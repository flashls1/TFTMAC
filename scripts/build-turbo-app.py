#!/usr/bin/env python3
"""Build the isolated TFT TURBO 2 native app entirely from source.

No private seed, signed-in AVD, saved account, or PIN is used. CP3 builds the
native app; the sealed native registry keeps emulator activation pending CP4.
An existing output is never deleted or overwritten.
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
from turbo2_isolation import (IsolationError, preflight, require_native_integration,
                              required_signing_identity, publish_exclusively,
                              verify_packaged_identity, staged_candidate_path)

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = Path.home() / 'Desktop/TFT TURBO 2.app'
DEVELOPER = '/Applications/Xcode-26.6.0.app/Contents/Developer'
ENV = dict(os.environ, DEVELOPER_DIR=DEVELOPER, PYTHONDONTWRITEBYTECODE='1')
PROTECTED_CORE_HASHES = {
    'TFT TURBO.app': 'a3955be420b00b1fd13801a5dfcad65fe085fe7e3486a763b6788750acb1ed67',
    'TFT Ranked.app': '00566b69d805b544645b478d272de1a94c63486ee9deccb406d6aea1d291cbee',
}


def digest(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            hasher.update(chunk)
    return hasher.hexdigest()


def run(*args, capture=False) -> str:
    result = subprocess.run([str(a) for a in args], cwd=ROOT, env=ENV, check=True,
                            stdout=subprocess.PIPE if capture else None, text=True)
    return result.stdout if capture else ''


def source_inputs() -> dict[str, str]:
    names = run('/usr/bin/git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z', capture=True)
    directories = {'tftmac', 'RankedLauncher', 'RuntimeHost', 'TFTMAC.xcodeproj', 'TFTMAC', 'CausalRuntime', 'Tests'}
    scripts = {'scripts/build-turbo-app.py', 'scripts/turbo2_isolation.py',
               'scripts/verify-turbo-build.command', 'scripts/test-native-app.command',
               'scripts/build-native-clock.command', 'scripts/install-trace-processor.command'}
    authority = {'ssot/runtime-modes.json', 'ssot/runtime-authority.json', 'ssot/turbo2-isolation.json'}
    selected = set()
    for name in names.split('\0'):
        if not name:
            continue
        path = Path(name)
        if path.parts[0] in directories or name in scripts or name in authority:
            if 'xcuserdata' in path.parts:
                continue
            if path.name in ('DEVGuestPIN.txt', 'riot-login.json'):
                raise IsolationError('Private provisioning is not a source-build input')
            local = ROOT / path
            if local.is_symlink() or not local.is_file():
                raise IsolationError('Source inputs must be regular managed files: ' + name)
            selected.add(name)
    return {name: digest(ROOT / name) for name in sorted(selected)}


def protected_snapshot() -> dict[str, dict[str, str]]:
    snapshot = {}
    for name, expected in PROTECTED_CORE_HASHES.items():
        app = Path.home() / 'Desktop' / name
        paths = ('Contents/MacOS/TFTMACDEVCore', 'Contents/MacOS/TFTMACDEVLauncher',
                 'Contents/Info.plist', 'Contents/Resources/runtime-modes.json')
        observed = {p: digest(app / p) for p in paths}
        if observed[paths[0]] != expected:
            raise IsolationError('Protected installed application identity changed: ' + name)
        run('/usr/bin/codesign', '--verify', '--deep', '--strict', app)
        snapshot[name] = observed
    return snapshot


def macho_uuids(path: Path) -> list[str]:
    output = run('/usr/bin/dwarfdump', '--uuid', path, capture=True)
    result = [f'{m[0]}:{m[1]}' for m in re.findall(r'UUID: ([0-9A-F-]+) \(([^)]+)\)', output)]
    if not result:
        raise IsolationError('Compiled native host has no Mach-O UUID')
    return result


def build(output: Path) -> None:
    report = preflight(output)  # Reject aliases and originals before any effects.
    require_native_integration()
    output = Path(report['app'])
    receipt_path = output.with_suffix('.build-receipt.json')
    if os.path.lexists(output) or os.path.lexists(receipt_path):
        raise IsolationError('Candidate output or receipt already exists; refusing overwrite')
    identity = required_signing_identity()
    before = source_inputs()
    originals = protected_snapshot()
    head = run('/usr/bin/git', 'rev-parse', 'HEAD', capture=True).strip()
    stage_root = Path(tempfile.mkdtemp(prefix='.tft-turbo2-build-', dir=output.parent))
    stage_root.chmod(0o700)
    app = stage_root / output.name
    staged_candidate_path(app)
    derived = ROOT / '.build/turbo2-native-release'
    receipt = {
        'status': 'BUILDING_NOT_ACCEPTED', 'source_head': head,
        'source_root': str(ROOT), 'source_inputs': before,
        'started_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'output': str(output), 'stage': str(app), 'app_name': 'TFT TURBO 2',
        'bundle_identifier': report['bundle_identifier'],
        'signing_identity': identity, 'accounts': 'DEFERRED_TO_LOCAL_CODEX',
        'emulator_activation': 'PENDING_CP4', 'private_seed_used': False,
        'signed_in_environment_copied': False, 'audio_gameplay_acceptance': 'NOT_RUN',
    }
    attempt = stage_root / 'build-attempt.json'
    attempt.write_text(json.dumps(receipt, indent=2) + '\n')
    attempt.chmod(0o600)
    try:
        run('/usr/bin/xcodebuild', '-quiet', '-project', ROOT / 'TFTMAC.xcodeproj',
            '-scheme', 'TFTMAC', '-configuration', 'Release', '-derivedDataPath', derived,
            'CODE_SIGNING_ALLOWED=NO', 'build')
        if source_inputs() != before:
            raise IsolationError('Source changed during compilation; no candidate published')
        built = derived / 'Build/Products/Release/TFTMAC.app'
        shutil.copytree(built, app, symlinks=True)
        resources = app / 'Contents/Resources'
        macos = app / 'Contents/MacOS'
        (macos / 'TFTMAC').rename(macos / 'TFTMACDEVCore')
        run('/usr/bin/xcrun', '--sdk', 'macosx', 'clang', '-Os', '-arch', 'arm64',
            '-mmacosx-version-min=15.0', '-DTFTMAC_TURBO2=1', ROOT / 'RankedLauncher/main.c',
            '-o', macos / 'TFTMACDEVLauncher')
        info_path = app / 'Contents/Info.plist'
        with info_path.open('rb') as stream:
            info = plistlib.load(stream)
        info.update(CFBundleIdentifier=report['bundle_identifier'], CFBundleName='TFT TURBO 2',
                    CFBundleDisplayName='TFT TURBO 2', CFBundleExecutable='TFTMACDEVLauncher',
                    CFBundleIconFile='TFTMAC-TURBO.icns',
                    NSRemovableVolumesUsageDescription='TFTMAC DEV uses the isolated Android diagnostic runtime stored on MAC MINI M4.')
        info_path.write_bytes(plistlib.dumps(info, sort_keys=False))
        shutil.copy2(ROOT / 'ssot/runtime-modes.json', resources / 'runtime-modes.json')
        for name in ('TFTMAC-TURBO.icns', 'TFTMAC-DEV.icns'):
            shutil.copy2(ROOT / 'tftmac/Assets/TFTMAC-TURBO.icns', resources / name)
        shutil.copytree(ROOT / 'tftmac/Assets/DEVHighPerf', resources / 'DEVHighPerf')

        # Existing source-owned helpers; never copy an installed personal app.
        ENV['TFTMAC_ANDROID_NDK_ROOT'] = '/Volumes/MAC MINI M4/TFTMAC-RUNTIME-DATA/SDK/ndk/29.0.14206865'
        ENV['TFTMAC_TEST_PYTHON'] = '/opt/homebrew/bin/python3'
        ENV['TFTMAC_CLOCK_SIGN_IDENTITY'] = identity
        run('/bin/zsh', ROOT / 'scripts/build-native-clock.command')
        shutil.copytree(ROOT / '.build/native-clock/NativeClock', resources / 'NativeClock')
        trace = Path(run('/bin/zsh', ROOT / 'scripts/install-trace-processor.command', capture=True).strip())
        if not trace.is_relative_to(ROOT / '.build') or digest(trace) != 'd29864d1ba3b36855527bb1b0ca3aa7f703cdce338b9680bb922c5c151b358fa':
            raise IsolationError('Pinned trace processor provenance failed')
        shutil.copy2(trace, resources / 'trace_processor_shell')

        host = resources / 'TFTMAC Emulator Host.app'
        host_binary = host / 'Contents/MacOS/TFTMACEmulatorHost'
        host_binary.parent.mkdir(parents=True)
        compile_arguments = ['-Os', '-arch', 'arm64', '-mmacosx-version-min=15.0']
        run('/usr/bin/xcrun', '--sdk', 'macosx', 'clang', *compile_arguments,
            ROOT / 'RuntimeHost/main.c', '-o', host_binary)
        shutil.copy2(ROOT / 'RuntimeHost/Turbo2Info.plist', host / 'Contents/Info.plist')
        run('/usr/bin/codesign', '--force', '--sign', identity, '--timestamp=none', host)
        host_receipt = {
            'schema': 1, 'state': 'TURBO2_NATIVE_HOST_BUILD_PASS',
            'host_application_relative_path': 'TFTMAC Emulator Host.app',
            'bundle_identifier': 'com.flashls1.tftmac.turbo2.emulator-host',
            'source_path': 'RuntimeHost/main.c', 'source_sha256': digest(ROOT / 'RuntimeHost/main.c'),
            'info_plist_path': 'RuntimeHost/Turbo2Info.plist',
            'info_plist_sha256': digest(ROOT / 'RuntimeHost/Turbo2Info.plist'),
            'executable_relative_path': 'Contents/MacOS/TFTMACEmulatorHost',
            'executable_sha256': digest(host_binary), 'executable_uuids': macho_uuids(host_binary),
            'compile_arguments': compile_arguments, 'signed_before_receipt': True,
            'outer_app_seals_receipt': True,
        }
        (resources / 'turbo2-host-build.json').write_text(json.dumps(host_receipt, indent=2) + '\n')
        source_receipt = {
            'schema': 1, 'source_head': head, 'source_inputs': before,
            'runtime_mode': 'turbo2', 'runtime_state': 'PENDING_CP4',
            'account_state': 'DEFERRED_TO_LOCAL_CODEX', 'private_seed_used': False,
        }
        (resources / 'turbo2-source-build.json').write_text(json.dumps(source_receipt, indent=2) + '\n')
        for name in ('TFTMACDEVCore', 'TFTMACDEVLauncher'):
            run('/usr/bin/codesign', '--force', '--sign', identity, '--timestamp=none', macos / name)
        run('/usr/bin/codesign', '--force', '--sign', identity, '--timestamp=none', app)
        run('/usr/bin/codesign', '--verify', '--deep', '--strict', app)
        verify_packaged_identity(app)
        # Full existing native suite is run by G08 against the staged candidate.
        run('/bin/zsh', ROOT / 'scripts/verify-turbo-build.command', '--staged-app', app)
        if source_inputs() != before or protected_snapshot() != originals:
            raise IsolationError('Source or protected artifacts changed; staged candidate not published')
        preflight(output)
        publish_exclusively(app, output)
        verify_packaged_identity(output)
        run('/usr/bin/codesign', '--verify', '--deep', '--strict', output)
        receipt.update(status='VERIFIED_STATIC_BUILD_RUNTIME_PENDING',
                       finished_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                       core_sha256=digest(output / 'Contents/MacOS/TFTMACDEVCore'),
                       launcher_sha256=digest(output / 'Contents/MacOS/TFTMACDEVLauncher'),
                       runtime_modes_sha256=digest(output / 'Contents/Resources/runtime-modes.json'),
                       static_build_gates='9/9', protected_applications='UNCHANGED',
                       live_runtime_and_authentication='NOT_TESTED')
        with receipt_path.open('x') as stream:
            json.dump(receipt, stream, indent=2)
            stream.write('\n')
        receipt_path.chmod(0o600)
        attempt.write_text(json.dumps(receipt, indent=2) + '\n')
        print('BUILT: ' + str(output))
        print('STATUS: native build verified; runtime provisioning/account setup are pending')
        print('RECEIPT: ' + str(receipt_path))
    except Exception as exc:
        receipt.update(status='NOT_ACCEPTED', failure_type=type(exc).__name__, failure=str(exc))
        attempt.write_text(json.dumps(receipt, indent=2) + '\n')
        raise


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument('--preflight', action='store_true')
    args = parser.parse_args(argv)
    try:
        report = preflight(args.output)
        if args.preflight:
            print(json.dumps(report, indent=2, sort_keys=True))
            return 0
        build(args.output)
    except (IsolationError, OSError, ValueError, subprocess.CalledProcessError) as exc:
        print(str(exc), file=sys.stderr)
        return 2
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
