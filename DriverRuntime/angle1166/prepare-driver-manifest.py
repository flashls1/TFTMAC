"""Extract a pinned build for DEV's reversible, boot-scoped driver transaction."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('--exchange', type=Path, required=True)
parser.add_argument('--variant', choices=('reference', 'reuse', 'capture', 'observed-reuse', 'observed-reuse-cache-r14'), required=True)
parser.add_argument('--reuse', action='store_true')
parser.add_argument('--capture-frames', type=int, default=0)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
assert not args.reuse or args.variant != 'reference'
assert 0 <= args.capture_frames <= 300
assert not args.capture_frames or args.variant == 'capture'
os.umask(0o077)
pinned = json.loads((Path(__file__).parent / 'binary-manifest.json').read_text())
build = args.exchange / args.variant
sha = lambda data: hashlib.sha256(data).hexdigest()
for name in ('AngleLibraries.apk', 'apk-libraries.json'):
    assert sha((build / name).read_bytes()) == pinned['variants'][args.variant][name]['sha256'], name
hashes = json.loads((build / 'apk-libraries.json').read_text())
args.output.mkdir(mode=0o700, parents=False, exist_ok=False)
libraries = []
with zipfile.ZipFile(build / 'AngleLibraries.apk') as apk:
    for name in ('libEGL_angle.so', 'libGLESv2_angle.so', 'libGLESv1_CM_angle.so'):
        entry = 'lib/arm64-v8a/' + name
        data = apk.read(entry)
        assert sha(data) == hashes[entry]
        assert data[:6] == b'\x7fELF\x02\x01' and data[16:20] == b'\x03\x00\xb7\x00'
        target = args.output / name
        target.write_bytes(data)
        libraries.append({'name': name, 'path': str(target.resolve()), 'sha256': sha(data)})
manifest = {'schema': 1, 'variant': 'reuse' if args.variant in ('observed-reuse', 'observed-reuse-cache-r14') else args.variant,
            'angleRevision': '1166eec4c0b125e9e945196acfc549983ef72b18',
            'reuseEnabled': args.reuse, 'captureFrames': args.capture_frames, 'libraries': libraries}
if args.variant in ('observed-reuse', 'observed-reuse-cache-r14'):
    manifest['viewDiagnosticsEnabled'] = True
target = args.output / 'driver-manifest.json'
target.write_text(json.dumps(manifest, indent=2) + '\n')
print(target.resolve())
