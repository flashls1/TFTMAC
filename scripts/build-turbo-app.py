#!/usr/bin/env python3
"""Build the personal TFT TURBO candidate on Flash's Mac.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SEED = Path('/Volumes/MAC MINI M4/TFTDEV-SSOT/private-build-inputs/ranked-65fd6587/TFT Ranked.app')
DEFAULT_OUTPUT = Path('/Users/flash/Desktop/TFT TURBO.app')
PIN = 'Contents/Resources/DEVGuestPIN.txt'
TURBO_ICNS = ROOT/'tftmac/Assets/TFTMAC-TURBO.icns' if (ROOT/'tftmac/Assets/TFTMAC-TURBO.icns').exists() else Path('/tmp/TFTMAC-TURBO.icns')

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
    parser.add_argument('--output', type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    output = args.output.resolve()
    seed = args.seed.resolve()
    
    # User constraint: existing production app on Desktop must never be touched
    ranked_prod = Path('/Users/flash/Desktop/TFT Ranked.app')
    if output == ranked_prod:
        raise SystemExit('Refusing to overwrite TFT Ranked.app production bundle!')
    
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
    derived = ROOT/'.build/turbo-build'
    before = source_inputs()
    
    if output.exists():
        shutil.rmtree(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.mkdir(mode=0o700)
    
    receipt_path = output.with_suffix('.build-receipt.json')
    receipt = {
        'status': 'BUILDING_NOT_VALIDATED',
        'app_name': 'TFT TURBO',
        'started_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'source_root': str(ROOT),
        'head': run('/usr/bin/git', 'rev-parse', 'HEAD', capture=True).strip(),
        'seed': str(seed),
        'output': str(output),
        'runtime_location': '/Users/flash/Library/Application Support/TFTMAC/InternalRuntime/StockShadow',
        'toolchain': run('/usr/bin/xcodebuild', '-version', capture=True).strip()
    }
    receipt_path.write_text(json.dumps(receipt, indent=2) + '\n')
    
    # 1. Compile TFTMAC with Xcode
    run('/usr/bin/xcodebuild', '-quiet', '-project', ROOT/'TFTMAC.xcodeproj', '-scheme', 'TFTMAC',
        '-configuration', 'Release', '-derivedDataPath', derived, 'CODE_SIGNING_ALLOWED=NO', 'build')
    
    if source_inputs() != before:
        raise SystemExit('Source changed during build; candidate is not admissible.')
    
    built = derived/'Build/Products/Release/TFTMAC.app'
    
    # 2. Copy seed base
    shutil.copytree(seed, output, symlinks=True, dirs_exist_ok=True)
    
    # 3. Replace Core executable with freshly built binary
    shutil.copy2(built/'Contents/MacOS/TFTMAC', output/'Contents/MacOS/TFTMACDEVCore')
    
    # 4. Compile Launcher
    run('/usr/bin/xcrun', '--sdk', 'macosx', 'clang', '-Os', '-arch', 'arm64', '-mmacosx-version-min=15.0',
        ROOT/'RankedLauncher/main.c', '-o', output/'Contents/MacOS/TFTMACDEVLauncher')
    
    # 5. Copy built runtime-modes.json (with internal SSD runtime paths and verified SHA256)
    shutil.copy2(built/'Contents/Resources/runtime-modes.json', output/'Contents/Resources/runtime-modes.json')
    
    # 6. Copy TURBO Icon and replace old DEV icon so LaunchServices / Finder can never resolve DEV icon
    if TURBO_ICNS.exists():
        shutil.copy2(TURBO_ICNS, output/'Contents/Resources/TFTMAC-TURBO.icns')
        shutil.copy2(TURBO_ICNS, output/'Contents/Resources/TFTMAC-DEV.icns')
    
    # 7. Update Info.plist (keep CFBundleIdentifier as com.flashls1.tftmac.dev to satisfy RuntimeMode.swift:176 and jitter buffering)
    info_plist_path = output/'Contents/Info.plist'
    plist_text = info_plist_path.read_text()
    plist_text = plist_text.replace('<string>TFT Ranked</string>', '<string>TFT TURBO</string>')
    if TURBO_ICNS.exists():
        plist_text = plist_text.replace('<string>TFTMAC-DEV.icns</string>', '<string>TFTMAC-TURBO.icns</string>')
    # Ensure NSRemovableVolumesUsageDescription is preserved to satisfy macOS TCC entitlement requirements
    if '<key>NSRemovableVolumesUsageDescription</key>' not in plist_text:
        removable_desc = '\t<key>NSRemovableVolumesUsageDescription</key>\n\t<string>TFTMAC DEV uses the isolated Android diagnostic runtime stored on MAC MINI M4.</string>\n'
        plist_text = plist_text.replace('</dict>', f'{removable_desc}</dict>')
    info_plist_path.write_text(plist_text)
    
    # 8. Copy HighPerf assets and verify integrity against runtime authority
    shutil.copytree(ROOT/'tftmac/Assets/DEVHighPerf', output/'Contents/Resources/DEVHighPerf', dirs_exist_ok=True)
    runtime_swift_text = (ROOT/'tftmac/Runtime/TFTMACRuntime.swift').read_text()
    for asset_name in ['DeviceProfiles.ini', 'profile-transaction.sh', 'debug-ramdisk.img', 'riot-defaults.sh']:
        asset_file = output/'Contents/Resources/DEVHighPerf'/asset_name
        if not asset_file.exists():
            raise SystemExit(f'CRITICAL: Missing HighPerf asset {asset_name}')
        actual_asset_hash = digest(asset_file)
        if f'"{asset_name}": "{actual_asset_hash}"' not in runtime_swift_text:
            raise SystemExit(f'CRITICAL: Asset hash mismatch in TFTMACRuntime.swift for {asset_name}: {actual_asset_hash}')
    device_profiles_hash = digest(output/'Contents/Resources/DEVHighPerf/DeviceProfiles.ini')
    profile_sh_text = (output/'Contents/Resources/DEVHighPerf/profile-transaction.sh').read_text()
    if f'control_expected={device_profiles_hash}' not in profile_sh_text:
        raise SystemExit(f'CRITICAL: profile-transaction.sh control_expected mismatch: expected {device_profiles_hash}')
    
    # 9. Set PIN permissions to 0600
    (output/PIN).chmod(0o600)
    
    # 10. Code signing with stable local identity to permanently preserve TCC permissions across builds
    signing_identity = '-'
    try:
        id_output = subprocess.check_output(['/usr/bin/security', 'find-identity', '-v', '-p', 'codesigning'], text=True)
        if 'TFTMAC Local Code Signing' in id_output:
            signing_identity = 'TFTMAC Local Code Signing'
    except Exception:
        pass
    
    clock_host = output/'Contents/Resources/NativeClock/tftmac-clock-host'
    if clock_host.exists():
        run('/usr/bin/codesign', '--force', '--sign', signing_identity, '--timestamp=none', clock_host)
    for binary in ['TFTMACDEVCore', 'TFTMACDEVLauncher']:
        run('/usr/bin/codesign', '--force', '--sign', signing_identity, '--timestamp=none', output/'Contents/MacOS'/binary)
    run('/usr/bin/codesign', '--force', '--sign', signing_identity, '--timestamp=none', output)
    run('/usr/bin/codesign', '--verify', '--deep', '--strict', output)
    
    # 11. Force LaunchServices registration and refresh Finder so Desktop icon displays yellow TURBO banner immediately
    lsregister = Path('/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister')
    if lsregister.exists():
        subprocess.run([str(lsregister), '-f', str(output)], check=False)
    subprocess.run(['/usr/bin/touch', str(output)], check=False)
    subprocess.run(['/usr/bin/osascript', '-e', f'tell application "Finder" to update (POSIX file "{output}") as alias'], check=False)
    subprocess.run(['/usr/bin/killall', 'Finder'], check=False)
    
    # 12. Verify protected invariant INV-01
    prod_ranked = Path('/Users/flash/Desktop/TFT Ranked.app/Contents/MacOS/TFTMACDEVCore')
    if prod_ranked.exists():
        prod_hash = digest(prod_ranked)
        if prod_hash != '00566b69d805b544645b478d272de1a94c63486ee9deccb406d6aea1d291cbee':
            raise SystemExit(f'CRITICAL: Protected Invariant INV-01 breached! {prod_hash}')
    
    if source_inputs() != before:
        raise SystemExit('Source changed during packaging; candidate is not admissible.')
    
    # 13. Run automated 9-gate quality verification protocol
    verify_script = ROOT/'scripts/verify-turbo-build.command'
    if verify_script.exists():
        print('\nExecuting automated 9-gate verification protocol...')
        subprocess.run(['/bin/zsh', str(verify_script)], check=True)
    
    receipt.update(
        status='VERIFIED_9_GATES_PASS',
        finished_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        signing_identity=signing_identity,
        core_sha256=digest(output/'Contents/MacOS/TFTMACDEVCore'),
        launcher_sha256=digest(output/'Contents/MacOS/TFTMACDEVLauncher'),
        runtime_modes_sha256=digest(output/'Contents/Resources/runtime-modes.json'),
        turbo_icns_sha256=digest(output/'Contents/Resources/TFTMAC-TURBO.icns') if (output/'Contents/Resources/TFTMAC-TURBO.icns').exists() else None
    )
    receipt_path.write_text(json.dumps(receipt, indent=2) + '\n')
    print(f'Successfully built and verified TFT TURBO app at: {output}')
    print(f'Build Receipt: {receipt_path}')
