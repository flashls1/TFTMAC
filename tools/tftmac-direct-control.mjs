#!/usr/bin/env node
import fs from 'node:fs';
import fsp from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawn, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { DatabaseSync } from 'node:sqlite';

const PACKAGE = 'com.riotgames.league.teamfighttactics';
const AVD_NAME = 'TFTMAC_Live_API37';
const ADB_PORT = '5040';
const SERIAL = 'emulator-5592';
const EMULATOR_PORT = '5592';
const EXTERNAL_ROOT = '/Volumes/MAC MINI M4/TFTMAC/Runtime';
function resolveConsoleUserHome() {
  const userResult = spawnSync('/usr/bin/stat', ['-f', '%Su', '/dev/console'], { encoding: 'utf8' });
  const user = String(userResult.stdout ?? '').trim();
  if (user && user !== 'root' && user !== 'loginwindow') {
    const homeResult = spawnSync('/usr/bin/dscl', ['.', '-read', `/Users/${user}`, 'NFSHomeDirectory'], { encoding: 'utf8' });
    const match = String(homeResult.stdout ?? '').match(/NFSHomeDirectory:\s+(.+)/);
    if (match?.[1]) return match[1].trim();
  }
  return os.homedir();
}

const USER_HOME = resolveConsoleUserHome();
const APP_SUPPORT = path.join(USER_HOME, 'Library', 'Application Support', 'TFTMAC');
const STATE_ROOT = path.join(APP_SUPPORT, 'State');
const CAPTURE_ROOT = path.join(APP_SUPPORT, 'Captures');
const DIAGNOSTICS_ROOT = path.join(APP_SUPPORT, 'Diagnostics');
const CONTROL_STATE = path.join(STATE_ROOT, 'direct-control.json');
const REQUIRED_IMAGE = 'system-images;android-37.0;google_apis_playstore_ps16k;arm64-v8a';
const scriptPath = fileURLToPath(import.meta.url);
const scriptDir = path.dirname(scriptPath);
const repoRoot = process.env.TFTMAC_REPO_ROOT ? path.resolve(process.env.TFTMAC_REPO_ROOT) : path.resolve(scriptDir, '..');

function json(value) { process.stdout.write(`${JSON.stringify(value, null, 2)}\n`); }
function sleep(ms) { return new Promise(resolve => setTimeout(resolve, ms)); }
function nowISO() { return new Date().toISOString(); }
function monoNs() { return process.hrtime.bigint(); }
function exists(p) { try { fs.accessSync(p); return true; } catch { return false; } }
function executable(p) { try { fs.accessSync(p, fs.constants.X_OK); return true; } catch { return false; } }
function ensureDir(p) { fs.mkdirSync(p, { recursive: true }); }
function appendJSONL(file, value) { fs.appendFileSync(file, `${JSON.stringify(value)}\n`); }
function readJSON(file, fallback = null) { try { return JSON.parse(fs.readFileSync(file, 'utf8')); } catch { return fallback; } }
function writeJSON(file, value) { ensureDir(path.dirname(file)); fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`); }
function sha256File(file) { const h = crypto.createHash('sha256'); h.update(fs.readFileSync(file)); return h.digest('hex'); }

function command(executablePath, args = [], options = {}) {
  const result = spawnSync(executablePath, args, {
    encoding: 'utf8',
    env: options.env ?? process.env,
    cwd: options.cwd ?? repoRoot,
    timeout: options.timeout ?? 120000,
    maxBuffer: 32 * 1024 * 1024
  });
  if (result.error) throw result.error;
  if (result.status !== 0 && !options.allowFailure) {
    throw new Error(`${executablePath} ${args.join(' ')} failed (${result.status}): ${(result.stderr || result.stdout || '').trim()}`);
  }
  return { status: result.status, stdout: result.stdout ?? '', stderr: result.stderr ?? '' };
}

function resolveReal(p) { try { return fs.realpathSync(p); } catch { return p; } }
function isUnder(child, parent) {
  const c = resolveReal(child);
  const p = resolveReal(parent);
  return c === p || c.startsWith(`${p}${path.sep}`);
}

function walk(root, maxDepth = 4, maxEntries = 12000) {
  const out = [];
  const stack = [{ p: root, depth: 0 }];
  while (stack.length && out.length < maxEntries) {
    const { p, depth } = stack.pop();
    let entries;
    try { entries = fs.readdirSync(p, { withFileTypes: true }); } catch { continue; }
    for (const entry of entries) {
      const full = path.join(p, entry.name);
      out.push(full);
      if (entry.isDirectory() && depth < maxDepth && entry.name !== 'emu-master-dev' && entry.name !== 'src' && entry.name !== '.git') {
        stack.push({ p: full, depth: depth + 1 });
      }
      if (out.length >= maxEntries) break;
    }
  }
  return out;
}

function discover() {
  if (!exists('/Volumes/MAC MINI M4')) throw new Error('External volume /Volumes/MAC MINI M4 is not mounted.');
  if (!exists(EXTERNAL_ROOT)) throw new Error(`Required bulk runtime root does not exist: ${EXTERNAL_ROOT}`);
  const canonicalSdk = path.join(EXTERNAL_ROOT, 'SDK');
  const canonicalAvdIni = path.join(EXTERNAL_ROOT, 'AVD', `${AVD_NAME}.ini`);
  const canonicalComplete = executable(path.join(canonicalSdk, 'platform-tools', 'adb'))
    && executable(path.join(canonicalSdk, 'emulator', 'emulator'))
    && exists(canonicalAvdIni);
  const files = canonicalComplete ? [] : walk(EXTERNAL_ROOT, 5);
  const sdkRoots = new Set();
  for (const file of files) {
    if (file.endsWith(`${path.sep}platform-tools${path.sep}adb`) && executable(file)) {
      const candidate = path.dirname(path.dirname(file));
      if (executable(path.join(candidate, 'emulator', 'emulator'))) sdkRoots.add(candidate);
    }
  }
  for (const candidate of [
    path.join(EXTERNAL_ROOT, 'sdk'),
    path.join(EXTERNAL_ROOT, 'android-sdk'),
    path.join(APP_SUPPORT, 'Runtime', 'sdk'),
    path.join(APP_SUPPORT, 'sdk')
  ]) {
    if (executable(path.join(candidate, 'platform-tools', 'adb')) && executable(path.join(candidate, 'emulator', 'emulator'))) sdkRoots.add(candidate);
  }
  const externalSdkRoots = [...sdkRoots].filter(p => isUnder(p, EXTERNAL_ROOT));
  const sdkRoot = externalSdkRoots[0] ?? [...sdkRoots][0] ?? null;
  if (!sdkRoot) throw new Error(`No complete Google SDK/emulator runtime was found under ${EXTERNAL_ROOT}.`);

  const avdIniCandidates = files.filter(p => p.endsWith(`${AVD_NAME}.ini`));
  for (const candidate of [
    path.join(EXTERNAL_ROOT, 'avd', `${AVD_NAME}.ini`),
    path.join(EXTERNAL_ROOT, '.android', 'avd', `${AVD_NAME}.ini`),
    path.join(APP_SUPPORT, 'Runtime', 'avd', `${AVD_NAME}.ini`),
    path.join(APP_SUPPORT, 'avd', `${AVD_NAME}.ini`)
  ]) if (exists(candidate)) avdIniCandidates.push(candidate);

  let avdIni = [...new Set(avdIniCandidates)].find(p => isUnder(p, EXTERNAL_ROOT)) ?? [...new Set(avdIniCandidates)][0] ?? null;
  let avdHome = avdIni ? path.dirname(avdIni) : null;
  let avdDir = null;
  let avdConfig = null;
  if (avdIni) {
    const ini = fs.readFileSync(avdIni, 'utf8');
    const m = ini.match(/^path=(.+)$/m);
    avdDir = m ? m[1].trim() : path.join(avdHome, `${AVD_NAME}.avd`);
    const configPath = path.join(avdDir, 'config.ini');
    if (exists(configPath)) avdConfig = fs.readFileSync(configPath, 'utf8');
  }

  const imagePkg = path.join(sdkRoot, 'system-images', 'android-37.0', 'google_apis_playstore_ps16k', 'arm64-v8a');
  const env = {
    ...process.env,
    ANDROID_SDK_ROOT: sdkRoot,
    ANDROID_AVD_HOME: avdHome ?? process.env.ANDROID_AVD_HOME ?? '',
    ANDROID_ADB_SERVER_PORT: ADB_PORT,
    ADB_MDNS_AUTO_CONNECT: ''
  };
  const adb = path.join(sdkRoot, 'platform-tools', 'adb');
  const emulator = path.join(sdkRoot, 'emulator', 'emulator');
  const emulatorVersion = command(emulator, ['-version'], { allowFailure: true, env }).stdout.split('\n').find(l => /Android emulator version/i.test(l))?.trim() ?? null;
  const adbVersion = command(adb, ['version'], { allowFailure: true, env }).stdout.split('\n')[0]?.trim() ?? null;

  return {
    externalRoot: EXTERNAL_ROOT,
    externalRootReal: resolveReal(EXTERNAL_ROOT),
    appSupportRuntime: exists(path.join(APP_SUPPORT, 'Runtime')) ? resolveReal(path.join(APP_SUPPORT, 'Runtime')) : null,
    sdkRoot,
    adb,
    emulator,
    emulatorVersion,
    adbVersion,
    requiredImagePath: imagePkg,
    requiredImagePresent: exists(imagePkg),
    avdIni,
    avdHome,
    avdDir,
    avdConfig,
    env,
    sdkRoots: [...sdkRoots],
    avdIniCandidates: [...new Set(avdIniCandidates)]
  };
}

function adb(runtime, args, options = {}) {
  return command(runtime.adb, ['-P', ADB_PORT, '-s', SERIAL, ...args], { ...options, env: runtime.env });
}
function adbServer(runtime) { command(runtime.adb, ['-P', ADB_PORT, 'start-server'], { env: runtime.env }); }
function deviceReady(runtime) { return adb(runtime, ['get-state'], { allowFailure: true, timeout: 10000 }).stdout.trim() === 'device'; }
async function waitForDevice(runtime, timeoutMs = 180000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (deviceReady(runtime)) return;
    await sleep(1000);
  }
  throw new Error('Timed out waiting for emulator ADB device.');
}
async function waitForBoot(runtime, timeoutMs = 240000) {
  await waitForDevice(runtime, timeoutMs);
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (adb(runtime, ['shell', 'getprop', 'sys.boot_completed'], { allowFailure: true, timeout: 10000 }).stdout.trim() === '1') return;
    await sleep(1000);
  }
  throw new Error('Timed out waiting for Android boot completion.');
}

function parseKeyValueLines(text) {
  const out = {};
  for (const line of text.split(/\r?\n/)) {
    const m = line.match(/^\s*([^:=]+?)\s*[:=]\s*(.*?)\s*$/);
    if (m) out[m[1].trim()] = m[2].trim();
  }
  return out;
}

function captureSigningDigest(runtime, apkPaths, captureDir, versionName, versionCode) {
  if (!captureDir || !apkPaths.length) return { certificateSHA256: null, output: null };
  const previous = readJSON(path.join(captureDir, 'package-state.json'), {});
  if (previous?.versionName === versionName && previous?.versionCode === versionCode && previous?.signerCertificateSHA256) {
    return { certificateSHA256: previous.signerCertificateSHA256, output: exists(path.join(captureDir, 'package-signing.txt')) ? fs.readFileSync(path.join(captureDir, 'package-signing.txt'), 'utf8') : null };
  }
  const buildToolsRoot = path.join(runtime.sdkRoot, 'build-tools');
  let apksigner = null;
  try {
    const versions = fs.readdirSync(buildToolsRoot).sort((a, b) => b.localeCompare(a, undefined, { numeric: true }));
    for (const version of versions) {
      const candidate = path.join(buildToolsRoot, version, 'apksigner');
      if (executable(candidate)) { apksigner = candidate; break; }
    }
  } catch {}
  if (!apksigner) return { certificateSHA256: null, output: 'apksigner unavailable in installed Google build-tools' };
  const baseApk = apkPaths.find(p => /\/base\.apk$/.test(p)) ?? apkPaths[0];
  const tempApk = `/private/tmp/tftmac-signing-${process.pid}-${Date.now()}.apk`;
  try {
    const pull = command(runtime.adb, ['-P', ADB_PORT, '-s', SERIAL, 'pull', baseApk, tempApk], { env: runtime.env, allowFailure: true, timeout: 300000 });
    if (pull.status !== 0 || !exists(tempApk)) return { certificateSHA256: null, output: `adb pull failed: ${pull.stderr || pull.stdout}` };
    const verified = command(apksigner, ['verify', '--print-certs', tempApk], { allowFailure: true, timeout: 120000 });
    const output = `${verified.stdout}${verified.stderr}`.trim();
    const digest = output.match(/Signer #\d+ certificate SHA-256 digest:\s*([0-9a-f:]+)/i)?.[1]?.replace(/:/g, '').toLowerCase() ?? null;
    fs.writeFileSync(path.join(captureDir, 'package-signing.txt'), `${output}\n`);
    return { certificateSHA256: digest, output };
  } finally {
    try { fs.unlinkSync(tempApk); } catch {}
  }
}

function packageState(runtime, captureDir = null, includeSigning = true) {
  const pathsOut = adb(runtime, ['shell', 'pm', 'path', PACKAGE], { allowFailure: true }).stdout.trim();
  if (!pathsOut.includes('package:')) {
    const missing = { observedAt: nowISO(), packageName: PACKAGE, state: 'MISSING', apkPaths: [] };
    if (captureDir) writeJSON(path.join(captureDir, 'package-state.json'), missing);
    return missing;
  }
  const apkPaths = pathsOut.split(/\r?\n/).filter(Boolean).map(l => l.replace(/^package:/, '').trim());
  const dump = adb(runtime, ['shell', 'dumpsys', 'package', PACKAGE], { allowFailure: true, timeout: 30000 }).stdout;
  const versionName = dump.match(/versionName=([^\s]+)/)?.[1] ?? null;
  const versionCode = dump.match(/versionCode=([^\s]+)/)?.[1] ?? null;
  const installer = dump.match(/installerPackageName=([^\s]+)/)?.[1] ?? dump.match(/Installer package name:\s*([^\s]+)/i)?.[1] ?? null;
  const firstInstallTime = dump.match(/firstInstallTime=([^\n]+)/)?.[1]?.trim() ?? null;
  const lastUpdateTime = dump.match(/lastUpdateTime=([^\n]+)/)?.[1]?.trim() ?? null;
  const launchActivity = adb(runtime, ['shell', 'cmd', 'package', 'resolve-activity', '--brief', PACKAGE], { allowFailure: true }).stdout.trim() || null;
  const hashes = {};
  const apkBytes = {};
  for (const apkPath of apkPaths) {
    const out = adb(runtime, ['shell', 'sha256sum', apkPath], { allowFailure: true, timeout: 30000 }).stdout.trim();
    const m = out.match(/^([0-9a-f]{64})\s+/i);
    if (m) hashes[apkPath] = m[1].toLowerCase();
    const sizeOut = adb(runtime, ['shell', 'stat', '-c', '%s', apkPath], { allowFailure: true, timeout: 10000 }).stdout.trim();
    if (/^\d+$/.test(sizeOut)) apkBytes[apkPath] = Number(sizeOut);
  }
  const signingLines = dump.split(/\r?\n/).filter(l => /sha-?256|signing|certificate/i.test(l)).slice(0, 80);
  const previousForSigning = captureDir ? readJSON(path.join(captureDir, 'package-state.json'), {}) : {};
  const signing = includeSigning
    ? captureSigningDigest(runtime, apkPaths, captureDir, versionName, versionCode)
    : { certificateSHA256: previousForSigning?.signerCertificateSHA256 ?? null, output: null };
  const previousState = captureDir ? readJSON(path.join(captureDir, 'package-state.json'), {}) : {};
  const currentWasVerified = previousState?.state === 'INSTALLED_CURRENT_OBSERVED'
    && previousState?.versionName === versionName
    && previousState?.versionCode === versionCode;
  const state = {
    observedAt: nowISO(), packageName: PACKAGE, state: currentWasVerified ? 'INSTALLED_CURRENT_OBSERVED' : 'INSTALLED_UNKNOWN_VERSION', versionName, versionCode,
    installerPackage: installer, firstInstallTime, lastUpdateTime, launchActivity, apkPaths, apkSHA256: hashes, apkBytes,
    signerCertificateSHA256: signing.certificateSHA256,
    signingObservation: signingLines
  };
  if (captureDir) {
    writeJSON(path.join(captureDir, 'package-state.json'), state);
    fs.writeFileSync(path.join(captureDir, 'package-dumpsys.txt'), dump);
  }
  return state;
}

function rendererState(runtime, captureDir) {
  const getprop = adb(runtime, ['shell', 'getprop'], { allowFailure: true, timeout: 30000 }).stdout;
  const sf = adb(runtime, ['shell', 'dumpsys', 'SurfaceFlinger'], { allowFailure: true, timeout: 30000 }).stdout;
  const gfx = adb(runtime, ['shell', 'dumpsys', 'gfxinfo', PACKAGE], { allowFailure: true, timeout: 30000 }).stdout;
  const activity = adb(runtime, ['shell', 'dumpsys', 'activity', 'top'], { allowFailure: true, timeout: 30000 }).stdout;
  const keys = [
    'ro.hardware.egl','ro.hardware.vulkan','ro.opengles.version','ro.boot.qemu.gltransport','ro.boot.qemu.gles','debug.hwui.renderer',
    'ro.kernel.qemu','ro.product.cpu.abi','ro.build.version.release','ro.build.version.sdk'
  ];
  const props = {};
  for (const key of keys) {
    const out = adb(runtime, ['shell', 'getprop', key], { allowFailure: true }).stdout.trim();
    if (out) props[key] = out;
  }
  const settings = {};
  for (const key of ['angle_gl_driver_all_angle','angle_gl_driver_selection_pkgs','angle_gl_driver_selection_values']) {
    settings[key] = adb(runtime, ['shell', 'settings', 'get', 'global', key], { allowFailure: true }).stdout.trim();
  }
  const emulatorLog = captureDir ? path.join(captureDir, 'emulator.stdout.log') : null;
  let hostGraphicsEvidence = [];
  if (emulatorLog && exists(emulatorLog)) {
    hostGraphicsEvidence = fs.readFileSync(emulatorLog, 'utf8').split(/\r?\n/)
      .filter(l => /ANGLE|gfxstream|MoltenVK|Metal|Vulkan|gltransport|virtio-gpu|renderer/i.test(l)).slice(-240);
  }
  const result = { observedAt: nowISO(), properties: props, angleSettings: settings, hostGraphicsEvidence };
  if (captureDir) {
    writeJSON(path.join(captureDir, 'renderer-state.json'), result);
    fs.writeFileSync(path.join(captureDir, 'renderer-getprop.txt'), getprop);
    fs.writeFileSync(path.join(captureDir, 'surfaceflinger', 'surfaceflinger.txt'), sf);
    fs.writeFileSync(path.join(captureDir, 'gfxinfo', 'gfxinfo-snapshot.txt'), gfx);
    fs.writeFileSync(path.join(captureDir, 'activity-top.txt'), activity);
  }
  return result;
}

function currentGitSha() {
  if (process.env.TFTMAC_BUILD_COMMIT) return process.env.TFTMAC_BUILD_COMMIT;
  const bundledCommit = path.join(scriptDir, 'build-commit.txt');
  if (exists(bundledCommit)) return fs.readFileSync(bundledCommit, 'utf8').trim();
  const result = command('/usr/bin/git', ['rev-parse', 'HEAD'], { cwd: repoRoot, allowFailure: true });
  return result.status === 0 ? result.stdout.trim() : 'uncommitted-control';
}

function runtimeState(runtime, captureDir, bootClass) {
  const avdHash = runtime.avdConfig ? crypto.createHash('sha256').update(runtime.avdConfig).digest('hex') : null;
  const display = adb(runtime, ['shell', 'wm', 'size'], { allowFailure: true }).stdout.trim();
  const density = adb(runtime, ['shell', 'wm', 'density'], { allowFailure: true }).stdout.trim();
  const state = {
    observedAt: nowISO(), control: 'control_stock_direct_v0', externalRoot: runtime.externalRoot,
    sdkRoot: runtime.sdkRoot, emulatorVersion: runtime.emulatorVersion, adbVersion: runtime.adbVersion,
    systemImagePackage: REQUIRED_IMAGE, avdName: AVD_NAME, avdHome: runtime.avdHome, avdConfigSHA256: avdHash,
    adbSerial: SERIAL, adbServerPort: Number(ADB_PORT), emulatorConsolePort: Number(EMULATOR_PORT),
    vcpu: 6, ramMB: 6144, displayRequested: '1920x1080', densityRequested: 320, refreshTargetHz: 60,
    gpuMode: 'host', audioEnabled: true, deviceFrame: false, snapshotsRequired: false, bootClass,
    observedDisplay: display, observedDensity: density
  };
  if (captureDir) writeJSON(path.join(captureDir, 'runtime-state.json'), state);
  return state;
}

function setIniValue(text, key, value) {
  const escaped = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const pattern = new RegExp(`^${escaped}=.*$`, 'm');
  return pattern.test(text)
    ? text.replace(pattern, `${key}=${value}`)
    : `${text.replace(/\s*$/, '')}\n${key}=${value}\n`;
}

function prepareAVD() {
  const runtime = discover();
  if (!isUnder(runtime.sdkRoot, EXTERNAL_ROOT)) throw new Error('Selected SDK is not on the required external runtime volume.');
  if (!runtime.requiredImagePresent) throw new Error(`Required official Play image is missing: ${runtime.requiredImagePath}`);
  if (!runtime.avdIni || !runtime.avdDir || !runtime.avdConfig) {
    const avdmanager = path.join(runtime.sdkRoot, 'cmdline-tools', 'latest', 'bin', 'avdmanager');
    if (!executable(avdmanager)) throw new Error(`Required AVD ${AVD_NAME} is missing and avdmanager is unavailable.`);
    ensureDir(path.join(EXTERNAL_ROOT, 'AVD'));
    command(avdmanager, ['create', 'avd', '--name', AVD_NAME, '--package', REQUIRED_IMAGE, '--device', 'pixel_tablet', '--force'], {
      env: { ...runtime.env, ANDROID_AVD_HOME: path.join(EXTERNAL_ROOT, 'AVD') },
      timeout: 120000
    });
    return prepareAVD();
  }
  if (!isUnder(runtime.avdDir, EXTERNAL_ROOT)) throw new Error('Selected AVD is not on the required external runtime volume.');
  const configPath = path.join(runtime.avdDir, 'config.ini');
  let config = runtime.avdConfig;
  const values = {
    AvdId: AVD_NAME,
    'avd.ini.displayname': 'TFTMAC Live Control',
    'hw.device.manufacturer': 'Google',
    'hw.device.name': 'pixel_tablet',
    'hw.initialOrientation': 'Landscape',
    'hw.cpu.arch': 'arm64',
    'hw.cpu.ncore': '6',
    'hw.ramSize': '6144',
    'hw.vmHeapSize': '768',
    'hw.lcd.width': '1920',
    'hw.lcd.height': '1080',
    'hw.lcd.density': '320',
    'hw.gpu.enabled': 'yes',
    'hw.gpu.mode': 'host',
    'hw.audioInput': 'yes',
    'hw.keyboard': 'yes',
    showDeviceFrame: 'no',
    'skin.name': '1920x1080',
    'disk.dataPartition.size': '16G',
    'runtime.network.speed': 'full',
    'runtime.network.latency': 'none',
    'PlayStore.enabled': 'true',
    'fastboot.forceColdBoot': 'yes',
    'fastboot.forceFastBoot': 'no'
  };
  for (const [key, value] of Object.entries(values)) config = setIniValue(config, key, value);
  fs.writeFileSync(configPath, config);
  const forbidden = config.split(/\r?\n/).filter(line => /guestangle|opengles\.version|nonconformant|moltenvk|graphics_profile/i.test(line));
  if (forbidden.length) throw new Error(`AVD contains experimental graphics overrides and is not a clean stock control: ${forbidden.join('; ')}`);
  return {
    avdName: AVD_NAME,
    avdHome: runtime.avdHome,
    avdDir: runtime.avdDir,
    configPath,
    configSHA256: sha256File(configPath),
    control: { vcpu: 6, ramMB: 6144, width: 1920, height: 1080, densityDpi: 320, gpu: 'host', playStore: true, audio: true },
    imagePackage: REQUIRED_IMAGE,
    emulatorVersion: runtime.emulatorVersion
  };
}

function startSampler(runtime, captureDir, sessionId) {
  const out = fs.openSync(path.join(captureDir, 'sampler.stdout.log'), 'a');
  const err = fs.openSync(path.join(captureDir, 'sampler.stderr.log'), 'a');
  const child = spawn(process.execPath, [scriptPath, 'sampler', '--capture', captureDir, '--session', sessionId], {
    cwd: repoRoot, env: runtime.env, detached: true, stdio: ['ignore', out, err]
  });
  child.unref();
  return child.pid;
}

function startEmulator(runtime, captureDir) {
  if (!runtime.avdHome || !runtime.avdIni || !runtime.avdDir) throw new Error(`Official AVD ${AVD_NAME} is not present under the external runtime.`);
  const out = fs.openSync(path.join(captureDir, 'emulator.stdout.log'), 'a');
  const err = fs.openSync(path.join(captureDir, 'emulator.stderr.log'), 'a');
  const args = [
    `@${AVD_NAME}`, '-id', 'TFTMAC-Direct-Control', '-port', EMULATOR_PORT,
    '-gpu', 'host', '-skin', '1920x1080', '-cores', '6', '-memory', '6144',
    '-no-snapshot', '-no-metrics', '-no-boot-anim', '-crash-report-mode', 'disabled'
  ];
  const env = { ...runtime.env, ANDROID_AVD_HOME: runtime.avdHome, ANDROID_EMULATOR_USE_SYSTEM_LIBS: '0' };
  const child = spawn(runtime.emulator, args, { cwd: repoRoot, env, detached: true, stdio: ['ignore', out, err] });
  child.unref();
  appendJSONL(path.join(captureDir, 'host-events.jsonl'), { utc: nowISO(), event: 'EMULATOR_STARTED', pid: child.pid, args });
  return child.pid;
}

async function startControl() {
  const runtime = discover();
  if (!isUnder(runtime.sdkRoot, EXTERNAL_ROOT)) throw new Error('Selected SDK is not on the required external runtime volume.');
  if (!runtime.requiredImagePresent) throw new Error(`Required official Play image is missing: ${runtime.requiredImagePath}`);
  if (!runtime.avdIni || !runtime.avdConfig) throw new Error(`Required AVD ${AVD_NAME} was not found. A clean AVD must be created from the installed official image before launch.`);
  if (!isUnder(runtime.avdDir, EXTERNAL_ROOT)) throw new Error('Selected AVD is not on the required external runtime volume.');
  ensureDir(STATE_ROOT); ensureDir(CAPTURE_ROOT); ensureDir(DIAGNOSTICS_ROOT);
  const sessionId = `${new Date().toISOString().replace(/[:.]/g, '-')}-${crypto.randomUUID()}`;
  const captureDir = path.join(CAPTURE_ROOT, sessionId);
  for (const d of [captureDir, path.join(captureDir, 'surfaceflinger'), path.join(captureDir, 'gfxinfo')]) ensureDir(d);
  for (const name of ['clock-sync.jsonl', 'markers.jsonl', 'logcat.raw.txt', 'logcat.filtered.txt', 'host-process.csv', 'host-process.jsonl', 'host-memory.csv', 'host-memory.jsonl']) {
    fs.closeSync(fs.openSync(path.join(captureDir, name), 'a'));
  }
  appendJSONL(path.join(captureDir, 'host-events.jsonl'), { utc: nowISO(), host_mono_ns: monoNs().toString(), event: 'LOGGER_INITIALIZED', sessionId });
  const session = {
    schema: 1, sessionId, startedUTC: nowISO(), endedUTC: null,
    hostStartMonoNs: monoNs().toString(), hostEndMonoNs: null, captureState: 'CAPTURING',
    workloadLabel: 'first-direct-play-control', appCommit: currentGitSha(), runtimeConfig: 'control_stock_direct_v0',
    packageName: PACKAGE, packageUpdatedDuringSession: false, packageAuthorityVerified: false, packageCurrentObservedAt: null,
    matchEntryObserved: false, combatObserved: false
  };
  writeJSON(path.join(captureDir, 'session.json'), session);
  const samplerPid = startSampler(runtime, captureDir, sessionId);
  appendJSONL(path.join(captureDir, 'host-events.jsonl'), { utc: nowISO(), event: 'SAMPLER_STARTED', pid: samplerPid });

  adbServer(runtime);
  const reusedRunningEmulator = deviceReady(runtime);
  const emulatorPid = reusedRunningEmulator ? null : startEmulator(runtime, captureDir);
  await waitForBoot(runtime);
  adb(runtime, ['shell', 'wm', 'size', '1920x1080']);
  adb(runtime, ['shell', 'wm', 'density', '320']);
  runtimeState(runtime, captureDir, reusedRunningEmulator ? 'WARM' : 'COLD');
  const pkg = packageState(runtime, captureDir, false);
  rendererState(runtime, captureDir);
  const state = { schema: 1, sessionId, captureDir, samplerPid, emulatorPid, reusedRunningEmulator, sdkRoot: runtime.sdkRoot, avdHome: runtime.avdHome, startedUTC: session.startedUTC, packageState: pkg.state };
  writeJSON(CONTROL_STATE, state);
  return { ...state, package: pkg, next: pkg.state === 'MISSING' ? 'run play-action to install official TFT from Google Play' : 'run play-action to verify/update official TFT, then launch-game' };
}

function parseBounds(text) {
  const m = text.match(/bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"/);
  if (!m) return null;
  return { x: Math.round((Number(m[1]) + Number(m[3])) / 2), y: Math.round((Number(m[2]) + Number(m[4])) / 2) };
}

function dumpUI(runtime) {
  adb(runtime, ['shell', 'uiautomator', 'dump', '/sdcard/tftmac-window.xml'], { allowFailure: true, timeout: 30000 });
  return adb(runtime, ['shell', 'cat', '/sdcard/tftmac-window.xml'], { allowFailure: true, timeout: 30000 }).stdout;
}

function findNodeByText(xml, wanted) {
  const nodes = xml.match(/<node\b[^>]*\/>/g) ?? [];
  for (const node of nodes) {
    const text = node.match(/text="([^"]*)"/)?.[1] ?? '';
    const desc = node.match(/content-desc="([^"]*)"/)?.[1] ?? '';
    if (wanted.some(rx => rx.test(text) || rx.test(desc))) return { node, text, desc, bounds: parseBounds(node) };
  }
  return null;
}

async function playAction() {
  const runtime = discover();
  const state = readJSON(CONTROL_STATE);
  const captureDir = state?.captureDir ?? null;
  await waitForBoot(runtime, 60000);
  adb(runtime, ['shell', 'am', 'start', '-a', 'android.intent.action.VIEW', '-d', `market://details?id=${PACKAGE}`], { allowFailure: true });
  await sleep(3500);
  const xml = dumpUI(runtime);
  if (captureDir) fs.writeFileSync(path.join(captureDir, 'google-play-ui.xml'), xml);
  const auth = findNodeByText(xml, [/sign in/i, /add account/i, /verify.*account/i, /choose an account/i, /google account/i]);
  if (auth) return { action: 'AUTH_REQUIRED', provider: 'Google', evidence: { text: auth.text, contentDescription: auth.desc }, instruction: 'Authenticate directly in the Google Play UI, then rerun play-action.' };
  const update = findNodeByText(xml, [/^Update$/i]);
  const install = findNodeByText(xml, [/^Install$/i]);
  const open = findNodeByText(xml, [/^Open$/i, /^Play$/i]);
  const target = update ?? install;
  if (target?.bounds) {
    adb(runtime, ['shell', 'input', 'tap', String(target.bounds.x), String(target.bounds.y)]);
    if (captureDir) {
      appendJSONL(path.join(captureDir, 'markers.jsonl'), { utc: nowISO(), host_mono_ns: monoNs().toString(), event: update ? 'PACKAGE_UPDATE' : 'PACKAGE_INSTALL', source: 'Google Play UI' });
      const session = readJSON(path.join(captureDir, 'session.json'), {});
      session.packageUpdatedDuringSession = true;
      writeJSON(path.join(captureDir, 'session.json'), session);
    }
    return { action: update ? 'UPDATE_STARTED' : 'INSTALL_STARTED', instruction: 'Google Play operation started; poll play-action until CURRENT_OBSERVED.' };
  }
  const progress = findNodeByText(xml, [/pending/i, /installing/i, /downloading/i, /%$/i, /^Cancel$/i]);
  if (progress) {
    return { action: 'INSTALL_OR_UPDATE_IN_PROGRESS', evidence: { text: progress.text, contentDescription: progress.desc } };
  }
  const pkg = packageState(runtime, captureDir);
  if (pkg.state !== 'MISSING' && open) {
    if (pkg.installerPackage !== 'com.android.vending') {
      if (captureDir) appendJSONL(path.join(captureDir, 'host-events.jsonl'), {
        utc: nowISO(), host_mono_ns: monoNs().toString(), event: 'PACKAGE_AUTHORITY_RESET',
        observedInstaller: pkg.installerPackage ?? null, versionName: pkg.versionName ?? null, versionCode: pkg.versionCode ?? null,
        signerCertificateSHA256: pkg.signerCertificateSHA256 ?? null
      });
      const removed = adb(runtime, ['shell', 'pm', 'uninstall', PACKAGE], { allowFailure: true, timeout: 60000 });
      if (!/Success/i.test(`${removed.stdout}${removed.stderr}`)) {
        return { action: 'AUTHORITY_UNRESOLVED', package: pkg, reason: `Existing package is not Google-Play-installed and could not be removed: ${removed.stderr || removed.stdout}` };
      }
      if (captureDir) writeJSON(path.join(captureDir, 'package-state.json'), { observedAt: nowISO(), packageName: PACKAGE, state: 'MISSING', apkPaths: [], authorityReset: true });
      await sleep(1500);
      return await playAction();
    }
    pkg.state = 'INSTALLED_CURRENT_OBSERVED';
    if (captureDir) {
      writeJSON(path.join(captureDir, 'package-state.json'), pkg);
      const session = readJSON(path.join(captureDir, 'session.json'), {});
      session.packageAuthorityVerified = true;
      session.packageCurrentObservedAt = nowISO();
      writeJSON(path.join(captureDir, 'session.json'), session);
    }
    return { action: 'CURRENT_OBSERVED', package: pkg, authority: 'Google Play listing shows Open/Play and no Update action' };
  }
  return { action: 'PLAY_STATE_UNRESOLVED', package: pkg, uiSample: xml.slice(0, 2000) };
}

async function launchGame() {
  const runtime = discover();
  const state = readJSON(CONTROL_STATE);
  if (!state?.captureDir) throw new Error('No active direct-control session. Run start first.');
  const captureDir = state.captureDir;
  await waitForBoot(runtime, 60000);
  const pkg = packageState(runtime, captureDir, false);
  if (pkg.state === 'MISSING') throw new Error('Official TFT package is not installed. Run play-action first.');
  rendererState(runtime, captureDir);
  adb(runtime, ['shell', 'dumpsys', 'gfxinfo', PACKAGE, 'reset'], { allowFailure: true, timeout: 30000 });
  appendJSONL(path.join(captureDir, 'host-events.jsonl'), { utc: nowISO(), host_mono_ns: monoNs().toString(), event: 'GFXINFO_RESET_BEFORE_TFT_LAUNCH' });
  const resolved = adb(runtime, ['shell', 'cmd', 'package', 'resolve-activity', '--brief', PACKAGE], { allowFailure: true }).stdout.trim();
  let launchResult;
  if (resolved && !/No activity/i.test(resolved)) {
    launchResult = adb(runtime, ['shell', 'am', 'start', '-W', '-n', resolved], { allowFailure: true, timeout: 120000 });
  } else {
    launchResult = adb(runtime, ['shell', 'monkey', '-p', PACKAGE, '-c', 'android.intent.category.LAUNCHER', '1'], { allowFailure: true, timeout: 120000 });
  }
  appendJSONL(path.join(captureDir, 'markers.jsonl'), { utc: nowISO(), host_mono_ns: monoNs().toString(), event: 'TFT_LAUNCH' });
  const deadline = Date.now() + 120000;
  let pid = '';
  while (Date.now() < deadline) {
    pid = adb(runtime, ['shell', 'pidof', PACKAGE], { allowFailure: true }).stdout.trim();
    if (pid) break;
    await sleep(1000);
  }
  if (!pid) throw new Error(`TFT did not remain running. ${launchResult.stderr || launchResult.stdout}`);
  await sleep(8000);
  const renderer = rendererState(runtime, captureDir);
  const xml = dumpUI(runtime);
  fs.writeFileSync(path.join(captureDir, 'tft-ui.xml'), xml);
  const screencap = spawnSync(runtime.adb, ['-P', ADB_PORT, '-s', SERIAL, 'exec-out', 'screencap', '-p'], { env: runtime.env, encoding: null, maxBuffer: 32 * 1024 * 1024, timeout: 30000 });
  if (screencap.status === 0 && screencap.stdout) fs.writeFileSync(path.join(captureDir, 'tft-launch.png'), screencap.stdout);
  const riotAuth = findNodeByText(xml, [/sign in/i, /log in/i, /riot account/i]);
  return { action: riotAuth ? 'RIOT_AUTH_POSSIBLE' : 'TFT_RUNNING', pid, resolvedActivity: resolved || null, renderer, riotAuthEvidence: riotAuth ? { text: riotAuth.text, contentDescription: riotAuth.desc } : null, captureDir };
}

function processAlive(pid) { if (!pid) return false; try { process.kill(pid, 0); return true; } catch { return false; } }

function marker(kind = 'stutter') {
  const state = readJSON(CONTROL_STATE);
  if (!state?.captureDir) throw new Error('No active direct-control session.');
  const definitions = {
    stutter: { event: 'MANUAL_STUTTER_MARKER', source: 'F8' },
    'match-entry': { event: 'MATCH_ENTRY', source: 'control-observation' },
    'combat-start': { event: 'COMBAT_START', source: 'control-observation' }
  };
  const definition = definitions[kind];
  if (!definition) throw new Error(`Unsupported marker kind: ${kind}`);
  const event = { utc: nowISO(), host_mono_ns: monoNs().toString(), ...definition };
  appendJSONL(path.join(state.captureDir, 'markers.jsonl'), event);
  if (kind !== 'stutter') {
    const sessionPath = path.join(state.captureDir, 'session.json');
    const session = readJSON(sessionPath, {});
    if (kind === 'match-entry') session.matchEntryObserved = true;
    if (kind === 'combat-start') session.combatObserved = true;
    writeJSON(sessionPath, session);
  }
  return { action: 'MARKER_RECORDED', kind, captureDir: state.captureDir, marker: event };
}

async function status() {
  const runtime = discover();
  const state = readJSON(CONTROL_STATE);
  const ready = deviceReady(runtime);
  const pkg = ready ? packageState(runtime, state?.captureDir ?? null, false) : null;
  const pid = ready ? adb(runtime, ['shell', 'pidof', PACKAGE], { allowFailure: true }).stdout.trim() : '';
  const top = ready ? adb(runtime, ['shell', 'dumpsys', 'activity', 'activities'], { allowFailure: true }).stdout.split(/\r?\n/).filter(l => /mResumedActivity|topResumedActivity/i.test(l)).slice(0, 4) : [];
  const xml = ready ? dumpUI(runtime) : '';
  const googleAuth = xml ? findNodeByText(xml, [/sign in/i, /add account/i, /choose an account/i]) : null;
  const riotAuth = xml ? findNodeByText(xml, [/sign in/i, /log in/i, /riot account/i]) : null;
  return { activeSession: state, deviceReady: ready, samplerAlive: processAlive(state?.samplerPid), emulatorProcessAlive: processAlive(state?.emulatorPid), package: pkg, tftPid: pid || null, resumedActivity: top, googleAuthPossible: Boolean(googleAuth), riotAuthPossible: Boolean(pid && riotAuth), uiTextSample: xml.match(/text="([^"]+)"/g)?.slice(0, 20) ?? [] };
}

function recursiveSize(root) {
  let total = 0;
  const stack = [root];
  while (stack.length) {
    const p = stack.pop();
    let st; try { st = fs.lstatSync(p); } catch { continue; }
    if (st.isFile()) total += st.size;
    else if (st.isDirectory()) { try { for (const e of fs.readdirSync(p)) stack.push(path.join(p, e)); } catch {} }
  }
  return total;
}

function parseFrameStats(text) {
  const byIntended = new Map();
  let header = null;
  for (const line of text.split(/\r?\n/)) {
    if (line.startsWith('Flags,IntendedVsync')) { header = line.split(','); continue; }
    if (!header || !/^\d+,/.test(line)) continue;
    const parts = line.split(',');
    if (parts.length < header.length) continue;
    const rec = Object.fromEntries(header.map((h, i) => [h, parts[i]]));
    let intended, completed;
    try {
      intended = BigInt(rec.IntendedVsync || '0');
      completed = BigInt(rec.FrameCompleted || '0');
    } catch { continue; }
    if (intended <= 0n || completed <= 0n || completed < intended || completed >= 9000000000000000000n) continue;
    byIntended.set(intended.toString(), {
      intendedNs: intended,
      completedNs: completed,
      renderLatencyNs: completed - intended
    });
  }
  const rows = [...byIntended.values()].sort((a, b) => a.completedNs < b.completedNs ? -1 : a.completedNs > b.completedNs ? 1 : 0);
  let previous = null;
  for (let i = 0; i < rows.length; i += 1) {
    rows[i].frameNumber = i + 1;
    rows[i].intervalNs = previous === null ? null : rows[i].completedNs - previous;
    previous = rows[i].completedNs;
  }
  return rows;
}

function readJSONL(file) {
  if (!exists(file)) return [];
  return fs.readFileSync(file, 'utf8').split(/\r?\n/).filter(Boolean).flatMap(line => {
    try { return [JSON.parse(line)]; } catch { return []; }
  });
}

function csvEscape(value) {
  if (value === null || value === undefined) return '';
  const s = String(value);
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

function percentile(values, p) {
  if (!values.length) return null;
  const a = [...values].sort((x, y) => x - y);
  const idx = Math.min(a.length - 1, Math.max(0, Math.ceil(p * a.length) - 1));
  return a[idx];
}

function finalizeManifest(captureDir) {
  const entries = [];
  for (const file of walk(captureDir, 12, 50000)) {
    try { if (fs.statSync(file).isFile() && path.basename(file) !== 'manifest.sha256') entries.push(file); } catch {}
  }
  entries.sort();
  const lines = entries.map(file => `${sha256File(file)}  ${path.relative(captureDir, file)}`);
  fs.writeFileSync(path.join(captureDir, 'manifest.sha256'), `${lines.join('\n')}\n`);
  return sha256File(path.join(captureDir, 'manifest.sha256'));
}

function filterLogcat(captureDir) {
  const raw = path.join(captureDir, 'logcat.raw.txt');
  const filtered = path.join(captureDir, 'logcat.filtered.txt');
  if (!exists(raw)) { fs.writeFileSync(filtered, ''); return 0; }
  const matcher = /riot|teamfight|leagueoflegends|unreal|\bUE[45]\b|angle|gfxstream|moltenvk|vulkan|metal|surfaceflinger|choreographer|openglrenderer|\bEGL\b|graphicsenv|activitymanager|packagemanager|fatal exception|\bANR\b/i;
  const lines = fs.readFileSync(raw, 'utf8').split(/\r?\n/).filter(line => matcher.test(line));
  fs.writeFileSync(filtered, `${lines.join('\n')}${lines.length ? '\n' : ''}`);
  return lines.length;
}

function artifactId(sessionId, relativePath) {
  return `artifact_${crypto.createHash('sha256').update(`${sessionId}\0${relativePath}`).digest('hex').slice(0, 28)}`;
}

function asNumber(value) {
  if (value === null || value === undefined || value === '') return null;
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

function labSchemaPath() {
  const candidates = [
    path.join(scriptDir, 'TFTMAC_PERFORMANCE_LAB.sql'),
    path.join(repoRoot, 'ssot', 'TFTMAC_PERFORMANCE_LAB.sql')
  ];
  return candidates.find(exists) ?? null;
}

function labSelfTest() {
  const schemaPath = labSchemaPath();
  if (!schemaPath) throw new Error('TFTMAC performance-lab schema is unavailable.');
  const tempPath = `/private/tmp/tftmac-lab-selftest-${process.pid}-${Date.now()}.sqlite`;
  const db = new DatabaseSync(tempPath);
  try {
    db.exec(fs.readFileSync(schemaPath, 'utf8'));
    const control = db.prepare("SELECT id,vcpu,ram_mb,display_width,display_height,density_dpi,state FROM runtime_configs WHERE id='control_stock_direct_v0'").get();
    const experiment = db.prepare("SELECT id,state FROM experiments WHERE id='exp_control_direct_play'").get();
    return { schemaPath, control, experiment };
  } finally {
    try { db.close(); } catch {}
    try { fs.unlinkSync(tempPath); } catch {}
  }
}

function normalizePerformanceLab(captureDir, frames, metrics, storage, manifestSHA256) {
  ensureDir(DIAGNOSTICS_ROOT);
  const schemaPath = labSchemaPath();
  if (!schemaPath) throw new Error('TFTMAC performance-lab schema is unavailable.');
  const databasePath = path.join(DIAGNOSTICS_ROOT, 'TFTMAC_PERFORMANCE_LAB.sqlite');
  const initialize = !exists(databasePath) || fs.statSync(databasePath).size === 0;
  const db = new DatabaseSync(databasePath);
  try {
    if (initialize) db.exec(fs.readFileSync(schemaPath, 'utf8'));
    db.exec('PRAGMA foreign_keys = ON;');

    const session = readJSON(path.join(captureDir, 'session.json'), {});
    const runtime = readJSON(path.join(captureDir, 'runtime-state.json'), {});
    const pkg = readJSON(path.join(captureDir, 'package-state.json'), {});
    const renderer = readJSON(path.join(captureDir, 'renderer-state.json'), {});
    const markers = readJSONL(path.join(captureDir, 'markers.jsonl'));
    const clocks = readJSONL(path.join(captureDir, 'clock-sync.jsonl'));
    const processes = readJSONL(path.join(captureDir, 'host-process.jsonl'));
    const memories = readJSONL(path.join(captureDir, 'host-memory.jsonl'));
    const sessionId = session.sessionId;
    const semanticValid = session.packageAuthorityVerified === true
      && session.matchEntryObserved === true
      && session.combatObserved === true
      && frames.some(frame => frame.intervalNs !== null);
    const captureState = semanticValid ? 'COMPLETE' : 'PARTIAL';
    const workloadClass = semanticValid ? 'MIXED' : 'UNKNOWN';
    const packageStatePath = path.join(captureDir, 'package-state.json');
    const rendererStatePath = path.join(captureDir, 'renderer-state.json');

    db.exec('BEGIN IMMEDIATE;');
    try {
      db.prepare("UPDATE runtime_configs SET config_sha256=COALESCE(config_sha256, ?), graphics_transport=COALESCE(graphics_transport, ?), angle_mode=COALESCE(angle_mode, ?), vulkan_mode=COALESCE(vulkan_mode, ?), moltenvk_mode=COALESCE(moltenvk_mode, ?) WHERE id='control_stock_direct_v0'")
        .run(runtime.avdConfigSHA256 ?? null,
          runtime.observedGraphicsTransport ?? null,
          renderer?.angleSettings ? JSON.stringify(renderer.angleSettings) : null,
          renderer?.properties?.['ro.hardware.vulkan'] ?? null,
          (renderer?.hostGraphicsEvidence ?? []).some(line => /MoltenVK/i.test(line)) ? 'OBSERVED_IN_HOST_LOG' : null);

      db.prepare(`INSERT INTO sessions (
        id,runtime_config_id,started_utc,ended_utc,host_start_mono_ns,host_end_mono_ns,boot_class,workload_class,
        package_name,package_version_name,package_version_code,package_state_sha256,renderer_state_sha256,session_manifest_sha256,
        package_updated_during_session,capture_state,semantic_valid,invalid_reason,notes
      ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
      ON CONFLICT(id) DO UPDATE SET
        ended_utc=excluded.ended_utc,host_end_mono_ns=excluded.host_end_mono_ns,boot_class=excluded.boot_class,workload_class=excluded.workload_class,
        package_version_name=excluded.package_version_name,package_version_code=excluded.package_version_code,package_state_sha256=excluded.package_state_sha256,
        renderer_state_sha256=excluded.renderer_state_sha256,session_manifest_sha256=excluded.session_manifest_sha256,
        package_updated_during_session=excluded.package_updated_during_session,capture_state=excluded.capture_state,semantic_valid=excluded.semantic_valid,
        invalid_reason=excluded.invalid_reason,notes=excluded.notes`)
        .run(sessionId, 'control_stock_direct_v0', session.startedUTC ?? null, session.endedUTC ?? null,
          asNumber(session.hostStartMonoNs), asNumber(session.hostEndMonoNs), runtime.bootClass ?? 'UNKNOWN', workloadClass,
          PACKAGE, pkg.versionName ?? null, pkg.versionCode ?? null,
          exists(packageStatePath) ? sha256File(packageStatePath) : null,
          exists(rendererStatePath) ? sha256File(rendererStatePath) : null,
          manifestSHA256, session.packageUpdatedDuringSession ? 1 : 0, captureState, semanticValid ? 1 : 0,
          semanticValid ? null : 'Control capture did not yet prove official-current package + live match entry + combat + frame cadence.',
          `Google Play authority verified=${session.packageAuthorityVerified === true}; signer=${pkg.signerCertificateSHA256 ?? 'unavailable'}`);

      db.prepare('DELETE FROM evidence WHERE session_id=?').run(sessionId);
      db.prepare('DELETE FROM experiment_sessions WHERE experiment_id=? AND session_id=?').run('exp_control_direct_play', sessionId);
      for (const table of ['metrics','frame_samples','process_samples','memory_samples','markers','clock_sync','artifacts']) {
        db.prepare(`DELETE FROM ${table} WHERE session_id=?`).run(sessionId);
      }

      const requiredArtifacts = new Set([
        'session.json','runtime-state.json','package-state.json','renderer-state.json','host-events.jsonl','clock-sync.jsonl','markers.jsonl',
        'emulator.stdout.log','emulator.stderr.log','logcat.raw.txt','logcat.filtered.txt','host-process.csv','host-process.jsonl','host-memory.csv','host-memory.jsonl',
        'surfaceflinger/surfaceflinger.txt','gfxinfo/framestats.raw.txt','manifest.sha256'
      ]);
      const artifactByPath = new Map();
      const files = walk(captureDir, 12, 50000).filter(file => { try { return fs.statSync(file).isFile(); } catch { return false; } });
      const observedRel = new Set(files.map(file => path.relative(captureDir, file)));
      const artifactStmt = db.prepare('INSERT INTO artifacts(id,session_id,experiment_id,artifact_kind,path,sha256,byte_count,required,state,created_at,notes) VALUES(?,?,?,?,?,?,?,?,?,?,?)');
      for (const file of files) {
        const rel = path.relative(captureDir, file);
        const id = artifactId(sessionId, rel);
        artifactByPath.set(rel, id);
        const stat = fs.statSync(file);
        artifactStmt.run(id, sessionId, null, path.extname(rel).replace(/^\./, '').toUpperCase() || 'FILE', rel, sha256File(file), stat.size, requiredArtifacts.has(rel) ? 1 : 0, 'PRESENT', session.endedUTC ?? nowISO(), null);
      }
      for (const rel of requiredArtifacts) {
        if (observedRel.has(rel)) continue;
        const id = artifactId(sessionId, rel);
        artifactByPath.set(rel, id);
        artifactStmt.run(id, sessionId, null, 'REQUIRED_CONTROL_ARTIFACT', rel, null, null, 1, 'MISSING', session.endedUTC ?? nowISO(), 'Required by TFTMAC_DIRECT_PLAY_CONTROL_BUILD.md');
      }

      const clockStmt = db.prepare('INSERT INTO clock_sync(session_id,host_t0_ns,guest_mono_ns,host_t1_ns,host_midpoint_ns,rtt_ns,estimated_offset_ns,source) VALUES(?,?,?,?,?,?,?,?)');
      for (const row of clocks) {
        if ([row.host_t0_ns,row.guest_mono_ns,row.host_t1_ns,row.host_midpoint_ns,row.rtt_ns,row.estimated_offset_ns].some(v => asNumber(v) === null)) continue;
        clockStmt.run(sessionId, asNumber(row.host_t0_ns), asNumber(row.guest_mono_ns), asNumber(row.host_t1_ns), asNumber(row.host_midpoint_ns), asNumber(row.rtt_ns), asNumber(row.estimated_offset_ns), row.source ?? '/proc/uptime');
      }

      const markerStmt = db.prepare('INSERT INTO markers(session_id,host_mono_ns,guest_mono_ns,marker_type,label,payload_json) VALUES(?,?,?,?,?,?)');
      for (const row of markers) {
        const type = row.event === 'MANUAL_STUTTER_MARKER' ? 'USER_STUTTER'
          : row.event === 'MATCH_ENTRY' ? 'MATCH_ENTRY'
          : row.event === 'COMBAT_START' ? 'COMBAT_START'
          : row.event === 'PACKAGE_UPDATE' ? 'PACKAGE_UPDATE'
          : 'CUSTOM';
        markerStmt.run(sessionId, asNumber(row.host_mono_ns) ?? asNumber(session.hostStartMonoNs) ?? 0, null, type, row.event ?? null, JSON.stringify(row));
      }

      const frameArtifact = artifactByPath.get('gfxinfo/framestats.raw.txt') ?? null;
      const frameStmt = db.prepare('INSERT INTO frame_samples(session_id,source,surface_name,frame_number,presentation_host_ns,presentation_guest_ns,frame_interval_ns,classification,raw_artifact_id) VALUES(?,?,?,?,?,?,?,?,?)');
      for (const row of frames) {
        const interval = row.intervalNs === null ? null : Number(row.intervalNs);
        const classification = interval === null ? 'UNKNOWN' : interval > 100000000 ? 'SEVERE_STALL' : interval > 33334000 ? 'JANK' : 'NORMAL';
        frameStmt.run(sessionId, 'gfxinfo_framestats', null, row.frameNumber, null, Number(row.completedNs), interval, classification, frameArtifact);
      }

      const processArtifact = artifactByPath.get('host-process.jsonl') ?? null;
      const processStmt = db.prepare('INSERT INTO process_samples(session_id,host_mono_ns,scope,process_name,pid,tid,cpu_pct,cpu_time_ns,rss_bytes,thread_count,nice_value,process_state,raw_artifact_id) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)');
      const emulatorRSSByMono = new Map();
      for (const row of processes) {
        const mono = asNumber(row.host_mono_ns);
        if (mono === null) continue;
        const rssBytes = asNumber(row.rss_kb) === null ? null : Number(row.rss_kb) * 1024;
        processStmt.run(sessionId, mono, 'HOST', path.basename(row.command ?? 'unknown'), asNumber(row.pid), null, asNumber(row.cpu_pct), null, rssBytes, null, asNumber(row.nice), row.state ?? null, processArtifact);
        if (/emulator|qemu/i.test(row.command ?? '') && rssBytes !== null) emulatorRSSByMono.set(String(row.host_mono_ns), Math.max(emulatorRSSByMono.get(String(row.host_mono_ns)) ?? 0, rssBytes));
      }

      const memoryArtifact = artifactByPath.get('host-memory.jsonl') ?? null;
      const memoryStmt = db.prepare('INSERT INTO memory_samples(session_id,host_mono_ns,host_used_bytes,host_available_bytes,host_compressed_bytes,host_swap_used_bytes,host_pressure_state,guest_total_bytes,guest_available_bytes,emulator_rss_bytes,pagein_count,pageout_count,raw_artifact_id) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)');
      for (const row of memories) {
        const mono = asNumber(row.host_mono_ns);
        if (mono === null) continue;
        memoryStmt.run(sessionId, mono, asNumber(row.host_used_bytes), asNumber(row.host_available_bytes), asNumber(row.host_compressed_bytes), asNumber(row.host_swap_used_bytes), null,
          asNumber(row.guest_total_bytes), asNumber(row.guest_available_bytes), emulatorRSSByMono.get(String(row.host_mono_ns)) ?? null,
          asNumber(row.pagein_count), asNumber(row.pageout_count), memoryArtifact);
      }

      const metricStmt = db.prepare('INSERT INTO metrics(session_id,experiment_id,metric_scope,metric_name,metric_value,unit,source_artifact_id,semantic_valid,notes) VALUES(?,?,?,?,?,?,?,?,?)');
      const metricRows = [
        ['FRAME','frame_sample_count',metrics.frameSampleCount,'count'],
        ['FRAME','presented_fps_approx',metrics.presentedFPSApprox,'fps'],
        ['FRAME','mean_frame_interval_ms',metrics.meanFrameMs,'ms'],
        ['FRAME','p50_frame_interval_ms',metrics.p50FrameMs,'ms'],
        ['FRAME','p95_frame_interval_ms',metrics.p95FrameMs,'ms'],
        ['FRAME','p99_frame_interval_ms',metrics.p99FrameMs,'ms'],
        ['FRAME','jank_pct',metrics.jankPct,'percent'],
        ['FRAME','severe_stall_count',metrics.severeStallCount,'count'],
        ['STORAGE','sdk_bytes',storage.sdkBytes,'bytes'],
        ['STORAGE','avd_bytes',storage.avdBytes,'bytes'],
        ['STORAGE','capture_bytes',storage.captureBytes,'bytes']
      ];
      for (const [scope,name,value,unit] of metricRows) {
        if (value === null || value === undefined || !Number.isFinite(Number(value))) continue;
        metricStmt.run(sessionId, null, scope, name, Number(value), unit, scope === 'FRAME' ? (artifactByPath.get('frame-metrics.json') ?? frameArtifact) : (artifactByPath.get('storage-bom.json') ?? null), semanticValid ? 1 : 0, null);
      }

      const packageArtifact = artifactByPath.get('package-state.json') ?? null;
      const rendererArtifact = artifactByPath.get('renderer-state.json') ?? null;
      if (session.packageAuthorityVerified === true && pkg.versionName) {
        db.prepare('INSERT INTO evidence(id,hypothesis_id,session_id,experiment_id,evidence_type,claim,relation,strength,source_artifact_id,created_at,notes) VALUES(?,?,?,?,?,?,?,?,?,?,?)')
          .run(`evidence_pkg_${sessionId}`, null, sessionId, null, 'CONFIG_OBSERVATION', `Google Play authority observed official TFT ${pkg.versionName} (${pkg.versionCode ?? 'unknown code'}).`, 'SUPPORTS', 'STRONG', packageArtifact, session.endedUTC ?? nowISO(), `Signer SHA-256: ${pkg.signerCertificateSHA256 ?? 'unavailable'}`);
        db.prepare("UPDATE unknowns SET status='RESOLVED', resolved_at=?, notes=? WHERE id='u_current_tft_version'")
          .run(session.endedUTC ?? nowISO(), `${pkg.versionName} / ${pkg.versionCode ?? 'unknown code'} / signer ${pkg.signerCertificateSHA256 ?? 'unavailable'}`);
      }
      if (exists(rendererStatePath)) {
        db.prepare('INSERT INTO evidence(id,hypothesis_id,session_id,experiment_id,evidence_type,claim,relation,strength,source_artifact_id,created_at,notes) VALUES(?,?,?,?,?,?,?,?,?,?,?)')
          .run(`evidence_renderer_${sessionId}`, null, sessionId, null, 'CONFIG_OBSERVATION', 'Renderer state was captured directly from the current stock control.', 'SUPPORTS', 'STRONG', rendererArtifact, session.endedUTC ?? nowISO(), JSON.stringify(renderer.properties ?? {}));
        db.prepare("UPDATE unknowns SET status='RESOLVED', resolved_at=?, notes=? WHERE id='u_observed_renderer_path'")
          .run(session.endedUTC ?? nowISO(), JSON.stringify({ properties: renderer.properties ?? {}, hostGraphicsEvidence: (renderer.hostGraphicsEvidence ?? []).slice(-20) }));
      }
      db.prepare("UPDATE unknowns SET status='RESOLVED', resolved_at=?, notes=? WHERE id='u_storage_bom'")
        .run(session.endedUTC ?? nowISO(), JSON.stringify(storage));

      if (semanticValid) {
        db.prepare("INSERT OR REPLACE INTO experiment_sessions(experiment_id,session_id,role) VALUES('exp_control_direct_play',?,'BASELINE')").run(sessionId);
        db.prepare("UPDATE experiments SET state='COMPLETE', completed_at=?, notes=? WHERE id='exp_control_direct_play'")
          .run(session.endedUTC ?? nowISO(), `Completed official-current live-match control session ${sessionId}.`);
      }
      db.exec('COMMIT;');
    } catch (error) {
      try { db.exec('ROLLBACK;'); } catch {}
      throw error;
    }

    const quality = db.prepare('SELECT * FROM v_session_quality WHERE session_id=?').get(session.sessionId);
    const stall = db.prepare('SELECT * FROM v_stall_summary WHERE session_id=?').get(session.sessionId);
    db.close();
    const result = {
      databasePath,
      databaseSHA256: sha256File(databasePath),
      initializedFromSchema: initialize,
      semanticValid,
      captureState,
      quality: quality ?? null,
      stallSummary: stall ?? null
    };
    writeJSON(path.join(captureDir, 'normalization.json'), result);
    return result;
  } catch (error) {
    try { db.close(); } catch {}
    throw error;
  }
}

async function stopControl() {
  const runtime = discover();
  const state = readJSON(CONTROL_STATE);
  if (!state?.captureDir) throw new Error('No active direct-control session.');
  const captureDir = state.captureDir;
  if (deviceReady(runtime)) {
    packageState(runtime, captureDir);
    rendererState(runtime, captureDir);
    const finalGfx = adb(runtime, ['shell', 'dumpsys', 'gfxinfo', PACKAGE, 'framestats'], { allowFailure: true, timeout: 30000 }).stdout;
    fs.appendFileSync(path.join(captureDir, 'gfxinfo', 'framestats.raw.txt'), `\n# ${nowISO()} final\n${finalGfx}\n`);
  }
  if (processAlive(state.samplerPid)) { try { process.kill(state.samplerPid, 'SIGTERM'); } catch {} }
  for (let i = 0; i < 10 && processAlive(state.samplerPid); i += 1) await sleep(500);
  const filteredLogLines = filterLogcat(captureDir);

  const frameText = exists(path.join(captureDir, 'gfxinfo', 'framestats.raw.txt')) ? fs.readFileSync(path.join(captureDir, 'gfxinfo', 'framestats.raw.txt'), 'utf8') : '';
  const frames = parseFrameStats(frameText);
  const frameMs = frames.flatMap(row => row.intervalNs === null ? [] : [Number(row.intervalNs) / 1e6]).filter(v => Number.isFinite(v) && v > 0 && v < 10000);
  const renderLatencyMs = frames.map(row => Number(row.renderLatencyNs) / 1e6).filter(v => Number.isFinite(v) && v >= 0 && v < 10000);
  const metrics = {
    frameSampleCount: frameMs.length,
    meanFrameMs: frameMs.length ? frameMs.reduce((a, b) => a + b, 0) / frameMs.length : null,
    p50FrameMs: percentile(frameMs, 0.50),
    p95FrameMs: percentile(frameMs, 0.95),
    p99FrameMs: percentile(frameMs, 0.99),
    maxFrameMs: frameMs.length ? Math.max(...frameMs) : null,
    meanRenderLatencyMs: renderLatencyMs.length ? renderLatencyMs.reduce((a, b) => a + b, 0) / renderLatencyMs.length : null,
    jankCount: frameMs.filter(v => v > 33.334).length,
    severeStallCount: frameMs.filter(v => v > 100).length,
    filteredLogLines
  };
  metrics.jankPct = frameMs.length ? metrics.jankCount * 100 / frameMs.length : null;
  metrics.presentedFPSApprox = metrics.meanFrameMs && metrics.meanFrameMs > 0 ? 1000 / metrics.meanFrameMs : null;
  writeJSON(path.join(captureDir, 'frame-metrics.json'), metrics);

  const pkg = readJSON(path.join(captureDir, 'package-state.json'), {});
  const runtimeBytes = recursiveSize(runtime.sdkRoot);
  const avdBytes = runtime.avdDir ? recursiveSize(runtime.avdDir) : null;
  const packageGuestBytes = Object.values(pkg.apkBytes ?? {}).reduce((sum, value) => sum + (Number(value) || 0), 0) || null;
  const storage = {
    observedAt: nowISO(),
    sdkBytes: runtimeBytes,
    avdBytes,
    packageGuestBytes,
    captureBytes: recursiveSize(captureDir),
    provisionalCeilingBytes: 35 * 1024 ** 3
  };
  writeJSON(path.join(captureDir, 'storage-bom.json'), storage);
  storage.captureBytes = recursiveSize(captureDir);
  writeJSON(path.join(captureDir, 'storage-bom.json'), storage);

  const sessionPath = path.join(captureDir, 'session.json');
  const session = readJSON(sessionPath, {});
  session.endedUTC = nowISO();
  session.hostEndMonoNs = monoNs().toString();
  session.semanticValid = session.packageAuthorityVerified === true && session.matchEntryObserved === true && session.combatObserved === true && frameMs.length > 0;
  session.captureState = session.semanticValid ? 'COMPLETE' : 'PARTIAL';
  writeJSON(sessionPath, session);

  const manifestSHA256 = finalizeManifest(captureDir);
  const normalization = normalizePerformanceLab(captureDir, frames, metrics, storage, manifestSHA256);
  const controlResult = { sessionId: state.sessionId, manifestSHA256, metrics, storage, normalization };
  writeJSON(path.join(captureDir, 'control-result.json'), controlResult);
  const result = { sessionId: state.sessionId, captureDir, ...controlResult };
  try { adb(runtime, ['emu', 'kill'], { allowFailure: true, timeout: 10000 }); } catch {}
  try { fs.unlinkSync(CONTROL_STATE); } catch {}
  return result;
}

function numberFromStat(value) {
  const cleaned = String(value ?? '').replace(/[^0-9]/g, '');
  return cleaned ? Number(cleaned) : 0;
}

function parseMeminfo(text) {
  const values = {};
  for (const line of text.split(/\r?\n/)) {
    const m = line.match(/^([^:]+):\s+(\d+)\s+kB$/);
    if (m) values[m[1]] = Number(m[2]) * 1024;
  }
  return values;
}

function parseSwapUsedBytes(text) {
  const m = text.match(/used\s*=\s*([0-9.]+)([KMGTP])?/i);
  if (!m) return null;
  const scale = { K: 1024, M: 1024 ** 2, G: 1024 ** 3, T: 1024 ** 4, P: 1024 ** 5 }[m[2]?.toUpperCase()] ?? 1;
  return Math.round(Number(m[1]) * scale);
}

function normalizedMemory(vmText, guestMeminfoText, swapUsedBytes, hostMonoNs, utc) {
  const parsed = parseKeyValueLines(vmText);
  const pageSize = Number(vmText.match(/page size of (\d+) bytes/i)?.[1] ?? 16384);
  const pagesFree = numberFromStat(parsed['Pages free']);
  const pagesInactive = numberFromStat(parsed['Pages inactive']);
  const pagesSpeculative = numberFromStat(parsed['Pages speculative']);
  const pagesCompressed = numberFromStat(parsed['Pages occupied by compressor']);
  const available = (pagesFree + pagesInactive + pagesSpeculative) * pageSize;
  const total = os.totalmem();
  const guest = parseMeminfo(guestMeminfoText);
  return {
    utc,
    host_mono_ns: hostMonoNs,
    host_total_bytes: total,
    host_used_bytes: Math.max(0, total - available),
    host_available_bytes: available,
    host_compressed_bytes: pagesCompressed * pageSize,
    host_swap_used_bytes: swapUsedBytes,
    pagein_count: numberFromStat(parsed['Pageins']),
    pageout_count: numberFromStat(parsed['Pageouts']),
    guest_total_bytes: guest.MemTotal ?? null,
    guest_available_bytes: guest.MemAvailable ?? guest.MemFree ?? null,
    vm_stat: parsed
  };
}

async function sampler(captureDir, sessionId) {
  ensureDir(path.join(captureDir, 'surfaceflinger')); ensureDir(path.join(captureDir, 'gfxinfo'));
  const runtime = discover();
  const procFile = path.join(captureDir, 'host-process.csv');
  const procJSONL = path.join(captureDir, 'host-process.jsonl');
  const memFile = path.join(captureDir, 'host-memory.jsonl');
  const memCSV = path.join(captureDir, 'host-memory.csv');
  const clockFile = path.join(captureDir, 'clock-sync.jsonl');
  const eventsFile = path.join(captureDir, 'host-events.jsonl');
  if (!exists(procFile)) fs.writeFileSync(procFile, 'utc,host_mono_ns,pid,ppid,cpu_pct,rss_kb,nice,state,command\n');
  if (!exists(memCSV)) fs.writeFileSync(memCSV, 'utc,host_mono_ns,host_total_bytes,host_used_bytes,host_available_bytes,host_compressed_bytes,host_swap_used_bytes,pagein_count,pageout_count,guest_total_bytes,guest_available_bytes\n');
  let stopped = false;
  let logcatProc = null;
  let lastSwapUsedBytes = null;
  process.on('SIGTERM', () => { stopped = true; });
  process.on('SIGINT', () => { stopped = true; });
  let tick = 0;
  while (!stopped) {
    const utc = nowISO();
    const hostMonoNs = monoNs().toString();
    const ps = command('/bin/ps', ['-axo', 'pid=,ppid=,%cpu=,rss=,nice=,state=,comm='], { allowFailure: true, timeout: 10000 }).stdout;
    for (const line of ps.split(/\r?\n/)) {
      if (!/emulator|qemu|TFTMAC|tftmac/i.test(line)) continue;
      const m = line.trim().match(/^(\d+)\s+(\d+)\s+([\d.]+)\s+(\d+)\s+(-?\d+)\s+(\S+)\s+(.+)$/);
      if (!m) continue;
      const sample = { utc, host_mono_ns: hostMonoNs, pid: Number(m[1]), ppid: Number(m[2]), cpu_pct: Number(m[3]), rss_kb: Number(m[4]), nice: Number(m[5]), state: m[6], command: m[7] };
      fs.appendFileSync(procFile, [sample.utc, sample.host_mono_ns, sample.pid, sample.ppid, sample.cpu_pct, sample.rss_kb, sample.nice, sample.state, sample.command].map(csvEscape).join(',') + '\n');
      appendJSONL(procJSONL, sample);
    }
    const vm = command('/usr/bin/vm_stat', [], { allowFailure: true, timeout: 10000 }).stdout;
    if (tick % 5 === 0) {
      const swap = command('/usr/sbin/sysctl', ['vm.swapusage'], { allowFailure: true, timeout: 10000 }).stdout;
      lastSwapUsedBytes = parseSwapUsedBytes(swap);
    }
    const readyNow = deviceReady(runtime);
    const guestMem = readyNow ? adb(runtime, ['shell', 'cat', '/proc/meminfo'], { allowFailure: true, timeout: 10000 }).stdout : '';
    const memory = normalizedMemory(vm, guestMem, lastSwapUsedBytes, hostMonoNs, utc);
    appendJSONL(memFile, memory);
    fs.appendFileSync(memCSV, [memory.utc, memory.host_mono_ns, memory.host_total_bytes, memory.host_used_bytes, memory.host_available_bytes, memory.host_compressed_bytes, memory.host_swap_used_bytes, memory.pagein_count, memory.pageout_count, memory.guest_total_bytes, memory.guest_available_bytes].map(csvEscape).join(',') + '\n');
    if (readyNow) {
      if (!logcatProc || logcatProc.exitCode !== null) {
        const fd = fs.openSync(path.join(captureDir, 'logcat.raw.txt'), 'a');
        const err = fs.openSync(path.join(captureDir, 'logcat.stderr.log'), 'a');
        logcatProc = spawn(runtime.adb, ['-P', ADB_PORT, '-s', SERIAL, 'logcat', '-v', 'threadtime'], { env: runtime.env, stdio: ['ignore', fd, err] });
        appendJSONL(eventsFile, { utc: nowISO(), event: 'LOGCAT_STARTED', pid: logcatProc.pid });
      }
      if (tick % 7 === 0) {
        const t0 = monoNs();
        const uptime = adb(runtime, ['shell', 'cat', '/proc/uptime'], { allowFailure: true, timeout: 10000 }).stdout.trim();
        const t1 = monoNs();
        const seconds = Number(uptime.split(/\s+/)[0]);
        if (Number.isFinite(seconds)) {
          const guest = BigInt(Math.round(seconds * 1e9));
          const midpoint = (t0 + t1) / 2n;
          appendJSONL(clockFile, { utc: nowISO(), host_t0_ns: t0.toString(), guest_mono_ns: guest.toString(), host_t1_ns: t1.toString(), host_midpoint_ns: midpoint.toString(), rtt_ns: (t1 - t0).toString(), estimated_offset_ns: (midpoint - guest).toString(), source: '/proc/uptime' });
        }
      }
      if (tick % 3 === 0) {
        const gfx = adb(runtime, ['shell', 'dumpsys', 'gfxinfo', PACKAGE, 'framestats'], { allowFailure: true, timeout: 15000 }).stdout;
        fs.appendFileSync(path.join(captureDir, 'gfxinfo', 'framestats.raw.txt'), `\n# ${utc}\n${gfx}\n`);
      }
    }
    tick += 1;
    await sleep(2000);
  }
  if (logcatProc && logcatProc.exitCode === null) { try { logcatProc.kill('SIGTERM'); } catch {} }
  appendJSONL(eventsFile, { utc: nowISO(), event: 'SAMPLER_STOPPED', sessionId });
}

function buildApp() {
  const sourcesDir = path.join(repoRoot, 'tftmac', 'Sources');
  const sources = fs.readdirSync(sourcesDir).filter(n => n.endsWith('.swift')).map(n => path.join(sourcesDir, n));
  const dist = path.join(repoRoot, 'dist');
  const app = path.join(dist, 'TFTMAC.app');
  const contents = path.join(app, 'Contents');
  const macos = path.join(contents, 'MacOS');
  ensureDir(macos); ensureDir(path.join(contents, 'Resources'));
  fs.rmSync(app, { recursive: true, force: true });
  ensureDir(macos); ensureDir(path.join(contents, 'Resources'));
  const binary = path.join(macos, 'TFTMAC');
  const developerCandidates = [
    '/Applications/Xcode-26.6.0.app/Contents/Developer',
    path.join(USER_HOME, 'Downloads', 'Xcode.app', 'Contents', 'Developer')
  ];
  const developerDir = developerCandidates.find(candidate => exists(path.join(candidate, 'usr', 'bin', 'xcodebuild')) || exists(path.join(candidate, 'Toolchains', 'XcodeDefault.xctoolchain', 'usr', 'bin', 'swiftc')));
  if (!developerDir) throw new Error('Xcode 26.6 / 17F113 developer directory was not found.');
  const xcodeEnv = { ...process.env, DEVELOPER_DIR: developerDir };
  const version = command('/usr/bin/xcodebuild', ['-version'], { env: xcodeEnv }).stdout.trim();
  if (!/Xcode 26\.6\b/.test(version) || !/Build version 17F113\b/.test(version)) throw new Error(`Wrong Xcode selected for control build: ${version}`);
  const swiftc = command('/usr/bin/xcrun', ['--find', 'swiftc'], { env: xcodeEnv }).stdout.trim();
  const sdkPath = command('/usr/bin/xcrun', ['--sdk', 'macosx', '--show-sdk-path'], { env: xcodeEnv }).stdout.trim();
  command(swiftc, ['-O', '-parse-as-library', '-target', 'arm64-apple-macosx14.0', '-sdk', sdkPath, ...sources, '-o', binary], { timeout: 240000, env: xcodeEnv });
  fs.copyFileSync(path.join(repoRoot, 'tftmac', 'Info.plist'), path.join(contents, 'Info.plist'));
  fs.copyFileSync(scriptPath, path.join(contents, 'Resources', 'tftmac-direct-control.mjs'));
  const labSource = path.join(repoRoot, 'ssot', 'TFTMAC_PERFORMANCE_LAB.sql');
  if (exists(labSource)) fs.copyFileSync(labSource, path.join(contents, 'Resources', 'TFTMAC_PERFORMANCE_LAB.sql'));
  fs.writeFileSync(path.join(contents, 'Resources', 'build-commit.txt'), `${currentGitSha()}\n`);
  command('/usr/bin/codesign', ['--force', '--sign', '-', '--timestamp=none', app], { timeout: 120000 });
  command('/usr/bin/codesign', ['--verify', '--deep', '--strict', '--verbose=2', app], { timeout: 120000 });
  return { app, binary, binarySHA256: sha256File(binary), infoPlistSHA256: sha256File(path.join(contents, 'Info.plist')) };
}

function launchApp() {
  const app = path.join(repoRoot, 'dist', 'TFTMAC.app');
  if (!exists(app)) throw new Error('TFTMAC.app has not been built. Run build first.');
  const result = command('/usr/bin/open', ['-n', app], { allowFailure: true, timeout: 30000 });
  return { app, openStatus: result.status, stderr: result.stderr.trim() || null };
}

async function main() {
  const [action, ...args] = process.argv.slice(2);
  if (action === 'inventory') {
    const r = discover();
    const avdConfig = r.avdConfig ? parseKeyValueLines(r.avdConfig) : null;
    json({ externalVolumeMounted: exists('/Volumes/MAC MINI M4'), externalRoot: r.externalRoot, appSupportRuntime: r.appSupportRuntime, sdkRoot: r.sdkRoot, emulatorVersion: r.emulatorVersion, adbVersion: r.adbVersion, requiredImagePresent: r.requiredImagePresent, requiredImagePath: r.requiredImagePath, avdName: AVD_NAME, avdIni: r.avdIni, avdHome: r.avdHome, avdDir: r.avdDir, avdConfig: avdConfig ? { imageSysdir: avdConfig['image.sysdir.1'] ?? null, cpuArch: avdConfig['hw.cpu.arch'] ?? null, ramSize: avdConfig['hw.ramSize'] ?? null, lcdWidth: avdConfig['hw.lcd.width'] ?? null, lcdHeight: avdConfig['hw.lcd.height'] ?? null, lcdDensity: avdConfig['hw.lcd.density'] ?? null, gpuEnabled: avdConfig['hw.gpu.enabled'] ?? null, gpuMode: avdConfig['hw.gpu.mode'] ?? null, playStoreEnabled: avdConfig['PlayStore.enabled'] ?? null } : null, sdkRoots: r.sdkRoots, avdIniCandidates: r.avdIniCandidates });
    return;
  }
  if (action === 'prepare') { json(prepareAVD()); return; }
  if (action === 'lab-selftest') { json(labSelfTest()); return; }
  if (action === 'build') { json(buildApp()); return; }
  if (action === 'launch-app') { json(launchApp()); return; }
  if (action === 'start') { json(await startControl()); return; }
  if (action === 'play-action') { json(await playAction()); return; }
  if (action === 'launch-game') { json(await launchGame()); return; }
  if (action === 'status') { json(await status()); return; }
  if (action === 'marker') { json(marker('stutter')); return; }
  if (action === 'match-entry') { json(marker('match-entry')); return; }
  if (action === 'combat-start') { json(marker('combat-start')); return; }
  if (action === 'stop') { json(await stopControl()); return; }
  if (action === 'package-state') { const r = discover(); json(packageState(r)); return; }
  if (action === 'sampler') {
    const captureIndex = args.indexOf('--capture');
    const sessionIndex = args.indexOf('--session');
    if (captureIndex < 0 || sessionIndex < 0) throw new Error('sampler requires --capture and --session');
    await sampler(args[captureIndex + 1], args[sessionIndex + 1]);
    return;
  }
  throw new Error('Usage: tftmac-direct-control.mjs inventory|prepare|lab-selftest|build|launch-app|start|play-action|launch-game|status|marker|match-entry|combat-start|stop|package-state');
}

main().catch(error => { process.stderr.write(`${error.stack || error.message}\n`); process.exit(1); });
