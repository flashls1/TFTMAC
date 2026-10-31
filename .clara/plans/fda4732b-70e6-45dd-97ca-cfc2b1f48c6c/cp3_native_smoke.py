"""Smoke-test the signed native candidate's deliberately pending runtime state.
No account setup, emulator launch, AVD access or original app mutation.
"""
from pathlib import Path
import ctypes
import datetime
import hashlib
import json
import os
import subprocess
import time

HOME = Path.home()
APP = HOME / 'Desktop/TFT TURBO 2.app'
FAILURES = HOME / 'Library/Application Support/TFTMAC/Modes/turbo2/State/StartupFailures'
RUNTIME = HOME / 'Library/Application Support/TFTMAC/Turbo2/StockShadow'
EXPECTED = 'TFT TURBO 2 is built. Android runtime setup is pending (Checkpoint 4). Account setup is deferred to local Codex.'


def pids(name):
    result = subprocess.run(['/usr/bin/pgrep', '-x', name], capture_output=True, text=True)
    if result.returncode not in (0, 1):
        raise RuntimeError('Process observation failed')
    return sorted(int(v) for v in result.stdout.split())


def executable(pid):
    library = ctypes.CDLL('/usr/lib/libproc.dylib')
    library.proc_pidpath.argtypes = (ctypes.c_int, ctypes.c_void_p, ctypes.c_uint)
    buffer = ctypes.create_string_buffer(4096)
    if library.proc_pidpath(pid, buffer, len(buffer)) <= 0:
        return ''
    return os.fsdecode(buffer.value)


def candidate_pids():
    target = str(APP / 'Contents/MacOS/TFTMACDEVCore')
    return [pid for pid in pids('TFTMACDEVCore') if executable(pid) == target]


assert APP.is_dir() and not APP.is_symlink()
assert not RUNTIME.exists(), 'Runtime provisioning is outside CP3'
assert not candidate_pids(), 'Do not replace an existing candidate session'
subprocess.run(['/usr/bin/codesign', '--verify', '--deep', '--strict', str(APP)], check=True)
engine_before = pids('qemu-system-aarch64')
adb_before = pids('adb')
known = set(FAILURES.glob('*.json')) if FAILURES.exists() else set()
start = time.time()
subprocess.run(['/usr/bin/open', '-n', str(APP)], check=True)
owned = []
receipt = None
receipt_path = None
try:
    deadline = time.monotonic() + 45
    while time.monotonic() < deadline:
        owned = candidate_pids()
        for path in set(FAILURES.glob('*.json')) - known:
            if path.stat().st_mtime < start:
                continue
            payload = json.loads(path.read_text())
            if EXPECTED in json.dumps(payload) and payload.get('pid') in owned:
                receipt, receipt_path = payload, path
                break
        if receipt is not None:
            break
        time.sleep(0.25)
    assert receipt is not None, 'No matching native pending-state receipt'
    assert not RUNTIME.exists(), 'Unexpected runtime provisioning'
    assert pids('qemu-system-aarch64') == engine_before, 'Emulator process set changed'
    assert pids('adb') == adb_before, 'ADB process set changed'
    pid = receipt['pid']
    assert executable(pid) == str(APP / 'Contents/MacOS/TFTMACDEVCore')
    # AppKit requests ordinary termination of only this verified native app.
    js = "ObjC.import('AppKit'); $.NSRunningApplication.runningApplicationWithProcessIdentifier(" + str(pid) + ").terminate;"
    subprocess.run(['/usr/bin/osascript', '-l', 'JavaScript', '-e', js], check=True, capture_output=True, text=True)
    deadline = time.monotonic() + 10
    while candidate_pids() and time.monotonic() < deadline:
        time.sleep(0.2)
    assert not candidate_pids(), 'Candidate has not completed ordinary termination'
    result = {
        'schema': 1, 'state': 'CP3_NATIVE_PENDING_STATE_SMOKE_PASS',
        'observed_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'application': str(APP), 'native_pid': pid, 'startup_receipt': str(receipt_path),
        'startup_receipt_sha256': hashlib.sha256(receipt_path.read_bytes()).hexdigest(),
        'expected_message': EXPECTED, 'normal_termination': True,
        'engine_process_set_unchanged': True, 'adb_process_set_unchanged': True,
        'runtime_root_absent': True, 'account_apis_reached': False,
        'authentication_gameplay_or_audio_acceptance': 'NOT_RUN',
    }
    Path(__file__).with_name('CP3_NATIVE_SMOKE.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
except Exception:
    # Never terminate an incumbent or unverified process, even on a failed test.
    for pid in candidate_pids():
        js = "ObjC.import('AppKit'); $.NSRunningApplication.runningApplicationWithProcessIdentifier(" + str(pid) + ").terminate;"
        subprocess.run(['/usr/bin/osascript', '-l', 'JavaScript', '-e', js], capture_output=True)
    raise
