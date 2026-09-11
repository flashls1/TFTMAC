"""Bounded native-clock transport validation in an explicitly selected DEV guest.

Only installs an owned temporary helper, creates an owned ADB forward, and removes
those resources. ADB never supplies the timestamps used for clock alignment.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import selectors
import socket
import subprocess
import time
import uuid

parser = argparse.ArgumentParser()
parser.add_argument('--adb', required=True)
parser.add_argument('--server-port', type=int, required=True)
parser.add_argument('--serial', required=True)
parser.add_argument('--host-helper', type=Path, required=True)
parser.add_argument('--guest-helper', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--transport', choices=('adb', 'emulator'), default='adb')
args = parser.parse_args()
os.umask(0o077)
args.output.mkdir(mode=0o700, parents=True, exist_ok=False)
adb = [args.adb, '-H', '127.0.0.1', '-P', str(args.server_port), '-s', args.serial]
nonce = uuid.uuid4().hex
guest_dir = '/data/local/tmp/tftmac-clock-' + nonce
guest_binary = guest_dir + '/clock'
server = None
forward_port = None
guest_pid = None
started = time.monotonic_ns()
receipt = {'schema': 1, 'state': 'CLOCK_VALIDATION_FAILED', 'clock_epoch': nonce,
           'transport': args.transport,
           'serial': args.serial, 'observer_started_host_ns': started,
           'host_helper_sha256': hashlib.sha256(args.host_helper.read_bytes()).hexdigest(),
           'guest_helper_sha256': hashlib.sha256(args.guest_helper.read_bytes()).hexdigest(),
           'long_interval_drift_bound_proven': False, 'cleanup_errors': []}


def command(parts, **kwargs):
    return subprocess.run(adb + parts, text=True, capture_output=True, timeout=20,
                          check=True, **kwargs).stdout.strip()


try:
    assert command(['get-state']) == 'device'
    receipt['guest_boot_id'] = command(['shell', 'cat', '/proc/sys/kernel/random/boot_id'])
    command(['shell', 'mkdir', '-m', '700', guest_dir])
    command(['push', str(args.guest_helper), guest_binary])
    command(['shell', 'chmod', '700', guest_binary])
    copied_sha = command(['shell', 'sha256sum', guest_binary]).split()[0]
    assert copied_sha == receipt['guest_helper_sha256']
    # Port collision is an explicit failure; never kill a foreign listener.
    mode = 'server-guest' if args.transport == 'emulator' else 'server'
    server = subprocess.Popen(adb + ['shell', guest_binary, mode, '49351',
                                    nonce[:16], nonce[16:]], stdout=subprocess.PIPE,
                              stderr=(args.output / 'server-stderr.txt').open('wb'))
    with selectors.DefaultSelector() as selector:
        selector.register(server.stdout, selectors.EVENT_READ)
        assert selector.select(timeout=8), 'native guest server did not report readiness'
        ready = json.loads(server.stdout.readline())
    assert ready['state'] == 'CLOCK_SERVER_READY' and ready['port'] == 49351
    guest_pid = ready['pid']
    (args.output / 'server-ready.json').write_text(json.dumps(ready) + '\n')
    if args.transport == 'adb':
        forward_port = int(command(['forward', 'tcp:0', 'tcp:49351']))
    else:
        assert ready['bind_address'] == '0.0.0.0'
        # Reserve a candidate port, then let QEMU bind it. A race is an explicit
        # failure; no replacement or deletion of another listener is allowed.
        with socket.socket() as probe:
            probe.bind(('127.0.0.1', 0))
            candidate_port = probe.getsockname()[1]
        result = command(['emu', 'redir', 'add', f'tcp:{candidate_port}:49351'])
        assert 'OK' in result and 'KO' not in result, result
        forward_port = candidate_port
        listeners = subprocess.run(['/usr/sbin/lsof', '-nP', f'-iTCP:{forward_port}', '-sTCP:LISTEN'],
                                   text=True, capture_output=True, timeout=5, check=True).stdout
        assert f'127.0.0.1:{forward_port} (LISTEN)' in listeners
        assert f'*:{forward_port}' not in listeners and f'[::]:{forward_port}' not in listeners
        (args.output / 'host-listener.txt').write_text(listeners)
    with (args.output / 'clock-samples.jsonl').open('wb') as raw:
        run = subprocess.run([str(args.host_helper), 'client', str(forward_port),
                              nonce[:16], nonce[16:], '100', '10'], stdout=raw,
                             stderr=subprocess.PIPE, timeout=12)
    receipt['client_status'] = run.returncode
    samples = [json.loads(line) for line in (args.output / 'clock-samples.jsonl').read_text().splitlines()]
    assert run.returncode == 0 and len(samples) == 100
    assert [x['sequence'] for x in samples] == list(range(1, 101))
    for sample in samples:
        assert sample['session_id'] == nonce
        assert sample['state'] in ('CLOCK_PRECISE', 'CLOCK_UNCERTAIN')
        assert sample['host_clock'] == 'MACH_ABSOLUTE' and sample['guest_clock'] == 'CLOCK_MONOTONIC'
        lower = sample['guest_t2_ns'] - sample['host_t3_ns']
        upper = sample['guest_t1_ns'] - sample['host_t0_ns']
        uncertainty = (upper - lower + 1) // 2
        assert lower <= upper
        assert sample['offset_lower_ns'] == lower and sample['offset_upper_ns'] == upper
        assert sample['uncertainty_ns'] == uncertainty
        assert (sample['state'] == 'CLOCK_PRECISE') == (uncertainty <= 500000)
    ordered = sorted(x['uncertainty_ns'] for x in samples)
    receipt.update(state='CLOCK_GUEST_TRANSPORT_VALIDATED', samples=len(samples),
                   precise_samples=sum(x['state'] == 'CLOCK_PRECISE' for x in samples),
                   median_uncertainty_ns=ordered[49], p95_uncertainty_ns=ordered[94],
                   max_uncertainty_ns=ordered[-1])
except Exception as error:
    receipt['failure'] = str(error)
finally:
    # Verify exact owned helper/session before terminating anything in the guest.
    if guest_pid is not None:
        try:
            cmdline = command(['shell', 'cat', f'/proc/{guest_pid}/cmdline']).replace('\x00', ' ')
            assert guest_binary in cmdline and nonce[:16] in cmdline and nonce[16:] in cmdline
            command(['shell', 'kill', '-TERM', str(guest_pid)])
        except Exception as error:
            receipt['cleanup_errors'].append('guest helper: ' + str(error))
    if server is not None:
        try:
            server.wait(timeout=5)
        except subprocess.TimeoutExpired:
            server.terminate()
            server.wait(timeout=5)
            receipt['cleanup_errors'].append('ADB server command required termination')
    if forward_port is not None:
        try:
            if args.transport == 'adb':
                command(['forward', '--remove', f'tcp:{forward_port}'])
            else:
                result = command(['emu', 'redir', 'del', f'tcp:{forward_port}'])
                assert 'OK' in result and 'KO' not in result, result
        except Exception as error:
            receipt['cleanup_errors'].append('forward: ' + str(error))
    try:
        command(['shell', 'rm', '-rf', guest_dir])
    except Exception as error:
        receipt['cleanup_errors'].append('owned temporary directory: ' + str(error))
    receipt['observer_ended_host_ns'] = time.monotonic_ns()
    receipt['artifacts'] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                            for p in args.output.iterdir() if p.is_file()}
    if receipt['cleanup_errors']:
        receipt['state'] = 'CLOCK_VALIDATION_CLEANUP_FAILED'
    (args.output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt))
    raise SystemExit(0 if receipt['state'] == 'CLOCK_GUEST_TRANSPORT_VALIDATED' else 1)
