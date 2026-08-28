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
const PLAY_PROBE_PACKAGE = 'com.openai.chatgpt';
const RIOT_SIGNER_SHA256 = '931d969502f3de01a4c239e4199211ebdc57bb9a7526394b9e3e2d1cc079ff0c';
const AVD_NAME = 'TFT_Ultra_Tablet';
const PLAY_DEVICE_ID = '13.5in Freeform';
const PLAY_PROFILE_LABEL = 'TFT Ultra Tablet - 13.5in Freeform / Galaxy Tab S10 Ultra-class';
const PLAY_DISPLAY_WIDTH = 2960;
const PLAY_DISPLAY_HEIGHT = 1848;
const PLAY_DISPLAY_DENSITY = 320;
const PLAY_RAM_MB = 8192;
const DONOR_PROFILE = Object.freeze({
  id: 'mactician_compatible_official_v0',
  label: 'Mactician-compatible official TFT control',
  width: 1920,
  height: 1080,
  density: 320,
  vcpu: 6,
  ramMB: 6144,
  refreshHz: 60,
  glTransport: 'virtio-gpu-asg',
  asgWriteBufferSize: 1048576,
  asgWriteStepSize: 16384,
  asgDataRingSize: 32768,
  drawFlushInterval: 800,
  featureList: 'GLESDynamicVersion,Vulkan,GuestAngle,-GLPipeChecksum,VulkanBatchedDescriptorSetUpdate,AsyncComposeSupport,VirtioGpuFenceContexts',
  angleEnabledFeatures: 'exposeNonConformantExtensionsAndVersions:exposeES32ForTesting',
  angleDisabledFeatures: 'preferSubmitAtFBOBoundary'
});
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
const IMAGE_UPGRADE_STATE = path.join(STATE_ROOT, 'image-upgrade.json');
const IMAGE_UPGRADE_STDOUT = path.join(APP_SUPPORT, 'Logs', 'image-upgrade.stdout.log');
const IMAGE_UPGRADE_STDERR = path.join(APP_SUPPORT, 'Logs', 'image-upgrade.stderr.log');
const REQUIRED_IMAGE = 'system-images;android-36;google_apis_playstore;arm64-v8a';
const REQUIRED_IMAGE_MIN_REVISION = 7;
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
    maxBuffer: options.maxBuffer ?? 32 * 1024 * 1024,
    input: options.input
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

  const imagePkg = path.join(sdkRoot, ...REQUIRED_IMAGE.split(';'));
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

function hostTimeZoneId() {
  return Intl.DateTimeFormat().resolvedOptions().timeZone || null;
}

function hostUtcOffsetString() {
  const minutesEast = -new Date().getTimezoneOffset();
  const sign = minutesEast >= 0 ? '+' : '-';
  const absolute = Math.abs(minutesEast);
  return `${sign}${String(Math.floor(absolute / 60)).padStart(2, '0')}${String(absolute % 60).padStart(2, '0')}`;
}

async function ensureGuestClock(runtime, captureDir = null) {
  const setAutoTime = adb(runtime, ['shell', 'settings', 'put', 'global', 'auto_time', '1'], { allowFailure: true, timeout: 10000 });
  const setAutoZone = adb(runtime, ['shell', 'settings', 'put', 'global', 'auto_time_zone', '1'], { allowFailure: true, timeout: 10000 });
  await sleep(1500);
  let best = null;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    const hostBeforeMs = Date.now();
    const guestEpochRaw = adb(runtime, ['shell', 'date', '+%s'], { allowFailure: true, timeout: 10000 }).stdout.trim();
    const hostAfterMs = Date.now();
    const guestEpochSeconds = Number(guestEpochRaw);
    const hostMidpointSeconds = (hostBeforeMs + hostAfterMs) / 2000;
    const skewSeconds = Number.isFinite(guestEpochSeconds) ? Math.abs(guestEpochSeconds - hostMidpointSeconds) : null;
    const sample = {
      observedAt: nowISO(),
      attempt: attempt + 1,
      hostEpochSeconds: hostMidpointSeconds,
      guestEpochSeconds: Number.isFinite(guestEpochSeconds) ? guestEpochSeconds : null,
      absoluteSkewSeconds: skewSeconds,
      hostTimeZone: hostTimeZoneId(),
      hostUtcOffset: hostUtcOffsetString(),
      guestUtcOffset: adb(runtime, ['shell', 'date', '+%z'], { allowFailure: true, timeout: 10000 }).stdout.trim() || null,
      guestTimeZone: adb(runtime, ['shell', 'getprop', 'persist.sys.timezone'], { allowFailure: true, timeout: 10000 }).stdout.trim() || null,
      autoTime: adb(runtime, ['shell', 'settings', 'get', 'global', 'auto_time'], { allowFailure: true, timeout: 10000 }).stdout.trim(),
      autoTimeZone: adb(runtime, ['shell', 'settings', 'get', 'global', 'auto_time_zone'], { allowFailure: true, timeout: 10000 }).stdout.trim(),
      setAutoTimeStatus: setAutoTime.status,
      setAutoTimeZoneStatus: setAutoZone.status
    };
    if (!best || (sample.absoluteSkewSeconds ?? Number.POSITIVE_INFINITY) < (best.absoluteSkewSeconds ?? Number.POSITIVE_INFINITY)) best = sample;
    if (sample.autoTime === '1' && sample.autoTimeZone === '1' && sample.absoluteSkewSeconds !== null && sample.absoluteSkewSeconds <= 5 && (!sample.guestUtcOffset || sample.guestUtcOffset === sample.hostUtcOffset)) break;
    await sleep(1000);
  }
  if (captureDir && best) {
    writeJSON(path.join(captureDir, 'clock-preflight.json'), best);
    appendJSONL(path.join(captureDir, 'host-events.jsonl'), { utc: nowISO(), event: 'CLOCK_PREFLIGHT', ...best });
  }
  if (!best || best.autoTime !== '1' || best.autoTimeZone !== '1') throw new Error(`PLAY_CLOCK_PREFLIGHT_FAILED: automatic time settings are not enabled (${JSON.stringify(best)}).`);
  if (best.absoluteSkewSeconds === null || best.absoluteSkewSeconds > 5) throw new Error(`PLAY_CLOCK_PREFLIGHT_FAILED: guest clock skew is ${best.absoluteSkewSeconds ?? 'unknown'} seconds.`);
  if (best.guestUtcOffset && best.guestUtcOffset !== best.hostUtcOffset) throw new Error(`PLAY_CLOCK_PREFLIGHT_FAILED: guest UTC offset ${best.guestUtcOffset} does not match host ${best.hostUtcOffset}.`);
  return best;
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

function resolvedComponent(text) {
  return String(text ?? '').split(/\r?\n/).map(line => line.trim()).filter(Boolean).findLast(line => /^[^\s/]+\/[^\s]+$/.test(line)) ?? null;
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
  const launchResolveRaw = adb(runtime, ['shell', 'cmd', 'package', 'resolve-activity', '--brief', PACKAGE], { allowFailure: true }).stdout.trim();
  const launchActivity = resolvedComponent(launchResolveRaw);
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
    vcpu: 6, ramMB: PLAY_RAM_MB, displayRequested: `${PLAY_DISPLAY_WIDTH}x${PLAY_DISPLAY_HEIGHT}`, densityRequested: PLAY_DISPLAY_DENSITY, refreshTargetHz: 60,
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
    command(avdmanager, ['create', 'avd', '--name', AVD_NAME, '--package', REQUIRED_IMAGE, '--device', PLAY_DEVICE_ID, '--force'], {
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
     'avd.ini.displayname': 'TFT Ultra Tablet - API36 Google Play',
    'hw.device.manufacturer': 'Google',
    'hw.device.name': PLAY_DEVICE_ID,
    'hw.initialOrientation': 'Landscape',
    'hw.cpu.arch': 'arm64',
    'hw.cpu.ncore': '6',
    'hw.ramSize': String(PLAY_RAM_MB),
    'hw.vmHeapSize': '768',
    'hw.lcd.width': String(PLAY_DISPLAY_WIDTH),
    'hw.lcd.height': String(PLAY_DISPLAY_HEIGHT),
    'hw.lcd.density': String(PLAY_DISPLAY_DENSITY),
    'hw.gpu.enabled': 'yes',
    'hw.gpu.mode': 'host',
    'hw.audioInput': 'yes',
    'hw.keyboard': 'yes',
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
    control: { role: 'PLAY_AUTHORITY', profileLabel: PLAY_PROFILE_LABEL, deviceTemplate: PLAY_DEVICE_ID, vcpu: 6, ramMB: PLAY_RAM_MB, width: PLAY_DISPLAY_WIDTH, height: PLAY_DISPLAY_HEIGHT, densityDpi: PLAY_DISPLAY_DENSITY, gpu: 'host', playStore: true, audio: true },
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
    `@${AVD_NAME}`, '-id', 'TFTMAC-Play-Authority', '-port', EMULATOR_PORT,
    '-gpu', 'host', '-cores', '6', '-memory', String(PLAY_RAM_MB),
    '-no-snapshot', '-no-metrics', '-no-boot-anim', '-crash-report-mode', 'disabled'
  ];
  const timeZone = hostTimeZoneId();
  if (timeZone) args.push('-timezone', timeZone);
  const env = { ...runtime.env, ANDROID_AVD_HOME: runtime.avdHome, ANDROID_EMULATOR_USE_SYSTEM_LIBS: '0' };
  const child = spawn(runtime.emulator, args, { cwd: repoRoot, env, detached: true, stdio: ['ignore', out, err] });
  child.unref();
  appendJSONL(path.join(captureDir, 'host-events.jsonl'), { utc: nowISO(), event: 'EMULATOR_STARTED', pid: child.pid, args });
  return child.pid;
}

function donorConfigBackupPath(runtime) {
  if (!runtime.avdDir) throw new Error('Donor control requires a resolved AVD directory.');
  return path.join(runtime.avdDir, 'config.ini.tftmac-donor-backup');
}

function prepareDonorAVD(runtime) {
  if (!runtime.avdDir || !runtime.avdConfig) throw new Error('Donor control requires an existing official Play AVD.');
  if (!isUnder(runtime.avdDir, EXTERNAL_ROOT)) throw new Error('Donor control AVD must remain on the external runtime volume.');
  const configPath = path.join(runtime.avdDir, 'config.ini');
  const backupPath = donorConfigBackupPath(runtime);
  if (exists(backupPath)) {
    const restored = fs.readFileSync(backupPath, 'utf8');
    fs.writeFileSync(configPath, restored);
    fs.unlinkSync(backupPath);
  }
  const baseline = fs.readFileSync(configPath, 'utf8');
  fs.writeFileSync(backupPath, baseline);
  let config = baseline;
  const values = {
    'hw.cpu.ncore': String(DONOR_PROFILE.vcpu),
    'hw.ramSize': String(DONOR_PROFILE.ramMB),
    'hw.lcd.width': String(DONOR_PROFILE.width),
    'hw.lcd.height': String(DONOR_PROFILE.height),
    'hw.lcd.density': String(DONOR_PROFILE.density),
    'hw.gpu.enabled': 'yes',
    'hw.gpu.mode': 'host',
    'hw.gltransport': DONOR_PROFILE.glTransport,
    'hw.gltransport.drawFlushInterval': String(DONOR_PROFILE.drawFlushInterval),
    'hw.gltransport.asg.writeBufferSize': String(DONOR_PROFILE.asgWriteBufferSize),
    'hw.gltransport.asg.writeStepSize': String(DONOR_PROFILE.asgWriteStepSize),
    'hw.gltransport.asg.dataRingSize': String(DONOR_PROFILE.asgDataRingSize),
    'showDeviceFrame': 'no',
    'skin.name': `${DONOR_PROFILE.width}x${DONOR_PROFILE.height}`,
    'fastboot.forceColdBoot': 'yes',
    'fastboot.forceFastBoot': 'no'
  };
  for (const [key, value] of Object.entries(values)) config = setIniValue(config, key, value);
  fs.writeFileSync(configPath, config);
  return {
    profile: DONOR_PROFILE,
    configPath,
    configSHA256: sha256File(configPath),
    baselineSHA256: crypto.createHash('sha256').update(baseline).digest('hex'),
    backupPath
  };
}

function restoreDonorAVD(runtime) {
  if (!runtime?.avdDir) return { restored: false, reason: 'AVD_UNRESOLVED' };
  const configPath = path.join(runtime.avdDir, 'config.ini');
  const backupPath = donorConfigBackupPath(runtime);
  if (!exists(backupPath)) return { restored: false, reason: 'NO_DONOR_BACKUP' };
  const baseline = fs.readFileSync(backupPath, 'utf8');
  fs.writeFileSync(configPath, baseline);
  fs.unlinkSync(backupPath);
  return { restored: true, configPath, configSHA256: sha256File(configPath) };
}

function startDonorEmulator(runtime, captureDir) {
  if (!runtime.avdHome || !runtime.avdIni || !runtime.avdDir) throw new Error(`Official AVD ${AVD_NAME} is not present under the external runtime.`);
  const out = fs.openSync(path.join(captureDir, 'emulator.stdout.log'), 'a');
  const err = fs.openSync(path.join(captureDir, 'emulator.stderr.log'), 'a');
  const args = [
    `@${AVD_NAME}`, '-id', 'TFTMAC-Mactician-Compatible', '-port', EMULATOR_PORT,
    '-gpu', 'host', '-feature', DONOR_PROFILE.featureList,
    '-append-userspace-opt', 'androidboot.opengles.version=196610',
    '-append-userspace-opt', 'androidboot.tftmac.graphics_profile=mactician-compatible',
    '-skin', `${DONOR_PROFILE.width}x${DONOR_PROFILE.height}`,
    '-vsync-rate', String(DONOR_PROFILE.refreshHz),
    '-dns-server', '1.1.1.1,8.8.8.8',
    '-cores', String(DONOR_PROFILE.vcpu), '-memory', String(DONOR_PROFILE.ramMB),
    '-no-snapshot', '-no-metrics', '-no-boot-anim', '-crash-report-mode', 'disabled'
  ];
  const timeZone = hostTimeZoneId();
  if (timeZone) args.push('-timezone', timeZone);
  const env = {
    ...runtime.env,
    ANDROID_AVD_HOME: runtime.avdHome,
    ANDROID_EMULATOR_USE_SYSTEM_LIBS: '0',
    ANGLE_FEATURE_OVERRIDES_ENABLED: DONOR_PROFILE.angleEnabledFeatures,
    ANGLE_FEATURE_OVERRIDES_DISABLED: DONOR_PROFILE.angleDisabledFeatures,
    MVK_CONFIG_SYNCHRONOUS_QUEUE_SUBMITS: '0',
    MVK_CONFIG_MAX_ACTIVE_METAL_COMMAND_BUFFERS_PER_QUEUE: '64',
    MVK_CONFIG_FAST_MATH_ENABLED: '1'
  };
  const child = spawn(runtime.emulator, args, { cwd: repoRoot, env, detached: true, stdio: ['ignore', out, err] });
  child.unref();
  appendJSONL(path.join(captureDir, 'host-events.jsonl'), {
    utc: nowISO(), event: 'DONOR_EMULATOR_STARTED', pid: child.pid, args,
    profile: DONOR_PROFILE.id,
    env: {
      ANGLE_FEATURE_OVERRIDES_ENABLED: env.ANGLE_FEATURE_OVERRIDES_ENABLED,
      ANGLE_FEATURE_OVERRIDES_DISABLED: env.ANGLE_FEATURE_OVERRIDES_DISABLED,
      MVK_CONFIG_SYNCHRONOUS_QUEUE_SUBMITS: env.MVK_CONFIG_SYNCHRONOUS_QUEUE_SUBMITS,
      MVK_CONFIG_MAX_ACTIVE_METAL_COMMAND_BUFFERS_PER_QUEUE: env.MVK_CONFIG_MAX_ACTIVE_METAL_COMMAND_BUFFERS_PER_QUEUE,
      MVK_CONFIG_FAST_MATH_ENABLED: env.MVK_CONFIG_FAST_MATH_ENABLED
    }
  });
  return child.pid;
}

function donorRuntimeState(runtime, captureDir, prepared, bootClass) {
  const display = adb(runtime, ['shell', 'wm', 'size'], { allowFailure: true }).stdout.trim();
  const density = adb(runtime, ['shell', 'wm', 'density'], { allowFailure: true }).stdout.trim();
  const state = {
    observedAt: nowISO(),
    control: DONOR_PROFILE.id,
    compatibilityAdapter: true,
    compatibilitySource: 'Mactician 1.1.0 measured runtime on this host',
    externalRoot: runtime.externalRoot,
    sdkRoot: runtime.sdkRoot,
    emulatorVersion: runtime.emulatorVersion,
    adbVersion: runtime.adbVersion,
    systemImagePackage: REQUIRED_IMAGE,
    avdName: AVD_NAME,
    avdHome: runtime.avdHome,
    avdConfigSHA256: prepared.configSHA256,
    baselineAvdConfigSHA256: prepared.baselineSHA256,
    adbSerial: SERIAL,
    adbServerPort: Number(ADB_PORT),
    emulatorConsolePort: Number(EMULATOR_PORT),
    vcpu: DONOR_PROFILE.vcpu,
    ramMB: DONOR_PROFILE.ramMB,
    displayRequested: `${DONOR_PROFILE.width}x${DONOR_PROFILE.height}`,
    densityRequested: DONOR_PROFILE.density,
    refreshTargetHz: DONOR_PROFILE.refreshHz,
    gpuMode: 'host',
    graphicsTransportRequested: DONOR_PROFILE.glTransport,
    guestAngleRequested: true,
    vulkanRequested: true,
    glesCompatibilityExposure: 196610,
    angleDisabledFeatures: DONOR_PROFILE.angleDisabledFeatures,
    moltenVK: { synchronousQueueSubmits: false, maxActiveMetalCommandBuffersPerQueue: 64, fastMath: true },
    asg: {
      writeBufferSize: DONOR_PROFILE.asgWriteBufferSize,
      writeStepSize: DONOR_PROFILE.asgWriteStepSize,
      dataRingSize: DONOR_PROFILE.asgDataRingSize,
      drawFlushInterval: DONOR_PROFILE.drawFlushInterval
    },
    audioEnabled: true,
    deviceFrame: false,
    snapshotsRequired: false,
    bootClass,
    observedDisplay: display,
    observedDensity: density
  };
  writeJSON(path.join(captureDir, 'runtime-state.json'), state);
  return state;
}

async function startDonorControl() {
  singleRuntimePreflight();
  const runtime = discover();
  if (!isUnder(runtime.sdkRoot, EXTERNAL_ROOT)) throw new Error('Selected SDK is not on the required external runtime volume.');
  if (!runtime.requiredImagePresent) throw new Error(`Required official Play image is missing: ${runtime.requiredImagePath}`);
  if (!runtime.avdIni || !runtime.avdConfig || !runtime.avdDir) throw new Error(`Required official Play AVD ${AVD_NAME} was not found.`);
  ensureDir(STATE_ROOT); ensureDir(CAPTURE_ROOT); ensureDir(DIAGNOSTICS_ROOT);
  const prepared = prepareDonorAVD(runtime);
  const sessionId = `${new Date().toISOString().replace(/[:.]/g, '-')}-${crypto.randomUUID()}`;
  const captureDir = path.join(CAPTURE_ROOT, sessionId);
  for (const d of [captureDir, path.join(captureDir, 'surfaceflinger'), path.join(captureDir, 'gfxinfo')]) ensureDir(d);
  for (const name of ['clock-sync.jsonl', 'markers.jsonl', 'logcat.raw.txt', 'logcat.filtered.txt', 'host-process.csv', 'host-process.jsonl', 'host-memory.csv', 'host-memory.jsonl']) fs.closeSync(fs.openSync(path.join(captureDir, name), 'a'));
  appendJSONL(path.join(captureDir, 'host-events.jsonl'), { utc: nowISO(), host_mono_ns: monoNs().toString(), event: 'LOGGER_INITIALIZED', sessionId, profile: DONOR_PROFILE.id });
  const session = {
    schema: 1, sessionId, startedUTC: nowISO(), endedUTC: null,
    hostStartMonoNs: monoNs().toString(), hostEndMonoNs: null, captureState: 'CAPTURING',
    workloadLabel: 'mactician-compatible-official-control', appCommit: currentGitSha(), runtimeConfig: DONOR_PROFILE.id,
    packageName: PACKAGE, packageUpdatedDuringSession: false, packageAuthorityVerified: false, packageCurrentObservedAt: null,
    matchEntryObserved: false, combatObserved: false
  };
  writeJSON(path.join(captureDir, 'session.json'), session);
  const samplerPid = startSampler(runtime, captureDir, sessionId);
  appendJSONL(path.join(captureDir, 'host-events.jsonl'), { utc: nowISO(), event: 'SAMPLER_STARTED', pid: samplerPid });
  adbServer(runtime);
  const emulatorPid = startDonorEmulator(runtime, captureDir);
  try {
    await waitForBoot(runtime);
    const clockPreflight = await ensureGuestClock(runtime, captureDir);
    const runtimeObserved = donorRuntimeState(runtime, captureDir, prepared, 'COLD');
    const pkg = packageState(runtime, captureDir, false);
    const renderer = rendererState(runtime, captureDir);
    const state = {
      schema: 1, sessionId, captureDir, samplerPid, emulatorPid, reusedRunningEmulator: false,
      sdkRoot: runtime.sdkRoot, avdHome: runtime.avdHome, startedUTC: session.startedUTC,
      packageState: pkg.state, controlProfile: DONOR_PROFILE.id, donorConfigBackupPath: prepared.backupPath
    };
    writeJSON(CONTROL_STATE, state);
    return { ...state, package: pkg, clockPreflight, runtime: runtimeObserved, renderer, next: pkg.state === 'MISSING' ? 'run play-action to install official TFT from Google Play' : 'run play-action to verify/update official TFT, then launch-game' };
  } catch (error) {
    if (processAlive(samplerPid)) { try { process.kill(samplerPid, 'SIGTERM'); } catch {} }
    try { adb(runtime, ['emu', 'kill'], { allowFailure: true, timeout: 10000 }); } catch {}
    restoreDonorAVD(runtime);
    throw error;
  }
}

async function startControl() {
  const singleRuntime = singleRuntimePreflight();
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
  const clockPreflight = await ensureGuestClock(runtime, captureDir);
  runtimeState(runtime, captureDir, reusedRunningEmulator ? 'WARM' : 'COLD');
  const pkg = packageState(runtime, captureDir, false);
  rendererState(runtime, captureDir);
  const state = { schema: 1, sessionId, captureDir, samplerPid, emulatorPid, reusedRunningEmulator, sdkRoot: runtime.sdkRoot, avdHome: runtime.avdHome, startedUTC: session.startedUTC, packageState: pkg.state };
  writeJSON(CONTROL_STATE, state);
  return { ...state, package: pkg, clockPreflight, next: pkg.state === 'MISSING' ? 'run play-action to install official TFT from Google Play' : 'run play-action to verify/update official TFT, then launch-game' };
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
  await ensureGuestClock(runtime, captureDir);
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
    if (!/^\d+$/.test(String(pkg.versionCode ?? '')) || Number(pkg.versionCode) <= 0) {
      return { action: 'PACKAGE_VERSION_INVALID', package: pkg, reason: 'Google Play-installed TFT must expose a positive Riot versionCode.' };
    }
    if (pkg.signerCertificateSHA256 && pkg.signerCertificateSHA256 !== RIOT_SIGNER_SHA256) {
      return { action: 'PACKAGE_SIGNER_MISMATCH', package: pkg, expectedSignerCertificateSHA256: RIOT_SIGNER_SHA256 };
    }
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

async function playProbe() {
  const runtime = discover();
  const state = readJSON(CONTROL_STATE);
  const captureDir = state?.captureDir ?? null;
  await waitForBoot(runtime, 60000);
  await ensureGuestClock(runtime, captureDir);
  const shell = (args, timeout = 30000) => adb(runtime, ['shell', ...args], { allowFailure: true, timeout });
  const installedBefore = shell(['pm', 'path', PLAY_PROBE_PACKAGE]).stdout.includes('package:');
  if (installedBefore) return { action: 'PROBE_ALREADY_INSTALLED', packageName: PLAY_PROBE_PACKAGE };
  shell(['am', 'start', '-a', 'android.intent.action.VIEW', '-d', `market://details?id=${PLAY_PROBE_PACKAGE}`]);
  await sleep(3500);
  let xml = dumpUI(runtime);
  const install = findNodeByText(xml, [/^Install$/i]);
  if (!install?.bounds) {
    return { action: 'PROBE_INSTALL_BUTTON_NOT_FOUND', packageName: PLAY_PROBE_PACKAGE, uiTextSample: xml.match(/text="([^"]+)"/g)?.slice(0, 60) ?? [] };
  }
  shell(['input', 'tap', String(install.bounds.x), String(install.bounds.y)]);
  const startedAt = Date.now();
  let installed = false;
  while (Date.now() - startedAt < 45000) {
    await sleep(1500);
    if (shell(['pm', 'path', PLAY_PROBE_PACKAGE], 10000).stdout.includes('package:')) { installed = true; break; }
  }
  xml = dumpUI(runtime);
  const logcat = command(runtime.adb, ['-P', ADB_PORT, '-s', SERIAL, 'logcat', '-d', '-v', 'threadtime', '-t', '6000'], { env: runtime.env, allowFailure: true, timeout: 30000, maxBuffer: 64 * 1024 * 1024 }).stdout;
  const relevant = logcat.split(/\r?\n/).filter(line => line.includes(PLAY_PROBE_PACKAGE) || /statusCode:1010|Delivery received non-OK response|Account .* from AppState|estimated size required|INSTALL_ERROR|DOWNLOAD_PENDING/i.test(line)).slice(-500);
  const result = {
    action: installed ? 'PROBE_INSTALLED' : 'PROBE_FAILED',
    packageName: PLAY_PROBE_PACKAGE,
    installed,
    packagePath: shell(['pm', 'path', PLAY_PROBE_PACKAGE]).stdout.trim() || null,
    uiTextSample: xml.match(/text="([^"]+)"/g)?.slice(0, 60) ?? [],
    relevantLogLines: relevant
  };
  if (captureDir) writeJSON(path.join(captureDir, 'google-play-third-party-probe.json'), result);
  return result;
}

function launchFailureProbe() {
  const runtime = discover();
  const state = readJSON(CONTROL_STATE);
  if (!deviceReady(runtime)) throw new Error('No active Android device for launch failure probe.');
  const logcat = command(runtime.adb, ['-P', ADB_PORT, '-s', SERIAL, 'logcat', '-d', '-v', 'threadtime', '-t', '12000'], { env: runtime.env, allowFailure: true, timeout: 30000, maxBuffer: 96 * 1024 * 1024 }).stdout;
  const lines = logcat.split(/\r?\n/);
  const relevant = lines.filter(line => /teamfighttactics|GameActivity|SplashActivity|AndroidRuntime|FATAL EXCEPTION|Fatal signal|DEBUG\s*:|crash_dump|tombstone|ActivityManager.*(died|killing|crash)|Process .*teamfighttactics|libUnreal|libUE|SIG(SEGV|ABRT|BUS|ILL)|linker|dlopen failed|UnsatisfiedLinkError|abort message|ANR in|am_crash/i.test(line)).slice(-1400);
  const result = { observedAt: nowISO(), sessionId: state?.sessionId ?? null, lines: relevant };
  if (state?.captureDir) writeJSON(path.join(state.captureDir, 'launch-failure-probe.json'), result);
  return result;
}

function glesCapabilityProbe() {
  const runtime = discover();
  const state = readJSON(CONTROL_STATE);
  if (!deviceReady(runtime)) throw new Error('No active Android device for GLES capability probe.');
  const shell = (args, timeout = 30000) => adb(runtime, ['shell', ...args], { allowFailure: true, timeout });
  const sf = shell(['dumpsys', 'SurfaceFlinger']).stdout;
  const gfx = shell(['dumpsys', 'gfxinfo', PACKAGE]).stdout;
  const props = {};
  for (const key of ['ro.opengles.version','ro.hardware.egl','ro.hardware.vulkan','ro.boot.hardwareegl','ro.boot.hardware.vulkan','ro.boot.hardware.gltransport','ro.boot.qemu.gltransport.name']) {
    props[key] = shell(['getprop', key]).stdout.trim() || null;
  }
  const logcat = command(runtime.adb, ['-P', ADB_PORT, '-s', SERIAL, 'logcat', '-d', '-v', 'threadtime', '-t', '4000'], { env: runtime.env, allowFailure: true, timeout: 30000, maxBuffer: 64 * 1024 * 1024 }).stdout;
  const relevant = logcat.split(/\r?\n/).filter(line => /teamfighttactics|GameActivity|Unreal|OpenGL ES|GLES|GL_VERSION|ANGLE|EGL|unable to run on this device|not supported|ES 3\.2|ES3_2|FeatureLevel/i.test(line)).slice(-500);
  const result = {
    observedAt: nowISO(),
    sessionId: state?.sessionId ?? null,
    properties: props,
    surfaceFlingerGraphics: sf.split(/\r?\n/).filter(line => /GLES|GL_VERSION|OpenGL|EGL|ANGLE|Vulkan|renderer/i.test(line)).slice(0, 240),
    gfxInfoGraphics: gfx.split(/\r?\n/).filter(line => /GLES|OpenGL|EGL|renderer|driver|version/i.test(line)).slice(0, 160),
    relevantLogLines: relevant
  };
  if (state?.captureDir) writeJSON(path.join(state.captureDir, 'gles-capability-probe.json'), result);
  return result;
}

async function launchGame() {
  const runtime = discover();
  const state = readJSON(CONTROL_STATE);
  if (!state?.captureDir) throw new Error('No active direct-control session. Run start first.');
  const captureDir = state.captureDir;
  await waitForBoot(runtime, 60000);
  await ensureGuestClock(runtime, captureDir);
  const pkg = packageState(runtime, captureDir, false);
  if (pkg.state === 'MISSING') throw new Error('Official TFT package is not installed. Run play-action first.');
  rendererState(runtime, captureDir);
  adb(runtime, ['shell', 'dumpsys', 'gfxinfo', PACKAGE, 'reset'], { allowFailure: true, timeout: 30000 });
  appendJSONL(path.join(captureDir, 'host-events.jsonl'), { utc: nowISO(), host_mono_ns: monoNs().toString(), event: 'GFXINFO_RESET_BEFORE_TFT_LAUNCH' });
  const resolvedRaw = adb(runtime, ['shell', 'cmd', 'package', 'resolve-activity', '--brief', PACKAGE], { allowFailure: true }).stdout.trim();
  const resolved = resolvedComponent(resolvedRaw);
  let launchResult;
  if (resolved) {
    launchResult = adb(runtime, ['shell', 'am', 'start', '-W', '-n', resolved], { allowFailure: true, timeout: 30000 });
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
  if (!pid) throw new Error(`TFT did not remain running. component=${resolved ?? 'unresolved'} launch=${(launchResult.stderr || launchResult.stdout || '').trim()}`);
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

async function recoverAnrWait() {
  const runtime = discover();
  const state = readJSON(CONTROL_STATE);
  if (!deviceReady(runtime)) throw new Error('No active Android device for ANR recovery.');
  const xml = dumpUI(runtime);
  const waitNode = findNodeByText(xml, [/^Wait$/i]);
  const anrText = findNodeByText(xml, [/isn['’]?t responding/i, /not responding/i]);
  if (!waitNode?.bounds) {
    return { action: 'ANR_WAIT_NOT_PRESENT', anrVisible: Boolean(anrText), postStatus: await status() };
  }
  adb(runtime, ['shell', 'input', 'tap', String(waitNode.bounds.x), String(waitNode.bounds.y)], { allowFailure: true, timeout: 10000 });
  if (state?.captureDir) {
    appendJSONL(path.join(state.captureDir, 'host-events.jsonl'), { utc: nowISO(), host_mono_ns: monoNs().toString(), event: 'ANR_WAIT_SELECTED', activity: 'MobileFREWebViewActivity' });
  }
  await sleep(2500);
  return { action: 'ANR_WAIT_SELECTED', postStatus: await status() };
}

function riotPatchState(runtime) {
  if (!deviceReady(runtime)) return { state: 'DEVICE_UNAVAILABLE', serviceActive: false, evidence: [] };
  const services = adb(runtime, ['shell', 'dumpsys', 'activity', 'services', PACKAGE], { allowFailure: true, timeout: 30000 }).stdout;
  const serviceLines = services.split(/\r?\n/).filter(line => /TFTPatchingFGService|com\.riotgames\.mobile/i.test(line)).slice(0, 80);
  const serviceActive = serviceLines.some(line => /TFTPatchingFGService/.test(line));
  const logcat = command(runtime.adb, ['-P', ADB_PORT, '-s', SERIAL, 'logcat', '-d', '-v', 'threadtime', '-t', '1800'], { env: runtime.env, allowFailure: true, timeout: 30000, maxBuffer: 32 * 1024 * 1024 }).stdout;
  const evidence = logcat.split(/\r?\n/).filter(line => /TFTPatchingFGService|teamfighttactics.*(patch|download|asset|content)|riotgames.*(patch|download|asset|content)/i.test(line)).slice(-120);
  return {
    state: serviceActive ? 'PATCHING_OR_INITIALIZING' : 'NO_ACTIVE_PATCH_SERVICE',
    serviceActive,
    serviceLines,
    evidence
  };
}

function telemetrySnapshot(captureDir) {
  const tracked = [
    'host-events.jsonl', 'host-process.jsonl', 'host-memory.jsonl', 'clock-sync.jsonl',
    'logcat.raw.txt', 'gfxinfo/framestats.raw.txt'
  ];
  const files = {};
  for (const rel of tracked) {
    const file = path.join(captureDir, rel);
    try {
      const stat = fs.statSync(file);
      files[rel] = { bytes: stat.size, mtimeMs: stat.mtimeMs };
    } catch {
      files[rel] = { bytes: null, mtimeMs: null };
    }
  }
  return files;
}

async function loggerHealth() {
  const state = readJSON(CONTROL_STATE);
  if (!state?.captureDir) throw new Error('No active direct-control session.');
  const before = telemetrySnapshot(state.captureDir);
  await sleep(2600);
  const after = telemetrySnapshot(state.captureDir);
  const growth = {};
  for (const [rel, current] of Object.entries(after)) {
    const prior = before[rel] ?? {};
    growth[rel] = current.bytes !== null && prior.bytes !== null
      ? { bytesAdded: current.bytes - prior.bytes, mtimeAdvanced: (current.mtimeMs ?? 0) > (prior.mtimeMs ?? 0) }
      : { bytesAdded: null, mtimeAdvanced: false };
  }
  const expectedStreams = ['host-process.jsonl', 'host-memory.jsonl', 'logcat.raw.txt', 'gfxinfo/framestats.raw.txt'];
  const activeStreams = expectedStreams.filter(rel => (growth[rel]?.bytesAdded ?? 0) > 0 || growth[rel]?.mtimeAdvanced);
  const result = {
    observedAt: nowISO(),
    sessionId: state.sessionId,
    captureDir: state.captureDir,
    samplerAlive: processAlive(state.samplerPid),
    emulatorProcessAlive: processAlive(state.emulatorPid),
    activeStreams,
    expectedStreams,
    healthy: processAlive(state.samplerPid) && activeStreams.length >= 3,
    before,
    after,
    growth
  };
  writeJSON(path.join(state.captureDir, 'logger-health.json'), result);
  return result;
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
  const anrWait = xml ? findNodeByText(xml, [/^Wait$/i]) : null;
  const anrText = xml ? findNodeByText(xml, [/isn['’]?t responding/i, /not responding/i]) : null;
  const riotPatch = ready && pid ? riotPatchState(runtime) : { state: 'NOT_RUNNING', serviceActive: false, evidence: [] };
  const gameState = anrWait
    ? 'ANR_WAIT_REQUIRED'
    : riotPatch.serviceActive
    ? 'PATCHING_OR_INITIALIZING'
    : pid && top.some(line => /teamfighttactics\/com\.epicgames\.unreal\.GameActivity/.test(line))
      ? 'RUNNING_POST_PATCH_OR_LOBBY'
      : pid ? 'RUNNING' : 'NOT_RUNNING';
  return { activeSession: state, deviceReady: ready, samplerAlive: processAlive(state?.samplerPid), emulatorProcessAlive: processAlive(state?.emulatorPid), package: pkg, tftPid: pid || null, gameState, riotPatch, anr: { visible: Boolean(anrText || anrWait), waitAvailable: Boolean(anrWait) }, resumedActivity: top, googleAuthPossible: Boolean(googleAuth), riotAuthPossible: Boolean(pid && riotAuth), uiTextSample: xml.match(/text="([^"]+)"/g)?.slice(0, 20) ?? [] };
}

function androidToolEnv(runtime) {
  const javaHomes = [
    process.env.JAVA_HOME,
    '/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home',
    '/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home',
    '/Applications/Android Studio.app/Contents/jbr/Contents/Home'
  ].filter(Boolean);
  const javaHome = javaHomes.find(home => executable(path.join(home, 'bin', 'java'))) ?? null;
  const env = { ...runtime.env };
  if (javaHome) {
    env.JAVA_HOME = javaHome;
    env.PATH = `${path.join(javaHome, 'bin')}:${env.PATH ?? ''}`;
  }
  return { env, javaHome };
}

function imageRevision(runtime, imagePackage = REQUIRED_IMAGE) {
  const properties = path.join(runtime.sdkRoot, ...imagePackage.split(';'), 'source.properties');
  if (!exists(properties)) return null;
  return parseKeyValueLines(fs.readFileSync(properties, 'utf8'))['Pkg.Revision'] ?? null;
}

async function imageUpgradeWorker() {
  ensureDir(path.dirname(IMAGE_UPGRADE_STATE));
  ensureDir(path.dirname(IMAGE_UPGRADE_STDOUT));
  const base = {
    schema: 1,
    pid: process.pid,
    targetPackage: REQUIRED_IMAGE,
    minimumRevision: REQUIRED_IMAGE_MIN_REVISION,
    startedAt: nowISO()
  };
  const record = extra => writeJSON(IMAGE_UPGRADE_STATE, { ...base, ...extra });
  try {
    const runtime = discover();
    const { env, javaHome } = androidToolEnv(runtime);
    const sdkmanager = path.join(runtime.sdkRoot, 'cmdline-tools', 'latest', 'bin', 'sdkmanager');
    const avdmanager = path.join(runtime.sdkRoot, 'cmdline-tools', 'latest', 'bin', 'avdmanager');
    if (!executable(sdkmanager)) throw new Error(`sdkmanager unavailable: ${sdkmanager}`);
    if (!executable(avdmanager)) throw new Error(`avdmanager unavailable: ${avdmanager}`);

    record({ status: 'RUNNING', stage: 'INSTALLING_IMAGE', javaHome });
    const install = command(sdkmanager, ['--install', REQUIRED_IMAGE, '--channel=3'], {
      env,
      timeout: 30 * 60 * 1000,
      maxBuffer: 128 * 1024 * 1024
    });
    const revision = imageRevision(runtime);
    if (!revision || Number.parseInt(revision, 10) < REQUIRED_IMAGE_MIN_REVISION) {
      throw new Error(`Image install completed but revision ${revision ?? 'unknown'} is below ${REQUIRED_IMAGE_MIN_REVISION}.`);
    }

    record({ status: 'RUNNING', stage: 'RECREATING_AVD', installedRevision: revision });
    for (const target of [runtime.avdIni, runtime.avdDir]) {
      if (!target) continue;
      if (!isUnder(target, EXTERNAL_ROOT)) throw new Error(`Refusing to remove AVD path outside external runtime: ${target}`);
      fs.rmSync(target, { recursive: true, force: true });
    }
    ensureDir(runtime.avdHome ?? path.join(EXTERNAL_ROOT, 'AVD'));
    const avdHome = runtime.avdHome ?? path.join(EXTERNAL_ROOT, 'AVD');
    command(avdmanager, [
      'create', 'avd', '--name', AVD_NAME,
      '--package', REQUIRED_IMAGE,
      '--device', PLAY_DEVICE_ID, '--force'
    ], {
      env: { ...env, ANDROID_AVD_HOME: avdHome },
      input: 'no\n',
      timeout: 120000,
      maxBuffer: 32 * 1024 * 1024
    });
    const prepared = prepareAVD();
    const completed = {
      status: 'SUCCEEDED',
      stage: 'COMPLETE',
      installedRevision: revision,
      endedAt: nowISO(),
      prepared,
      sdkmanagerOutputTail: install.stdout.slice(-6000)
    };
    record(completed);
    return completed;
  } catch (error) {
    const failure = {
      status: 'FAILED',
      stage: 'FAILED',
      endedAt: nowISO(),
      error: error instanceof Error ? error.message : String(error)
    };
    record(failure);
    throw error;
  }
}

function imageUpgradeStart() {
  const existing = readJSON(IMAGE_UPGRADE_STATE);
  if (existing?.status === 'RUNNING' && processAlive(existing.pid)) {
    return { launched: false, alreadyRunning: true, worker: existing };
  }
  ensureDir(path.dirname(IMAGE_UPGRADE_STDOUT));
  const out = fs.openSync(IMAGE_UPGRADE_STDOUT, 'a');
  const err = fs.openSync(IMAGE_UPGRADE_STDERR, 'a');
  try {
    const child = spawn(process.execPath, [scriptPath, 'image-upgrade-worker'], {
      cwd: repoRoot,
      env: process.env,
      detached: true,
      stdio: ['ignore', out, err]
    });
    child.unref();
    return {
      launched: true,
      pid: child.pid,
      targetPackage: REQUIRED_IMAGE,
      minimumRevision: REQUIRED_IMAGE_MIN_REVISION,
      statePath: IMAGE_UPGRADE_STATE,
      stdoutPath: IMAGE_UPGRADE_STDOUT,
      stderrPath: IMAGE_UPGRADE_STDERR
    };
  } finally {
    fs.closeSync(out);
    fs.closeSync(err);
  }
}

function imageUpgradeStatus() {
  const state = readJSON(IMAGE_UPGRADE_STATE, { status: 'NOT_STARTED' });
  const tail = file => {
    if (!exists(file)) return null;
    const text = fs.readFileSync(file, 'utf8');
    return text.slice(-6000);
  };
  return {
    ...state,
    alive: Boolean(state?.pid && processAlive(state.pid)),
    stdoutTail: tail(IMAGE_UPGRADE_STDOUT),
    stderrTail: tail(IMAGE_UPGRADE_STDERR)
  };
}

function imageCheck() {
  const runtime = discover();
  const sourceProperties = path.join(runtime.requiredImagePath, 'source.properties');
  const installedProperties = exists(sourceProperties) ? parseKeyValueLines(fs.readFileSync(sourceProperties, 'utf8')) : {};
  const javaHomes = [
    process.env.JAVA_HOME,
    '/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home',
    '/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home',
    '/Applications/Android Studio.app/Contents/jbr/Contents/Home'
  ].filter(Boolean);
  const javaHome = javaHomes.find(home => executable(path.join(home, 'bin', 'java'))) ?? null;
  const env = { ...runtime.env };
  if (javaHome) {
    env.JAVA_HOME = javaHome;
    env.PATH = `${path.join(javaHome, 'bin')}:${env.PATH ?? ''}`;
  }
  const sdkmanager = path.join(runtime.sdkRoot, 'cmdline-tools', 'latest', 'bin', 'sdkmanager');
  const androidCli = path.join(runtime.sdkRoot, 'cmdline-tools', 'latest', 'bin', 'android');
  let listing = { status: -1, stdout: '', stderr: 'No Android SDK package-list tool found' };
  if (executable(sdkmanager)) {
    listing = command(sdkmanager, ['--list', '--channel=3'], { env, allowFailure: true, timeout: 120000, maxBuffer: 64 * 1024 * 1024 });
  } else if (executable(androidCli)) {
    listing = command(androidCli, [`--sdk=${runtime.sdkRoot}`, 'sdk', 'list', '.*(android-3[67]).*playstore.*arm64.*', '--all', '--all-versions', '--canary'], { env, allowFailure: true, timeout: 120000, maxBuffer: 64 * 1024 * 1024 });
  }
  const lines = `${listing.stdout}\n${listing.stderr}`.split(/\r?\n/)
    .filter(line => /system-images.*android-3[67].*(google_apis_playstore|playstore).*arm64/i.test(line));
  return {
    installedPackage: REQUIRED_IMAGE,
    installedRevision: installedProperties['Pkg.Revision'] ?? null,
    installedDescription: installedProperties['Pkg.Desc'] ?? null,
    packageToolStatus: listing.status,
    javaHome,
    matchingAvailableLines: lines.slice(0, 120)
  };
}

function deviceProfiles() {
  const runtime = discover();
  const { env, javaHome } = androidToolEnv(runtime);
  const avdmanager = path.join(runtime.sdkRoot, 'cmdline-tools', 'latest', 'bin', 'avdmanager');
  if (!executable(avdmanager)) throw new Error(`avdmanager unavailable: ${avdmanager}`);
  const result = command(avdmanager, ['list', 'device'], { env, allowFailure: true, timeout: 120000, maxBuffer: 32 * 1024 * 1024 });
  const blocks = result.stdout.split(/---------/).map(block => block.trim()).filter(Boolean);
  const profiles = blocks.map(block => {
    const id = block.match(/id:\s*\d+\s+or\s+"([^"]+)"/)?.[1] ?? null;
    const name = block.match(/Name:\s*(.+)/)?.[1]?.trim() ?? null;
    const oem = block.match(/OEM\s*:\s*(.+)/)?.[1]?.trim() ?? null;
    const tag = block.match(/Tag\s*:\s*(.+)/)?.[1]?.trim() ?? null;
    return { id, name, oem, tag, raw: block };
  }).filter(p => p.id);
  return { javaHome, status: result.status, profiles };
}

async function googleAccountUI() {
  const runtime = discover();
  await waitForBoot(runtime, 60000);
  const before = adb(runtime, ['shell', 'dumpsys', 'account'], { allowFailure: true, timeout: 30000 }).stdout;
  const launch = adb(runtime, [
    'shell', 'am', 'start', '-W',
    '-a', 'android.settings.ADD_ACCOUNT_SETTINGS',
    '--esa', 'account_types', 'com.google'
  ], { allowFailure: true, timeout: 30000 });
  await sleep(1800);
  const xml = dumpUI(runtime);
  const state = readJSON(CONTROL_STATE);
  if (state?.captureDir) {
    fs.writeFileSync(path.join(state.captureDir, 'google-account-ui.xml'), xml);
    appendJSONL(path.join(state.captureDir, 'host-events.jsonl'), { utc: nowISO(), event: 'GOOGLE_ACCOUNT_UI_OPENED', launchStatus: launch.status });
  }
  return {
    action: 'GOOGLE_ACCOUNT_UI_OPEN',
    launchStatus: launch.status,
    launchOutput: `${launch.stdout}${launch.stderr}`.trim(),
    accountsBefore: before.match(/Accounts:\s*(\d+)/)?.[1] ?? null,
    uiTextSample: xml.match(/text="([^"]+)"/g)?.slice(0, 40) ?? []
  };
}

async function playStoreRepair() {
  const runtime = discover();
  await waitForBoot(runtime, 60000);
  const state = readJSON(CONTROL_STATE);
  const captureDir = state?.captureDir ?? null;
  const shell = (args, timeout = 30000) => adb(runtime, ['shell', ...args], { allowFailure: true, timeout });
  const accountsBefore = shell(['dumpsys', 'account']).stdout;
  const countBefore = Number(accountsBefore.match(/Accounts:\s*(\d+)/)?.[1] ?? 0);
  const clear = shell(['pm', 'clear', 'com.android.vending'], 60000);
  shell(['am', 'force-stop', 'com.android.vending']);
  await sleep(1200);
  const launch = shell(['am', 'start', '-W', '-a', 'android.intent.action.VIEW', '-d', `market://details?id=${PACKAGE}`], 30000);
  await sleep(5000);
  const accountsAfter = shell(['dumpsys', 'account']).stdout;
  const countAfter = Number(accountsAfter.match(/Accounts:\s*(\d+)/)?.[1] ?? 0);
  const xml = dumpUI(runtime);
  const result = {
    action: 'PLAY_STORE_STATE_REPAIRED',
    clearStatus: clear.status,
    clearOutput: `${clear.stdout}${clear.stderr}`.trim(),
    launchStatus: launch.status,
    accountCountBefore: countBefore,
    accountCountAfter: countAfter,
    googleAccountPreserved: /type=com\.google|Account \{.*com\.google/i.test(accountsAfter),
    uiTextSample: xml.match(/text="([^"]+)"/g)?.slice(0, 60) ?? []
  };
  if (captureDir) {
    appendJSONL(path.join(captureDir, 'host-events.jsonl'), { utc: nowISO(), event: 'PLAY_STORE_STATE_REPAIR', accountCountBefore: countBefore, accountCountAfter: countAfter, clearStatus: clear.status });
    writeJSON(path.join(captureDir, 'play-store-repair.json'), result);
  }
  return result;
}

async function playInstallBrief() {
  const runtime = discover();
  await waitForBoot(runtime, 60000);
  const state = readJSON(CONTROL_STATE);
  const captureDir = state?.captureDir ?? null;
  const logcat = command(runtime.adb, ['-P', ADB_PORT, '-s', SERIAL, 'logcat', '-d', '-v', 'threadtime', '-t', '15000'], { env: runtime.env, allowFailure: true, timeout: 30000, maxBuffer: 64 * 1024 * 1024 }).stdout;
  const lines = logcat.split(/\r?\n/);
  const focus = lines.filter(line => /(com\.riotgames\.league\.teamfighttactics|Finsky.*(tos|install|acqui|download|deliver|session|offer|eligible|account|library|purchase|error|fail|abandon|device)|PackageInstaller.*(teamfight|riot|abandon|fail|error)|Phonesky.*(tos|install|fail|error)|Installer.*teamfight|Session.*teamfight)/i.test(line)).slice(-800);
  const shell = (args, timeout = 30000) => adb(runtime, ['shell', ...args], { allowFailure: true, timeout });
  const vendingPrefs = shell(['dumpsys', 'package', 'com.android.vending']).stdout;
  const accounts = shell(['dumpsys', 'account']).stdout;
  const result = {
    observedAt: nowISO(),
    accountCount: Number(accounts.match(/Accounts:\s*(\d+)/)?.[1] ?? 0),
    googleAccountPresent: /type=com\.google|Account \{.*com\.google/i.test(accounts),
    playVersionName: vendingPrefs.match(/versionName=([^\s]+)/)?.[1] ?? null,
    tosTokenEmptySeen: focus.some(line => /tosToken is empty/i.test(line)),
    tftMentionCount: focus.filter(line => /com\.riotgames\.league\.teamfighttactics/i.test(line)).length,
    focusLines: focus
  };
  if (captureDir) writeJSON(path.join(captureDir, 'google-play-install-brief.json'), result);
  return result;
}

async function installDiagnose() {
  const runtime = discover();
  await waitForBoot(runtime, 60000);
  const state = readJSON(CONTROL_STATE);
  const captureDir = state?.captureDir ?? null;
  const shell = (args, timeout = 30000) => adb(runtime, ['shell', ...args], { allowFailure: true, timeout });
  const logcat = command(runtime.adb, ['-P', ADB_PORT, '-s', SERIAL, 'logcat', '-d', '-v', 'threadtime', '-t', '12000'], { env: runtime.env, allowFailure: true, timeout: 30000, maxBuffer: 64 * 1024 * 1024 }).stdout;
  const rx = /(INSTALL_FAILED|PackageInstaller|PackageManager|PackageInstallerSession|Finsky|Phonesky|installd|dex2oat|AppIntegrity|PlayProtect|Verifier|install[^ ]*.*fail|fail[^ ]*.*install|insufficient|not enough|storage|native librar|ABI|split|session.*(fail|abandon)|download.*(fail|error)|asset.*(fail|error)|fs-verity|parse.*package|incompatible)/i;
  const lines = logcat.split(/\r?\n/).filter(line => rx.test(line)).slice(-1800);
  const vendingDump = shell(['dumpsys', 'package', 'com.android.vending']).stdout;
  const sessions = shell(['dumpsys', 'package', 'installer']).stdout;
  const staged = shell(['cmd', 'package', 'list', 'staged-sessions']).stdout;
  const result = {
    observedAt: nowISO(),
    sessionId: state?.sessionId ?? null,
    tftPackage: packageState(runtime, captureDir, false),
    guest: {
      sdk: shell(['getprop', 'ro.build.version.sdk']).stdout.trim(),
      release: shell(['getprop', 'ro.build.version.release']).stdout.trim(),
      fingerprint: shell(['getprop', 'ro.build.fingerprint']).stdout.trim(),
      abi: shell(['getprop', 'ro.product.cpu.abi']).stdout.trim(),
      abiList: shell(['getprop', 'ro.product.cpu.abilist']).stdout.trim(),
      pageSize: shell(['getconf', 'PAGESIZE']).stdout.trim(),
      dataFilesystem: shell(['df', '-h', '/data']).stdout.trim(),
      dataBytes: shell(['df', '-B1', '/data']).stdout.trim()
    },
    playStore: {
      versionName: vendingDump.match(/versionName=([^\s]+)/)?.[1] ?? null,
      versionCode: vendingDump.match(/versionCode=([^\s]+)/)?.[1] ?? null,
      installerSessions: sessions.split(/\r?\n/).filter(line => /Session|install|failure|error|stage|package/i.test(line)).slice(-500),
      stagedSessions: staged.trim() || null
    },
    foreground: shell(['dumpsys', 'activity', 'top']).stdout.split(/\r?\n/).filter(line => /ACTIVITY|topResumedActivity|mResumedActivity|com\.android\.vending/.test(line)).slice(0, 50),
    relevantLogLines: lines
  };
  if (captureDir) {
    writeJSON(path.join(captureDir, 'google-play-install-diagnostic.json'), result);
    fs.writeFileSync(path.join(captureDir, 'google-play-install-logcat.txt'), `${lines.join('\n')}\n`);
  }
  return result;
}

async function authBrief() {
  const runtime = discover();
  await waitForBoot(runtime, 60000);
  const logcat = command(runtime.adb, ['-P', ADB_PORT, '-s', SERIAL, 'logcat', '-d', '-v', 'threadtime', '-t', '5000'], { env: runtime.env, allowFailure: true, timeout: 30000 }).stdout;
  const rx = /(MinuteMaid|PreAddAccount|GLSUser|DeviceKeyStore|crashpad|FATAL EXCEPTION|Force finishing activity.*google|Process .*com\.google\.android\.gms.*died|POST_PRE_ADD_ACCOUNT|auth\.uiflows|Protocol message end-group|Account.*error)/i;
  const lines = logcat.split(/\r?\n/).filter(line => rx.test(line)).slice(-500);
  const accounts = adb(runtime, ['shell', 'dumpsys', 'account'], { allowFailure: true, timeout: 30000 }).stdout;
  const top = adb(runtime, ['shell', 'dumpsys', 'activity', 'top'], { allowFailure: true, timeout: 30000 }).stdout;
  const result = {
    observedAt: nowISO(),
    accountCount: Number(accounts.match(/Accounts:\s*(\d+)/)?.[1] ?? 0),
    foreground: top.split(/\r?\n/).filter(line => /ACTIVITY|topResumedActivity|mResumedActivity/.test(line)).slice(0, 30),
    minuteMaidCrash: lines.some(line => /Force finishing activity.*MinuteMaid|crashpad|FATAL EXCEPTION.*google|Process .*com\.google\.android\.gms.*died/i.test(line)),
    glsProtocolError: lines.some(line => /Protocol message end-group tag did not match expected tag/i.test(line)),
    deviceKeyMissing: lines.some(line => /Device key file not found/i.test(line)),
    relevantLines: lines
  };
  const state = readJSON(CONTROL_STATE);
  if (state?.captureDir) writeJSON(path.join(state.captureDir, 'google-auth-brief.json'), result);
  return result;
}

async function playCertification() {
  const runtime = discover();
  await waitForBoot(runtime, 60000);
  const state = readJSON(CONTROL_STATE);
  const captureDir = state?.captureDir ?? null;
  await ensureGuestClock(runtime, captureDir);
  const shell = (args, timeout = 30000) => adb(runtime, ['shell', ...args], { allowFailure: true, timeout });
  const prop = key => shell(['getprop', key]).stdout.trim() || null;
  const features = shell(['pm', 'list', 'features']).stdout.split(/\r?\n/).filter(Boolean);
  const gsfQuery = shell(['content', 'query', '--uri', 'content://com.google.android.gsf.gservices', '--projection', 'name:value', '--where', "name='android_id'"]).stdout.trim();
  const packageDump = name => shell(['dumpsys', 'package', name]).stdout;
  const vendingDump = packageDump('com.android.vending');
  const gmsDump = packageDump('com.google.android.gms');
  const gsfDump = packageDump('com.google.android.gsf');

  const activityCandidates = [
    'com.android.vending/com.google.android.finsky.activities.SettingsActivity',
    'com.android.vending/com.google.android.finsky.settings.SettingsActivity'
  ];
  let settingsLaunch = null;
  let xml = '';
  for (const component of activityCandidates) {
    const launch = shell(['am', 'start', '-W', '-n', component]);
    if (launch.status === 0 && !/Error|Exception|does not exist|not exported/i.test(`${launch.stdout}${launch.stderr}`)) {
      settingsLaunch = component;
      await sleep(1800);
      xml = dumpUI(runtime);
      break;
    }
  }
  if (!xml) {
    shell(['am', 'force-stop', 'com.android.vending']);
    shell(['am', 'start', '-W', '-a', 'android.intent.action.MAIN', '-c', 'android.intent.category.LAUNCHER', '-n', 'com.android.vending/com.google.android.finsky.activities.MainActivity']);
    await sleep(2200);
    xml = dumpUI(runtime);
    const account = findNodeByText(xml, [/account and settings/i, /settings and account/i, /profile/i]);
    if (account?.bounds) {
      shell(['input', 'tap', String(account.bounds.x), String(account.bounds.y)]);
      await sleep(900);
      xml = dumpUI(runtime);
      const settings = findNodeByText(xml, [/^Settings$/i]);
      if (settings?.bounds) {
        shell(['input', 'tap', String(settings.bounds.x), String(settings.bounds.y)]);
        await sleep(1000);
        xml = dumpUI(runtime);
      }
    }
  }
  const about = findNodeByText(xml, [/^About$/i]);
  if (about?.bounds) {
    shell(['input', 'tap', String(about.bounds.x), String(about.bounds.y)]);
    await sleep(1000);
    xml = dumpUI(runtime);
  }
  const nodes = xml.match(/<node\b[^>]*\/>/g) ?? [];
  const visibleText = nodes.flatMap(node => {
    const text = node.match(/text="([^"]*)"/)?.[1] ?? '';
    const desc = node.match(/content-desc="([^"]*)"/)?.[1] ?? '';
    return [text, desc].filter(Boolean);
  });
  const certificationText = visibleText.filter(value => /play protect certification|device is (?:not )?certified|certification/i.test(value));
  const sanitizedUiText = visibleText.filter(value => !/@/.test(value)).filter(value => /play protect|certif|about|play store version|update play store|device/i.test(value)).slice(0, 80);
  const clickableNodes = nodes.filter(node => /clickable="true"/.test(node)).flatMap(node => {
    const text = node.match(/text="([^"]*)"/)?.[1] ?? '';
    const desc = node.match(/content-desc="([^"]*)"/)?.[1] ?? '';
    const bounds = parseBounds(node);
    if ((text && /@/.test(text)) || (desc && /@/.test(desc))) return [];
    if (!bounds) return [];
    return [{ text: text || null, contentDescription: desc || null, bounds }];
  }).slice(0, 120);
  const allSanitizedText = visibleText.filter(value => value && !/@/.test(value)).slice(0, 160);
  const result = {
    observedAt: nowISO(),
    imagePackage: REQUIRED_IMAGE,
    playStoreEnabledInAvd: parseKeyValueLines(runtime.avdConfig ?? '')['PlayStore.enabled'] ?? null,
    settingsLaunch,
    certificationText,
    certificationState: certificationText.some(value => /not certified/i.test(value)) ? 'NOT_CERTIFIED'
      : certificationText.some(value => /device is certified|play protect certified/i.test(value)) ? 'CERTIFIED'
      : 'UNRESOLVED',
    device: {
      fingerprint: prop('ro.build.fingerprint'),
      brand: prop('ro.product.brand'),
      manufacturer: prop('ro.product.manufacturer'),
      model: prop('ro.product.model'),
      device: prop('ro.product.device'),
      buildType: prop('ro.build.type'),
      buildTags: prop('ro.build.tags'),
      debuggable: prop('ro.debuggable'),
      secure: prop('ro.secure'),
      verifiedBootState: prop('ro.boot.verifiedbootstate'),
      flashLocked: prop('ro.boot.flash.locked'),
      vbmetaDeviceState: prop('ro.boot.vbmeta.device_state'),
      sdk: prop('ro.build.version.sdk'),
      release: prop('ro.build.version.release'),
      abi: prop('ro.product.cpu.abi')
    },
    graphicsEligibility: {
      roOpenGLESVersion: prop('ro.opengles.version'),
      hardwareEGL: prop('ro.hardware.egl'),
      hardwareVulkan: prop('ro.hardware.vulkan'),
      vulkanVersionFeature: features.find(line => /android\.hardware\.vulkan\.version/i.test(line)) ?? null,
      vulkanLevelFeature: features.find(line => /android\.hardware\.vulkan\.level/i.test(line)) ?? null,
      glesVersionFeature: features.find(line => /reqGlEsVersion|opengles/i.test(line)) ?? null,
      relevantFeatures: features.filter(line => /vulkan|opengl|gles|texture|screen\.landscape|touchscreen|ram\.(normal|low)/i.test(line)).slice(0, 120)
    },
    registration: {
      androidIdPresent: Boolean(shell(['settings', 'get', 'secure', 'android_id']).stdout.trim()),
      gsfAndroidIdQuerySucceeded: Boolean(gsfQuery && !/Permission Denial|SecurityException|No result/i.test(gsfQuery)),
      gsfAndroidIdPresent: /value=\d+|android_id/i.test(gsfQuery),
      playStoreVersionName: vendingDump.match(/versionName=([^\s]+)/)?.[1] ?? null,
      playServicesVersionName: gmsDump.match(/versionName=([^\s]+)/)?.[1] ?? null,
      gsfVersionName: gsfDump.match(/versionName=([^\s]+)/)?.[1] ?? null
    },
    uiEvidence: sanitizedUiText,
    allSanitizedText,
    clickableNodes
  };
  if (captureDir) writeJSON(path.join(captureDir, 'google-play-certification.json'), result);
  return result;
}

async function playDiagnose() {
  const runtime = discover();
  await waitForBoot(runtime, 60000);
  const state = readJSON(CONTROL_STATE);
  const captureDir = state?.captureDir ?? null;
  const shell = (args, timeout = 30000) => adb(runtime, ['shell', ...args], { allowFailure: true, timeout });
  const pkg = name => {
    const dump = shell(['dumpsys', 'package', name]).stdout;
    return {
      installed: /Package \[|versionCode=|versionName=/.test(dump),
      versionName: dump.match(/versionName=([^\s]+)/)?.[1] ?? null,
      versionCode: dump.match(/versionCode=([^\s]+)/)?.[1] ?? null,
      firstInstallTime: dump.match(/firstInstallTime=([^\n]+)/)?.[1]?.trim() ?? null,
      lastUpdateTime: dump.match(/lastUpdateTime=([^\n]+)/)?.[1]?.trim() ?? null,
      enabled: dump.match(/enabled=([^\s]+)/)?.[1] ?? null
    };
  };
  const props = {};
  for (const key of [
    'ro.build.version.release','ro.build.version.sdk','ro.build.version.security_patch','ro.build.fingerprint',
    'ro.product.model','ro.product.manufacturer','ro.product.device','ro.product.cpu.abi',
    'ro.boot.verifiedbootstate','ro.boot.flash.locked','ro.kernel.qemu','ro.boot.qemu.avd_name',
    'ro.build.tags','ro.build.type','ro.debuggable','ro.secure','persist.sys.timezone'
  ]) props[key] = shell(['getprop', key]).stdout.trim() || null;
  const epoch = shell(['date', '+%s']).stdout.trim();
  const utcDate = shell(['date', '-u']).stdout.trim();
  const autoTime = shell(['settings', 'get', 'global', 'auto_time']).stdout.trim();
  const autoZone = shell(['settings', 'get', 'global', 'auto_time_zone']).stdout.trim();
  const androidId = shell(['settings', 'get', 'secure', 'android_id']).stdout.trim();
  const accounts = shell(['dumpsys', 'account']).stdout;
  const connectivity = shell(['dumpsys', 'connectivity']).stdout;
  const dnsProbe = shell(['ping', '-c', '1', '-W', '3', 'connectivitycheck.gstatic.com'], 10000);
  const playCheck = shell(['pm', 'list', 'packages', '-i']).stdout.split(/\r?\n/)
    .filter(line => /com\.android\.vending|com\.google\.android\.gms|com\.google\.android\.gsf/.test(line));
  const logcat = command(runtime.adb, ['-P', ADB_PORT, '-s', SERIAL, 'logcat', '-d', '-v', 'threadtime', '-t', '6000'], { env: runtime.env, allowFailure: true, timeout: 30000 }).stdout;
  const authRx = /(Finsky|Vending|GoogleLogin|GoogleAuth|AuthManager|AccountManager|GLS|GmsAuth|GmsCore|Google Play services|checkin|Checkin|DroidGuard|SafetyNet|Integrity|PlayIntegrity|device.?cert|certification|OAuth|token|Token|signin|SignIn|auth|Auth|phenotype|conscrypt|SSL|TLS|network|Network)/i;
  const authLines = logcat.split(/\r?\n/).filter(line => authRx.test(line)).slice(-1200);
  const result = {
    observedAt: nowISO(),
    sessionId: state?.sessionId ?? null,
    foreground: shell(['dumpsys', 'activity', 'top']).stdout.split(/\r?\n/).filter(line => /ACTIVITY|mResumedActivity|topResumedActivity|com\.android\.vending/.test(line)).slice(0, 40),
    clock: { hostEpochSeconds: Math.floor(Date.now() / 1000), guestEpochSeconds: Number(epoch) || null, guestUTC: utcDate || null, autoTime, autoTimeZone: autoZone },
    network: { dnsProbeStatus: dnsProbe.status, dnsProbe: `${dnsProbe.stdout}${dnsProbe.stderr}`.trim(), connectivityMentions: connectivity.split(/\r?\n/).filter(line => /VALIDATED|INTERNET|WIFI|NetworkAgentInfo|Dns|dns/i.test(line)).slice(0, 120) },
    properties: props,
    androidId: androidId || null,
    packages: {
      playStore: pkg('com.android.vending'),
      playServices: pkg('com.google.android.gms'),
      googleServicesFramework: pkg('com.google.android.gsf')
    },
    packageInstallers: playCheck,
    accountsSummary: accounts.split(/\r?\n/).filter(line => /Account \{|type=com\.google|Accounts:|User UserInfo|AuthenticatorDescription/i.test(line)).slice(0, 160),
    authLogLines: authLines
  };
  if (captureDir) {
    writeJSON(path.join(captureDir, 'google-play-auth-diagnostic.json'), result);
    fs.writeFileSync(path.join(captureDir, 'google-play-auth-logcat.txt'), `${authLines.join('\n')}\n`);
  }
  return result;
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
  if (state.controlProfile === DONOR_PROFILE.id) {
    try { result.donorAvdRestore = restoreDonorAVD(runtime); } catch (error) { result.donorAvdRestore = { restored: false, error: error instanceof Error ? error.message : String(error) }; }
  }
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

function runtimeProcessAudit() {
  const ps = command('/bin/ps', ['axo', 'pid=,ppid=,etime=,command='], { allowFailure: true, timeout: 10000, maxBuffer: 16 * 1024 * 1024 });
  const lines = ps.stdout.split(/\r?\n/).map(line => line.trim()).filter(Boolean);
  const relevant = lines.filter(line => /(TFTMAC|Mactician|TftPBE|TFT_Ultra_Tablet|TFTMAC_Live_API36|qemu-system-aarch64|\/emulator(?:\s|$)|adb.*fork-server|tftmac-direct-control\.mjs\s+sampler)/i.test(line));
  const classified = relevant.map(line => {
    const match = line.match(/^(\d+)\s+(\d+)\s+(\S+)\s+(.+)$/);
    const pid = match ? Number(match[1]) : null;
    const ppid = match ? Number(match[2]) : null;
    const elapsed = match?.[3] ?? null;
    const commandLine = match?.[4] ?? line;
    let kind = 'OTHER_RELEVANT';
    if (/tftmac-direct-control\.mjs\s+sampler/i.test(commandLine)) kind = 'TFTMAC_SAMPLER';
    else if (/TFTMAC\.app\/Contents\/MacOS\/TFTMAC/i.test(commandLine)) kind = 'TFTMAC_APP';
    else if (/Mactician\.app\/Contents\/MacOS\/Mactician/i.test(commandLine)) kind = 'MACTICIAN_APP';
    else if (/qemu-system-aarch64|\/emulator(?:\s|$)/i.test(commandLine)) kind = 'ANDROID_EMULATOR';
    else if (/adb.*fork-server/i.test(commandLine)) kind = 'ADB_SERVER';
    return { pid, ppid, elapsed, kind, command: commandLine };
  });
  const lsof = command('/usr/sbin/lsof', ['-nP', '-iTCP:5038', '-iTCP:5040', '-iTCP:5582', '-iTCP:5592'], { allowFailure: true, timeout: 10000, maxBuffer: 8 * 1024 * 1024 });
  const portLines = lsof.stdout.split(/\r?\n/).filter(Boolean);
  const adb5040 = portLines.some(line => /:5040\s+\(LISTEN\)/.test(line)) ? 'LISTENER_PRESENT' : 'NO_LISTENER';
  return {
    observedAt: nowISO(),
    processCount: classified.length,
    processes: classified,
    ports: portLines,
    adb5040,
    controlState: readJSON(CONTROL_STATE),
    duplicateRisk: {
      tftmacApps: classified.filter(item => item.kind === 'TFTMAC_APP').length,
      macticianApps: classified.filter(item => item.kind === 'MACTICIAN_APP').length,
      emulators: classified.filter(item => item.kind === 'ANDROID_EMULATOR').length,
      samplers: classified.filter(item => item.kind === 'TFTMAC_SAMPLER').length,
      adbServers: classified.filter(item => item.kind === 'ADB_SERVER').length
    }
  };
}

function cleanupTftmacAdbResidue() {
  const auditBefore = runtimeProcessAudit();
  const tftmacAdb = auditBefore.processes.filter(item => item.kind === 'ADB_SERVER' && /tcp:5040\b/.test(item.command));
  if (!tftmacAdb.length) return { action: 'TFTMAC_ADB_RESIDUE_ABSENT', auditBefore, auditAfter: auditBefore };
  const runtime = discover();
  const killed = command(runtime.adb, ['-P', ADB_PORT, 'kill-server'], { env: runtime.env, allowFailure: true, timeout: 10000 });
  const auditAfter = runtimeProcessAudit();
  if (auditAfter.processes.some(item => item.kind === 'ADB_SERVER' && /tcp:5040\b/.test(item.command))) {
    throw new Error(`TFTMAC_ADB_RESIDUE_CLEANUP_FAILED: ${(killed.stderr || killed.stdout || '').trim()}`);
  }
  return { action: 'TFTMAC_ADB_RESIDUE_CLEANED', killedPids: tftmacAdb.map(item => item.pid), killStatus: killed.status, auditBefore, auditAfter };
}

function singleRuntimePreflight() {
  const audit = runtimeProcessAudit();
  const blockers = audit.processes.filter(item => ['TFTMAC_APP', 'MACTICIAN_APP', 'ANDROID_EMULATOR', 'TFTMAC_SAMPLER', 'ADB_SERVER'].includes(item.kind));
  if (blockers.length || audit.ports.length) {
    throw new Error(`SINGLE_RUNTIME_PREFLIGHT_BLOCKED: ${JSON.stringify({ blockers, ports: audit.ports, adb5040: audit.adb5040 })}`);
  }
  return { pass: true, observedAt: audit.observedAt, audit };
}

function launchMacticianControl() {
  const preflight = singleRuntimePreflight();
  const app = '/Applications/Mactician.app';
  const binary = path.join(app, 'Contents', 'MacOS', 'Mactician');
  if (!executable(binary)) throw new Error(`MACTICIAN_APP_MISSING: ${binary}`);
  const env = { ...process.env, ANDROID_ADB_SERVER_PORT: '5038', ADB_MDNS_AUTO_CONNECT: '' };
  const child = spawn(binary, [], { env, detached: true, stdio: 'ignore' });
  child.unref();
  return { action: 'MACTICIAN_LAUNCHED', app, binary, pid: child.pid, inheritedAdbServerPort: 5038, preflight, observedAt: nowISO() };
}

async function stopMacticianControl() {
  const ps = command('/bin/ps', ['axo', 'pid=,command='], { allowFailure: true, timeout: 10000 }).stdout;
  const lines = ps.split(/\r?\n/).map(line => line.trim()).filter(Boolean);
  const targets = lines.flatMap(line => {
    const match = line.match(/^(\d+)\s+(.+)$/);
    if (!match) return [];
    const pid = Number(match[1]);
    const cmd = match[2];
    if (/Mactician\.app\/Contents\/MacOS\/Mactician|\/Mactician\/sdk\/emulator\/.*qemu-system-aarch64|launcher-runtime\.command|run-asg-experiment\.command|run-tft-root-affinity\.command/i.test(cmd)) return [{ pid, cmd }];
    return [];
  });
  for (const target of [...targets].sort((a, b) => b.pid - a.pid)) {
    try { process.kill(target.pid, 'SIGTERM'); } catch {}
  }
  const adbCandidates = [
    path.join(USER_HOME, 'Library', 'Application Support', 'Mactician', 'sdk', 'platform-tools', 'adb'),
    '/Volumes/MAC MINI M4/Mactician/sdk/platform-tools/adb'
  ].filter(executable);
  if (adbCandidates.length) command(adbCandidates[0], ['-P', '5038', 'kill-server'], { allowFailure: true, timeout: 10000 });
  await sleep(1200);
  const after = runtimeProcessAudit();
  const remaining = after.processes.filter(item => ['MACTICIAN_APP','ANDROID_EMULATOR'].includes(item.kind) || (item.kind === 'ADB_SERVER' && /tcp:5038\b/.test(item.command)));
  if (remaining.length) throw new Error(`MACTICIAN_STOP_INCOMPLETE: ${JSON.stringify(remaining)}`);
  return { action: 'MACTICIAN_STOPPED', terminated: targets, observedAt: nowISO(), auditAfter: after };
}

function newestMatchingFile(roots, pattern, maximum = 20000) {
  const candidates = [];
  for (const root of roots) {
    if (!exists(root)) continue;
    for (const file of walk(root, 5, maximum)) {
      try {
        const stat = fs.statSync(file);
        if (stat.isFile() && pattern.test(file)) candidates.push({ file, mtimeMs: stat.mtimeMs });
      } catch {}
    }
  }
  candidates.sort((a, b) => b.mtimeMs - a.mtimeMs);
  return candidates[0]?.file ?? null;
}

function macticianRuntimeAudit() {
  const processAudit = runtimeProcessAudit();
  const ps = command('/bin/ps', ['axo', 'pid=,ppid=,etime=,command='], { allowFailure: true, timeout: 10000, maxBuffer: 32 * 1024 * 1024 });
  const processTree = ps.stdout.split(/\r?\n/).map(line => line.trim()).filter(Boolean)
    .filter(line => /(Mactician|TftPBE|emulator-5582|qemu-system-aarch64|\/emulator(?:\s|$))/i.test(line));
  const app = '/Applications/Mactician.app';
  const appVersion = exists(path.join(app, 'Contents', 'Info.plist'))
    ? command('/usr/libexec/PlistBuddy', ['-c', 'Print :CFBundleShortVersionString', path.join(app, 'Contents', 'Info.plist')], { allowFailure: true, timeout: 10000 }).stdout.trim() || null
    : null;
  const appBuild = exists(path.join(app, 'Contents', 'Info.plist'))
    ? command('/usr/libexec/PlistBuddy', ['-c', 'Print :CFBundleVersion', path.join(app, 'Contents', 'Info.plist')], { allowFailure: true, timeout: 10000 }).stdout.trim() || null
    : null;
  const macticianAdbPort = processTree.map(line => line.match(/adb\s+-L\s+tcp:(\d+)\s+fork-server/i)?.[1]).find(Boolean)
    ?? processAudit.processes.map(item => item.command.match(/adb\s+-L\s+tcp:(\d+)\s+fork-server/i)?.[1]).find(Boolean)
    ?? '5038';
  const adbCandidates = [
    path.join(USER_HOME, 'Library', 'Application Support', 'Mactician', 'sdk', 'platform-tools', 'adb'),
    '/Volumes/MAC MINI M4/Mactician/sdk/platform-tools/adb'
  ].filter(executable);
  const adbSnapshots = adbCandidates.map(adbPath => {
    const devices = command(adbPath, ['-P', macticianAdbPort, 'devices', '-l'], { allowFailure: true, timeout: 10000 });
    const serials = [...devices.stdout.matchAll(/^(emulator-\d+)\s+device\b/gm)].map(match => match[1]);
    const snapshots = serials.map(serial => {
      const shell = args => command(adbPath, ['-P', macticianAdbPort, '-s', serial, ...args], { allowFailure: true, timeout: 20000, maxBuffer: 24 * 1024 * 1024 }).stdout.trim();
      const packageDump = shell(['shell', 'dumpsys', 'package', PACKAGE]);
      const props = {};
      for (const key of ['ro.boot.qemu.avd_name','ro.hardware.egl','ro.hardware.vulkan','ro.opengles.version','ro.boot.qemu.gltransport','ro.boot.qemu.gles']) props[key] = shell(['shell', 'getprop', key]) || null;
      const angleSettings = {};
      for (const key of ['angle_gl_driver_all_angle','angle_gl_driver_selection_pkgs','angle_gl_driver_selection_values']) angleSettings[key] = shell(['shell', 'settings', 'get', 'global', key]) || null;
      const surfaceFlinger = shell(['shell', 'dumpsys', 'SurfaceFlinger']);
      return {
        serial,
        bootCompleted: shell(['shell', 'getprop', 'sys.boot_completed']) || null,
        avdName: shell(['emu', 'avd', 'name']) || props['ro.boot.qemu.avd_name'],
        packagePath: shell(['shell', 'pm', 'path', PACKAGE]) || null,
        versionName: packageDump.match(/versionName=([^\s]+)/)?.[1] ?? null,
        versionCode: packageDump.match(/versionCode=(\d+)/)?.[1] ?? null,
        packagePid: shell(['shell', 'pidof', PACKAGE]) || null,
        topActivity: shell(['shell', 'dumpsys', 'activity', 'activities']).split(/\r?\n/).filter(line => /topResumedActivity|mResumedActivity|teamfighttactics|leagueoflegends/i.test(line)).slice(0, 40),
        properties: props,
        angleSettings,
        displaySize: shell(['shell', 'wm', 'size']) || null,
        displayDensity: shell(['shell', 'wm', 'density']) || null,
        surfaceFlingerGraphics: surfaceFlinger.split(/\r?\n/).filter(line => /GLES|OpenGL|Vulkan|ANGLE|gfxstream|GPU|renderer/i.test(line)).slice(0, 160)
      };
    });
    return { adbPath, devices: devices.stdout.trim(), snapshots };
  });
  const logRoots = [
    path.join(USER_HOME, 'Library', 'Application Support', 'Mactician', 'logs'),
    path.join(USER_HOME, 'Library', 'Application Support', 'Mactician'),
    '/Volumes/MAC MINI M4/Mactician'
  ];
  const latestLog = newestMatchingFile(logRoots, /(?:launcher|emulator|mactician|tft).*\.log$/i);
  let graphicsLogEvidence = [];
  let failureLogEvidence = [];
  let latestLogTail = [];
  if (latestLog) {
    try {
      const logLines = fs.readFileSync(latestLog, 'utf8').split(/\r?\n/);
      latestLogTail = logLines.slice(-240);
      graphicsLogEvidence = logLines.filter(line => /ANGLE|ASG|gfxstream|MoltenVK|Metal|Vulkan|Setting ICD|gltransport|GuestAngle|feature/i.test(line)).slice(-200);
      failureLogEvidence = logLines.filter(line => /error|failed|failure|fatal|abort|offline|not found|missing|exit|terminated|could not|cannot|timed out|timeout/i.test(line)).slice(-160);
    } catch {}
  }
  const relevantPorts = command('/usr/sbin/lsof', ['-nP', '-iTCP:5037', '-iTCP:5038', '-iTCP:5040', '-iTCP:5582', '-iTCP:5592'], { allowFailure: true, timeout: 10000, maxBuffer: 8 * 1024 * 1024 }).stdout.split(/\r?\n/).filter(Boolean);
  return { observedAt: nowISO(), appVersion, appBuild, macticianAdbPort: Number(macticianAdbPort), processAudit, processTree, relevantPorts, adbSnapshots, latestLog, latestLogTail, failureLogEvidence, graphicsLogEvidence };
}

function cleanupObserverAdb5037() {
  const ps = command('/bin/ps', ['axo', 'pid=,command='], { allowFailure: true, timeout: 10000 }).stdout;
  const observed = ps.split(/\r?\n/).map(line => line.trim()).filter(line => /adb\s+-L\s+tcp:5037\s+fork-server/i.test(line));
  if (!observed.length) return { action: 'OBSERVER_ADB_5037_ABSENT' };
  const adbCandidates = [
    path.join(USER_HOME, 'Library', 'Application Support', 'Mactician', 'sdk', 'platform-tools', 'adb'),
    '/Volumes/MAC MINI M4/Mactician/sdk/platform-tools/adb'
  ].filter(executable);
  if (!adbCandidates.length) throw new Error('No Mactician adb binary available to remove observer-created 5037 server.');
  const killed = command(adbCandidates[0], ['-P', '5037', 'kill-server'], { allowFailure: true, timeout: 10000 });
  const after = command('/bin/ps', ['axo', 'pid=,command='], { allowFailure: true, timeout: 10000 }).stdout.split(/\r?\n/).map(line => line.trim()).filter(line => /adb\s+-L\s+tcp:5037\s+fork-server/i.test(line));
  if (after.length) throw new Error(`OBSERVER_ADB_5037_CLEANUP_FAILED: ${(killed.stderr || killed.stdout || '').trim()}`);
  return { action: 'OBSERVER_ADB_5037_CLEANED', observed, killStatus: killed.status };
}

function openPlayWeb() {
  const url = `https://play.google.com/store/apps/details?id=${PACKAGE}`;
  const result = command('/usr/bin/open', [url], { allowFailure: true, timeout: 30000 });
  return { action: 'PLAY_WEB_OPENED', url, openStatus: result.status, stderr: result.stderr.trim() || null };
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
  if (action === 'open-play-web') { json(openPlayWeb()); return; }
  if (action === 'runtime-process-audit') { json(runtimeProcessAudit()); return; }
  if (action === 'cleanup-tftmac-adb-residue') { json(cleanupTftmacAdbResidue()); return; }
  if (action === 'single-runtime-preflight') { json(singleRuntimePreflight()); return; }
  if (action === 'launch-mactician-control') { json(launchMacticianControl()); return; }
  if (action === 'stop-mactician-control') { json(await stopMacticianControl()); return; }
  if (action === 'mactician-runtime-audit') { json(macticianRuntimeAudit()); return; }
  if (action === 'cleanup-observer-adb-5037') { json(cleanupObserverAdb5037()); return; }
  if (action === 'start') { json(await startControl()); return; }
  if (action === 'start-donor-control') { json(await startDonorControl()); return; }
  if (action === 'play-action') { json(await playAction()); return; }
  if (action === 'play-probe') { json(await playProbe()); return; }
  if (action === 'launch-game') { json(await launchGame()); return; }
  if (action === 'gles-capability-probe') { json(glesCapabilityProbe()); return; }
  if (action === 'launch-failure-probe') { json(launchFailureProbe()); return; }
  if (action === 'recover-anr-wait') { json(await recoverAnrWait()); return; }
  if (action === 'logger-health') { json(await loggerHealth()); return; }
  if (action === 'status') { json(await status()); return; }
  if (action === 'play-certification') { json(await playCertification()); return; }
  if (action === 'play-diagnose') { json(await playDiagnose()); return; }
  if (action === 'auth-brief') { json(await authBrief()); return; }
  if (action === 'install-diagnose') { json(await installDiagnose()); return; }
  if (action === 'play-install-brief') { json(await playInstallBrief()); return; }
  if (action === 'play-store-repair') { json(await playStoreRepair()); return; }
  if (action === 'google-account-ui') { json(await googleAccountUI()); return; }
  if (action === 'image-check') { json(imageCheck()); return; }
  if (action === 'device-profiles') { json(deviceProfiles()); return; }
  if (action === 'image-upgrade-start') { json(imageUpgradeStart()); return; }
  if (action === 'image-upgrade-status') { json(imageUpgradeStatus()); return; }
  if (action === 'image-upgrade-worker') { json(await imageUpgradeWorker()); return; }
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
  throw new Error('Usage: tftmac-direct-control.mjs inventory|prepare|lab-selftest|build|launch-app|runtime-process-audit|single-runtime-preflight|launch-mactician-control|mactician-runtime-audit|start|start-donor-control|play-action|launch-game|gles-capability-probe|launch-failure-probe|status|play-certification|marker|match-entry|combat-start|stop|package-state');
}

main().catch(error => { process.stderr.write(`${error.stack || error.message}\n`); process.exit(1); });
