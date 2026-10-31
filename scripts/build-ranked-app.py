#!/usr/bin/env python3
"""Build the personal Ranked candidate without source overlays or installation.

Run with /opt/homebrew/bin/python3 on Flash's Mac. The explicit private seed
supplies existing auxiliary resources and provisioning, never core/launcher code.
The seed manifest deliberately excludes the low-entropy PIN value and its hash.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SEED = Path('/Volumes/MAC MINI M4/TFTDEV-SSOT/private-build-inputs/ranked-65fd6587/TFT Ranked.app')
PIN = 'Contents/Resources/DEVGuestPIN.txt'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def run(*args, capture=False):
    return subprocess.run([str(a) for a in args], cwd=ROOT, env=ENV, check=True,
                          stdout=subprocess.PIPE if capture else None, text=True).stdout

def source_inputs():
    paths = []
    for directory in ['tftmac', 'RankedLauncher', 'TFTMAC.xcodeproj', 'TFTMAC']:
        paths.extend(p for p in (ROOT/directory).rglob('*') if p.is_file()
                     and 'xcuserdata' not in p.parts and p.name != 'DEVGuestPIN.txt')
    paths.append(Path(__file__).resolve())
    return {str(p.relative_to(ROOT)):digest(p) for p in sorted(set(paths))}

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seed', type=Path, default=DEFAULT_SEED)
    parser.add_argument('--output', type=Path, default=ROOT/'dist/TFT Ranked Candidate.app')
    args = parser.parse_args()
    output = args.output.resolve()
    seed = args.seed.resolve()
    if output.exists() or output.suffix != '.app':
        raise SystemExit('Output must be a new .app path; existing apps are never overwritten.')
    expected = json.loads((seed.parent/'non-secret-seed-manifest.json').read_text())
    if expected.get('Contents/MacOS/TFTMACDEVCore') != '65fd658712f453932526db2f9e25c42c7d32ef913dd82d12c26ab33e38e35710':
        raise SystemExit('Unrecognized resource seed identity.')
    actual = {str(p.relative_to(seed)):digest(p) for p in seed.rglob('*')
              if p.is_file() and str(p.relative_to(seed)) != PIN}
    if actual != expected:
        raise SystemExit('Resource seed differs from its preserved manifest.')
    if not (seed/PIN).is_file() or (seed/PIN).stat().st_mode & 0o077:
        raise SystemExit('Existing private DEV provisioning is missing or not owner-only; no credential setup attempted.')
    ENV = dict(os.environ)
    ENV['DEVELOPER_DIR'] = '/Applications/Xcode-26.6.0.app/Contents/Developer'
    derived = ROOT/'.build/ranked-canonical'
    before = source_inputs()
    output.parent.mkdir(parents=True, exist_ok=True)
    # Reserve a fresh destination; interrupted output is never accepted or reused.
    output.mkdir(mode=0o700)
    receipt_path = output.with_suffix('.build-receipt.json')
    receipt = {'status':'BUILDING_NOT_VALIDATED', 'started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
               'source_root':str(ROOT), 'head':run('/usr/bin/git','rev-parse','HEAD',capture=True).strip(),
               'source_inputs':before, 'seed':str(seed), 'seed_non_secret_manifest':expected,
               'private_provisioning':'existing DEV-only resource; contents and hash omitted',
               'output':str(output), 'toolchain':run('/usr/bin/xcodebuild','-version',capture=True).strip(),
               'runtime_validation':'PENDING_NORMAL_CANDIDATE_LAUNCH'}
    receipt_path.write_text(json.dumps(receipt,indent=2)+'\n')
    run('/usr/bin/xcodebuild','-quiet','-project',ROOT/'TFTMAC.xcodeproj','-scheme','TFTMAC',
        '-configuration','Release','-derivedDataPath',derived,'CODE_SIGNING_ALLOWED=NO','build')
    if source_inputs() != before:
        raise SystemExit('Source changed during build; candidate is not admissible.')
    built = derived/'Build/Products/Release/TFTMAC.app'
    shutil.copytree(seed, output, symlinks=True, dirs_exist_ok=True)
    shutil.copy2(built/'Contents/MacOS/TFTMAC', output/'Contents/MacOS/TFTMACDEVCore')
    run('/usr/bin/xcrun','--sdk','macosx','clang','-Os','-arch','arm64','-mmacosx-version-min=15.0',
        ROOT/'RankedLauncher/main.c','-o',output/'Contents/MacOS/TFTMACDEVLauncher')
    shutil.copytree(ROOT/'tftmac/Assets/DEVHighPerf', output/'Contents/Resources/DEVHighPerf', dirs_exist_ok=True)
    (output/PIN).chmod(0o600)
    # Keep the existing personal bundle identity and access scope; no Keychain signing identity lookup.
    for binary in ['TFTMACDEVCore','TFTMACDEVLauncher']:
        run('/usr/bin/codesign','--force','--sign','-','--timestamp=none',output/'Contents/MacOS'/binary)
    run('/usr/bin/codesign','--force','--sign','-','--timestamp=none',output)
    run('/usr/bin/codesign','--verify','--deep','--strict',output)
    if source_inputs() != before:
        raise SystemExit('Source changed during packaging; candidate is not admissible.')
    receipt.update(status='BUILT_RUNTIME_TEST_PENDING',
                   finished_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                   core_sha256=digest(output/'Contents/MacOS/TFTMACDEVCore'),
                   launcher_sha256=digest(output/'Contents/MacOS/TFTMACDEVLauncher'),
                   profile_sha256=digest(output/'Contents/Resources/DEVHighPerf/DeviceProfiles.ini'),
                   transaction_sha256=digest(output/'Contents/Resources/DEVHighPerf/profile-transaction.sh'))
    receipt_path.write_text(json.dumps(receipt,indent=2)+'\n')
    print(f'Built separate candidate: {output}\nNext required action: normal candidate launch and runtime acceptance.\nReceipt: {receipt_path}')
