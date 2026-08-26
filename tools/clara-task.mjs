#!/usr/bin/env node
import { createHash } from 'node:crypto';
import { createReadStream, existsSync } from 'node:fs';
import { mkdir, readFile, rename, rm, stat, writeFile, copyFile, readdir } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn, spawnSync } from 'node:child_process';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const PRIVATE = join(ROOT, 'private');
const ACQ = join(PRIVATE, 'live-acquisition');
const SDK = join(ACQ, 'sdk');
const DOWNLOADS = join(ACQ, 'downloads');
const AVD_HOME = join(ACQ, 'avd');
const AVD_NAME = 'TftLiveStore';
const PERFORMANCE_AVD_NAME = 'TftHighEndTablet';
const SERIAL = 'emulator-5590';
const PERFORMANCE_SERIAL = 'emulator-5592';
const ADB_PORT = '5040';
const PACKAGE = 'com.riotgames.league.teamfighttactics';
const EXPECTED_ACTIVITY = 'com.riotgames.leagueoflegends.RiotNativeActivity';
const LIVE_ROOT = join(PRIVATE, 'live-apks');
const LIVE_CURRENT = join(LIVE_ROOT, 'current');
const LIVE_MANIFEST = join(LIVE_ROOT, 'manifest.json');
const RELEASE_TEMPLATE = join(ROOT, 'launcher', 'Resources', 'release-manifest.json');
const PLAY_REPO = 'https://dl.google.com/android/repository/sys-img/google_apis_playstore/sys-img2-3.xml';
const PLAY_REPO_BASE = 'https://dl.google.com/android/repository/sys-img/google_apis_playstore/';
const PLAY_PACKAGE_PATH = 'system-images;android-36;google_apis_playstore;arm64-v8a';

function die(message) {
  console.error(`TFTMAC: ${message}`);
  process.exit(1);
}

function run(executable, args, options = {}) {
  const result = spawnSync(executable, args, {
    cwd: options.cwd ?? ROOT,
    env: options.env ?? process.env,
    encoding: 'utf8',
    stdio: options.capture ? ['ignore', 'pipe', 'pipe'] : 'inherit',
    maxBuffer: 16 * 1024 * 1024
  });
  if (result.error) die(`${executable} failed to start: ${result.error.message}`);
  if (result.status !== 0) {
    if (options.capture) {
      if (result.stdout) process.stdout.write(result.stdout);
      if (result.stderr) process.stderr.write(result.stderr);
    }
    die(`${executable} exited with ${result.status}`);
  }
  return options.capture ? String(result.stdout ?? '').trim() : '';
}

async function hashFile(path, algorithm = 'sha256') {
  return new Promise((resolveHash, reject) => {
    const hash = createHash(algorithm);
    const stream = createReadStream(path);
    stream.on('error', reject);
    stream.on('data', chunk => hash.update(chunk));
    stream.on('end', () => resolveHash(hash.digest('hex')));
  });
}

async function download(url, destination, expectedHash, algorithm = 'sha256') {
  await mkdir(dirname(destination), { recursive: true });
  if (existsSync(destination) && expectedHash) {
    if (await hashFile(destination, algorithm) === expectedHash) return;
    await rm(destination, { force: true });
  }
  const partial = `${destination}.partial`;
  run('/usr/bin/curl', ['-fL', '--retry', '3', '--retry-delay', '2', '--continue-at', '-', url, '-o', partial]);
  if (expectedHash) {
    const actual = await hashFile(partial, algorithm);
    if (actual !== expectedHash) {
      await rm(partial, { force: true });
      die(`checksum mismatch for ${url}: expected ${expectedHash}, got ${actual}`);
    }
  }
  await rename(partial, destination);
}

async function extractZip(zip, destination) {
  await rm(destination, { recursive: true, force: true });
  await mkdir(destination, { recursive: true });
  run('/usr/bin/unzip', ['-q', zip, '-d', destination]);
}

async function ensureCoreSDK() {
  const template = JSON.parse(await readFile(RELEASE_TEMPLATE, 'utf8'));
  for (const id of ['platform-tools', 'emulator']) {
    const component = template.components.find(entry => entry.id === id);
    if (!component) die(`release template lacks ${id}`);
    const target = join(ACQ, component.installPath);
    const marker = id === 'platform-tools' ? join(target, 'adb') : join(target, 'emulator');
    if (existsSync(marker)) continue;
    const archive = join(DOWNLOADS, `${id}.zip`);
    await download(component.url, archive, component.sha256, 'sha256');
    const stage = join(ACQ, `.stage-${id}`);
    await extractZip(archive, stage);
    const source = join(stage, component.archiveRoot);
    if (!existsSync(source)) die(`${id} archive did not contain ${component.archiveRoot}`);
    await mkdir(dirname(target), { recursive: true });
    await rm(target, { recursive: true, force: true });
    await rename(source, target);
    await rm(stage, { recursive: true, force: true });
  }
}

function xmlBlockForPackage(xml, packagePath) {
  const escaped = packagePath.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const match = xml.match(new RegExp(`<remotePackage\\b[^>]*path=["']${escaped}["'][^>]*>([\\s\\S]*?)<\\/remotePackage>`));
  if (!match) die(`Google repository does not list ${packagePath}`);
  return match[1];
}

function xmlText(block, tag) {
  const match = block.match(new RegExp(`<${tag}(?:\\s[^>]*)?>([\\s\\S]*?)<\\/${tag}>`));
  return match?.[1]?.trim() ?? null;
}

async function ensurePlayImage() {
  const install = join(SDK, 'system-images', 'android-36', 'google_apis_playstore', 'arm64-v8a');
  if (existsSync(join(install, 'system.img')) && existsSync(join(install, 'source.properties'))) return;
  await mkdir(DOWNLOADS, { recursive: true });
  const repoXML = join(DOWNLOADS, 'google-play-system-images.xml');
  run('/usr/bin/curl', ['-fL', '--retry', '3', PLAY_REPO, '-o', repoXML]);
  const xml = await readFile(repoXML, 'utf8');
  const block = xmlBlockForPackage(xml, PLAY_PACKAGE_PATH);
  const archives = block.match(/<archives>([\s\S]*?)<\/archives>/)?.[1] ?? block;
  const archive = archives.match(/<archive>([\s\S]*?<complete>[\s\S]*?<\/complete>[\s\S]*?)<\/archive>/)?.[1];
  if (!archive) die('Google Play system-image metadata has no complete archive');
  const complete = archive.match(/<complete>([\s\S]*?)<\/complete>/)?.[1];
  if (!complete) die('Google Play system-image metadata is incomplete');
  const filename = xmlText(complete, 'url');
  const checksumMatch = complete.match(/<checksum\s+type=["'](sha1|sha256)["']>([0-9a-fA-F]+)<\/checksum>/);
  if (!filename || !checksumMatch) die('Google Play system-image URL/checksum missing');
  const algorithm = checksumMatch[1].toLowerCase();
  const expected = checksumMatch[2].toLowerCase();
  const archivePath = join(DOWNLOADS, filename.split('/').pop());
  await download(new URL(filename, PLAY_REPO_BASE).href, archivePath, expected, algorithm);
  const stage = join(ACQ, '.stage-play-image');
  await extractZip(archivePath, stage);
  const source = existsSync(join(stage, 'arm64-v8a')) ? join(stage, 'arm64-v8a') : stage;
  if (!existsSync(join(source, 'system.img'))) die('Google Play archive did not contain system.img');
  await mkdir(dirname(install), { recursive: true });
  await rm(install, { recursive: true, force: true });
  if (source === stage) {
    await mkdir(install, { recursive: true });
    for (const entry of await readdir(stage)) await rename(join(stage, entry), join(install, entry));
    await rm(stage, { recursive: true, force: true });
  } else {
    await rename(source, install);
    await rm(stage, { recursive: true, force: true });
  }
}

async function ensureAcquisitionAVD() {
  const avd = join(AVD_HOME, `${AVD_NAME}.avd`);
  const ini = join(AVD_HOME, `${AVD_NAME}.ini`);
  if (existsSync(join(avd, 'config.ini')) && existsSync(ini)) return false;
  await mkdir(avd, { recursive: true });
  const config = `AvdId=${AVD_NAME}\navd.ini.displayname=TFTMAC Google Play Acquisition\nabi.type=arm64-v8a\nhw.cpu.arch=arm64\nhw.cpu.ncore=4\nhw.lcd.density=320\nhw.lcd.height=1080\nhw.lcd.width=1920\nhw.ramSize=4096\nhw.vmHeapSize=576\nhw.gpu.enabled=yes\nhw.gpu.mode=host\nhw.keyboard=yes\nskin.name=1920x1080\nshowDeviceFrame=no\ndisk.dataPartition.size=12288M\nimage.sysdir.1=system-images/android-36/google_apis_playstore/arm64-v8a/\ntag.id=google_apis_playstore\ntag.display=Google Play\nPlayStore.enabled=true\nfastboot.forceColdBoot=yes\nfastboot.forceFastBoot=no\navd.ini.encoding=UTF-8\n`;
  await writeFile(join(avd, 'config.ini'), config);
  await writeFile(ini, `avd.ini.encoding=UTF-8\npath=${avd}\npath.rel=${AVD_NAME}.avd\ntarget=android-36\n`);
  const qemuImg = join(SDK, 'emulator', 'qemu-img');
  run(qemuImg, ['create', '-f', 'qcow2', join(avd, 'userdata-qemu.img'), '12G']);
  const encryption = join(SDK, 'system-images', 'android-36', 'google_apis_playstore', 'arm64-v8a', 'encryptionkey.img');
  if (existsSync(encryption)) await copyFile(encryption, join(avd, 'encryptionkey.img'));
  return true;
}

function adb(args, capture = true) {
  const executable = join(SDK, 'platform-tools', 'adb');
  return run(executable, ['-P', ADB_PORT, '-s', SERIAL, ...args], {
    capture,
    env: { ...process.env, ANDROID_ADB_SERVER_PORT: ADB_PORT, ADB_MDNS_AUTO_CONNECT: '' }
  });
}

function adbMaybe(args) {
  const executable = join(SDK, 'platform-tools', 'adb');
  const result = spawnSync(executable, ['-P', ADB_PORT, '-s', SERIAL, ...args], {
    encoding: 'utf8',
    env: { ...process.env, ANDROID_ADB_SERVER_PORT: ADB_PORT, ADB_MDNS_AUTO_CONNECT: '' },
    maxBuffer: 16 * 1024 * 1024
  });
  return result.status === 0 ? String(result.stdout ?? '').trim() : null;
}

async function waitUntil(description, seconds, test) {
  const deadline = Date.now() + seconds * 1000;
  while (Date.now() < deadline) {
    const value = await test();
    if (value) return value;
    await new Promise(resolveWait => setTimeout(resolveWait, 1000));
  }
  die(`timed out waiting for ${description}`);
}

async function acquireLive() {
  await mkdir(ACQ, { recursive: true });
  console.log('TFTMAC: preparing official Google Android components...');
  await ensureCoreSDK();
  await ensurePlayImage();
  const firstBoot = await ensureAcquisitionAVD();
  const adbExe = join(SDK, 'platform-tools', 'adb');
  run(adbExe, ['-P', ADB_PORT, 'start-server'], { env: { ...process.env, ANDROID_ADB_SERVER_PORT: ADB_PORT, ADB_MDNS_AUTO_CONNECT: '' } });

  let emulator = null;
  if (!adbMaybe(['get-state'])) {
    const emulatorExe = join(SDK, 'emulator', 'emulator');
    const args = [`@${AVD_NAME}`, '-id', 'TFTMAC-Google-Play', '-port', '5590', '-gpu', 'host', '-skin', '1920x1080', '-cores', '4', '-memory', '4096', '-no-snapshot', '-no-metrics', '-no-boot-anim', '-no-audio', '-crash-report-mode', 'disabled'];
    if (firstBoot) args.push('-wipe-data');
    emulator = spawn(emulatorExe, args, {
      cwd: ROOT,
      env: { ...process.env, ANDROID_SDK_ROOT: SDK, ANDROID_AVD_HOME: AVD_HOME, ANDROID_ADB_SERVER_PORT: ADB_PORT, ADB_MDNS_AUTO_CONNECT: '' },
      stdio: 'ignore'
    });
    emulator.on('error', error => die(`Google Play emulator failed: ${error.message}`));
  }

  await waitUntil('Google Play emulator ADB', 240, () => adbMaybe(['get-state']) === 'device');
  await waitUntil('Android boot', 240, () => adbMaybe(['shell', 'getprop', 'sys.boot_completed'])?.replace(/\r/g, '') === '1');
  await writeFile(join(AVD_HOME, `${AVD_NAME}.avd`, '.tftmac-initialized'), new Date().toISOString());

  const installed = adbMaybe(['shell', 'pm', 'path', PACKAGE]);
  if (!installed) {
    adb(['shell', 'am', 'start', '-a', 'android.intent.action.VIEW', '-d', `market://details?id=${PACKAGE}`], false);
    console.log('\nTFTMAC_GOOGLE_PLAY_READY');
    console.log('Google Play is open in the Android window. Sign in there and install "TFT: Teamfight Tactics" from Riot Games.');
    console.log('Do not enter Google or Riot credentials anywhere outside the Google Play / TFT Android windows.');
    console.log('This process will detect the completed install automatically.\n');
    await waitUntil('live TFT installation from Google Play', 1800, () => adbMaybe(['shell', 'pm', 'path', PACKAGE]));
  }

  const installerLine = adb(['shell', 'pm', 'list', 'packages', '-i', PACKAGE]);
  if (!installerLine.includes(`package:${PACKAGE}`) || !installerLine.includes('installer=com.android.vending')) {
    die(`live TFT was not installed by Google Play: ${installerLine || 'no installer record'}`);
  }

  const packagePathsOutput = adb(['shell', 'pm', 'path', PACKAGE]).replace(/\r/g, '');
  const packagePaths = packagePathsOutput.split('\n').map(line => line.replace(/^package:/, '').trim()).filter(Boolean);
  if (!packagePaths.length) die('Google Play TFT has no APK paths');
  packagePaths.sort((a, b) => (a.endsWith('/base.apk') ? -1 : b.endsWith('/base.apk') ? 1 : a.localeCompare(b)));
  if (!packagePaths[0].endsWith('/base.apk')) die('Google Play TFT base.apk was not found');

  const dump = adb(['shell', 'dumpsys', 'package', PACKAGE]);
  const versionName = dump.match(/versionName=([^\s]+)/)?.[1];
  const versionCodeText = dump.match(/versionCode=(\d+)/)?.[1];
  if (!versionName || !versionCodeText) die('could not determine live TFT version');
  const versionCode = Number(versionCodeText);

  const resolved = adbMaybe(['shell', 'cmd', 'package', 'resolve-activity', '--brief', '-a', 'android.intent.action.MAIN', '-c', 'android.intent.category.LAUNCHER', PACKAGE]) ?? '';
  if (!resolved.includes(EXPECTED_ACTIVITY) && !dump.includes(EXPECTED_ACTIVITY)) {
    die(`live TFT no longer exposes expected Unreal activity ${EXPECTED_ACTIVITY}; observed ${resolved || 'none'}`);
  }

  const stage = join(LIVE_ROOT, `.next-${Date.now()}`);
  await rm(stage, { recursive: true, force: true });
  await mkdir(stage, { recursive: true });
  const apks = [];
  const used = new Set();
  for (const remotePath of packagePaths) {
    let name = remotePath.split('/').pop();
    if (used.has(name)) die(`duplicate APK split filename from Google Play: ${name}`);
    used.add(name);
    const localPath = join(stage, name);
    adb(['pull', remotePath, localPath], false);
    const info = await stat(localPath);
    const sha256 = await hashFile(localPath, 'sha256');
    apks.push({ name, size: info.size, sha256 });
  }

  const base = apks[0];
  const basePath = join(stage, 'base.apk');
  const zipList = run('/usr/bin/unzip', ['-l', basePath], { capture: true });
  const hasUECommandLine = zipList.includes('assets/UECommandLine.txt');

  const manifest = {
    packageName: PACKAGE,
    version: versionName,
    versionCode,
    launchActivity: resolved.split('\n').pop()?.trim() || null,
    baseSHA256: base.sha256,
    donorUECommandLineCompatible: hasUECommandLine,
    apks
  };
  await mkdir(LIVE_ROOT, { recursive: true });
  const manifestNext = join(LIVE_ROOT, '.manifest.next.json');
  await writeFile(manifestNext, `${JSON.stringify(manifest, null, 2)}\n`);
  await rm(LIVE_CURRENT, { recursive: true, force: true });
  await rename(stage, LIVE_CURRENT);
  await rename(manifestNext, LIVE_MANIFEST);
  console.log(`TFTMAC_ACQUIRED ${versionName} versionCode=${versionCode} splits=${apks.length}`);
  console.log(`TFTMAC_BASE_SHA256 ${base.sha256}`);
  console.log(`TFTMAC_LAUNCH_ACTIVITY ${manifest.launchActivity ?? 'unknown'}`);
  console.log(`TFTMAC_UECOMMANDLINE ${hasUECommandLine ? 'present' : 'absent'}`);

  adbMaybe(['emu', 'kill']);
  if (emulator) {
    await new Promise(resolveWait => {
      const timer = setTimeout(resolveWait, 15000);
      emulator.once('exit', () => { clearTimeout(timer); resolveWait(); });
    });
  }
}

async function prepareHighEndTablet() {
  await mkdir(ACQ, { recursive: true });
  await ensureCoreSDK();
  await ensurePlayImage();
  await ensureAcquisitionAVD();
  if (adbMaybe(['get-state'])) {
    die('Google Play acquisition device is still running; finish the Riot patch and shut it down cleanly before cloning the high-end tablet');
  }
  const sourceAVD = join(AVD_HOME, `${AVD_NAME}.avd`);
  const targetAVD = join(AVD_HOME, `${PERFORMANCE_AVD_NAME}.avd`);
  const sourceINI = join(AVD_HOME, `${AVD_NAME}.ini`);
  const targetINI = join(AVD_HOME, `${PERFORMANCE_AVD_NAME}.ini`);
  if (!existsSync(sourceAVD) || !existsSync(sourceINI)) die('source Google Play AVD is missing');
  await rm(targetAVD, { recursive: true, force: true });
  await rm(targetINI, { force: true });
  run('/bin/cp', ['-R', sourceAVD, targetAVD]);
  let config = await readFile(join(targetAVD, 'config.ini'), 'utf8');
  const set = (key, value) => {
    const pattern = new RegExp(`^${key.replace(/[.*+?^${}()|[\\]\\]/g, '\\$&')}=.*$`, 'm');
    if (pattern.test(config)) config = config.replace(pattern, `${key}=${value}`);
    else config += `\n${key}=${value}`;
  };
  set('AvdId', PERFORMANCE_AVD_NAME);
  set('avd.ini.displayname', 'TFTMAC High-End Tablet');
  set('hw.device.manufacturer', 'Google');
  set('hw.device.name', 'pixel_tablet');
  set('hw.initialOrientation', 'Landscape');
  set('hw.cpu.ncore', '8');
  set('hw.ramSize', '8192');
  set('hw.vmHeapSize', '768');
  set('hw.lcd.width', '1920');
  set('hw.lcd.height', '1080');
  set('hw.lcd.density', '280');
  set('hw.gpu.enabled', 'yes');
  set('hw.gpu.mode', 'host');
  set('hw.keyboard', 'yes');
  set('showDeviceFrame', 'no');
  set('skin.name', '1920x1080');
  set('runtime.network.speed', 'full');
  set('runtime.network.latency', 'none');
  set('fastboot.forceColdBoot', 'yes');
  set('fastboot.forceFastBoot', 'no');
  await writeFile(join(targetAVD, 'config.ini'), config);
  await rm(join(targetAVD, 'hardware-qemu.ini'), { force: true });
  await rm(join(targetAVD, 'hardware-qemu.ini.lock'), { force: true });
  await rm(join(targetAVD, 'multiinstance.lock'), { force: true });
  await writeFile(targetINI, `avd.ini.encoding=UTF-8\npath=${targetAVD}\npath.rel=${PERFORMANCE_AVD_NAME}.avd\ntarget=android-36\n`);
  const contract = {
    schemaVersion: 1,
    avdName: PERFORMANCE_AVD_NAME,
    donorProfile: 'Pixel Tablet / custom high-end tablet',
    sourceImage: 'Google Play ARM64 Android 16 API 36',
    renderTarget: '1920x1080',
    densityDpi: 280,
    smallestWidthDp: Math.floor(1080 * 160 / 280),
    cpuCores: 8,
    ramMB: 8192,
    vmHeapMB: 768,
    gpuMode: 'host',
    enhancedBootFlags: [
      '-feature', 'GLESDynamicVersion,Vulkan,GuestAngle,-GLPipeChecksum,AsyncComposeSupport,VirtioGpuFenceContexts',
      '-append-userspace-opt', 'androidboot.opengles.version=196610'
    ],
    createdAt: new Date().toISOString()
  };
  await writeFile(join(AVD_HOME, `${PERFORMANCE_AVD_NAME}.json`), `${JSON.stringify(contract, null, 2)}\n`);
  console.log(JSON.stringify(contract, null, 2));
}

async function stopAcquisition() {
  await ensureCoreSDK();
  if (!adbMaybe(['get-state'])) {
    console.log('TFTMAC_ACQUISITION_STOPPED already_off');
    return;
  }
  adbMaybe(['emu', 'kill']);
  await waitUntil('Google Play acquisition shutdown', 60, () => !adbMaybe(['get-state']));
  console.log('TFTMAC_ACQUISITION_STOPPED clean');
}

async function playHighEndTablet() {
  await ensureCoreSDK();
  await ensurePlayImage();
  const targetAVD = join(AVD_HOME, `${PERFORMANCE_AVD_NAME}.avd`);
  const targetINI = join(AVD_HOME, `${PERFORMANCE_AVD_NAME}.ini`);
  if (!existsSync(join(targetAVD, 'config.ini')) || !existsSync(targetINI)) {
    die('high-end tablet is not prepared yet');
  }
  const adbExe = join(SDK, 'platform-tools', 'adb');
  run(adbExe, ['-P', ADB_PORT, 'start-server'], { env: { ...process.env, ANDROID_ADB_SERVER_PORT: ADB_PORT, ADB_MDNS_AUTO_CONNECT: '' } });
  const performanceState = (() => {
    const executable = join(SDK, 'platform-tools', 'adb');
    const result = spawnSync(executable, ['-P', ADB_PORT, '-s', PERFORMANCE_SERIAL, 'get-state'], {
      encoding: 'utf8',
      env: { ...process.env, ANDROID_ADB_SERVER_PORT: ADB_PORT, ADB_MDNS_AUTO_CONNECT: '' }
    });
    return result.status === 0 ? String(result.stdout ?? '').trim() : null;
  })();
  if (performanceState !== 'device') {
    const emulatorExe = join(SDK, 'emulator', 'emulator');
    const child = spawn(emulatorExe, [
      `@${PERFORMANCE_AVD_NAME}`, '-id', 'TFTMAC-High-End-Tablet', '-port', '5592',
      '-gpu', 'host', '-skin', '1920x1080', '-cores', '8', '-memory', '8192',
      '-no-snapshot', '-no-metrics', '-no-boot-anim', '-crash-report-mode', 'disabled',
      '-feature', 'GLESDynamicVersion,Vulkan,GuestAngle,-GLPipeChecksum,AsyncComposeSupport,VirtioGpuFenceContexts',
      '-append-userspace-opt', 'androidboot.opengles.version=196610'
    ], {
      cwd: ROOT,
      env: { ...process.env, ANDROID_SDK_ROOT: SDK, ANDROID_AVD_HOME: AVD_HOME, ANDROID_ADB_SERVER_PORT: ADB_PORT, ADB_MDNS_AUTO_CONNECT: '' },
      detached: true,
      stdio: 'ignore'
    });
    child.unref();
  }
  const perfADB = args => {
    const executable = join(SDK, 'platform-tools', 'adb');
    const result = spawnSync(executable, ['-P', ADB_PORT, '-s', PERFORMANCE_SERIAL, ...args], {
      encoding: 'utf8',
      env: { ...process.env, ANDROID_ADB_SERVER_PORT: ADB_PORT, ADB_MDNS_AUTO_CONNECT: '' },
      maxBuffer: 16 * 1024 * 1024
    });
    return result.status === 0 ? String(result.stdout ?? '').trim() : null;
  };
  await waitUntil('high-end tablet ADB', 240, () => perfADB(['get-state']) === 'device');
  await waitUntil('high-end tablet Android boot', 240, () => perfADB(['shell', 'getprop', 'sys.boot_completed'])?.replace(/\r/g, '') === '1');
  perfADB(['shell', 'wm', 'size', '1920x1080']);
  perfADB(['shell', 'wm', 'density', '280']);
  const installed = perfADB(['shell', 'pm', 'path', PACKAGE]);
  if (!installed) die('TFT is missing from high-end tablet clone');
  perfADB(['shell', 'am', 'force-stop', PACKAGE]);
  perfADB(['shell', 'am', 'start', '-n', `${PACKAGE}/com.riotgames.leagueoflegends.RiotNativeActivity`]);
  const pid = await waitUntil('TFT on high-end tablet', 120, () => perfADB(['shell', 'pidof', PACKAGE]));
  const gles = perfADB(['shell', 'getprop', 'ro.opengles.version']);
  const bootGles = perfADB(['shell', 'getprop', 'ro.boot.opengles.version']);
  const vulkan = perfADB(['shell', 'getprop', 'ro.hardware.vulkan']);
  const size = perfADB(['shell', 'wm', 'size']);
  const density = perfADB(['shell', 'wm', 'density']);
  console.log(JSON.stringify({
    ok: true,
    avdName: PERFORMANCE_AVD_NAME,
    pid,
    packageName: PACKAGE,
    renderTarget: size,
    density,
    roOpenGLESVersion: gles,
    bootOpenGLESVersion: bootGles,
    vulkanHardware: vulkan,
    cpuCores: 8,
    ramMB: 8192
  }, null, 2));
}

async function repairHighEndLaunchState() {
  await ensureCoreSDK();
  const runPerf = args => {
    const executable = join(SDK, 'platform-tools', 'adb');
    const result = spawnSync(executable, ['-P', ADB_PORT, '-s', PERFORMANCE_SERIAL, ...args], {
      encoding: 'utf8',
      env: { ...process.env, ANDROID_ADB_SERVER_PORT: ADB_PORT, ADB_MDNS_AUTO_CONNECT: '' },
      maxBuffer: 16 * 1024 * 1024
    });
    return { status: result.status, stdout: String(result.stdout ?? '').trim(), stderr: String(result.stderr ?? '').trim() };
  };
  const component = `${PACKAGE}/com.riotgames.leagueoflegends.RiotNativeActivity`;
  const packageEnable = runPerf(['shell', 'pm', 'enable', '--user', '0', PACKAGE]);
  const unstop = runPerf(['shell', 'cmd', 'package', 'set-stopped-state', '--user', '0', PACKAGE, 'false']);
  const activityEnable = runPerf(['shell', 'pm', 'enable', '--user', '0', component]);
  const query = runPerf(['shell', 'cmd', 'package', 'resolve-activity', '--brief', '-a', 'android.intent.action.MAIN', '-c', 'android.intent.category.LAUNCHER', PACKAGE]);
  const start = runPerf(['shell', 'am', 'start', '-W', '--user', '0', '-n', component]);
  await new Promise(resolveWait => setTimeout(resolveWait, 3000));
  const pid = runPerf(['shell', 'pidof', PACKAGE]);
  const top = runPerf(['shell', 'dumpsys', 'activity', 'activities']);
  const result = {
    packageEnable,
    unstop,
    activityEnable,
    resolvedAfterRepair: query,
    start,
    pid: pid.stdout || null,
    topActivities: top.stdout.split('\n').filter(line => /topResumedActivity|mResumedActivity|teamfighttactics/i.test(line)).slice(0, 100)
  };
  console.log(JSON.stringify(result, null, 2));
}

async function reinstallHighEndFromOfficialApk() {
  await ensureCoreSDK();
  await ensurePlayImage();
  const targetAVD = join(AVD_HOME, `${PERFORMANCE_AVD_NAME}.avd`);
  const targetINI = join(AVD_HOME, `${PERFORMANCE_AVD_NAME}.ini`);
  if (!existsSync(join(targetAVD, 'config.ini')) || !existsSync(targetINI)) {
    die('high-end tablet is not prepared yet');
  }
  const adbExe = join(SDK, 'platform-tools', 'adb');
  run(adbExe, ['-P', ADB_PORT, 'start-server'], {
    env: { ...process.env, ANDROID_ADB_SERVER_PORT: ADB_PORT, ADB_MDNS_AUTO_CONNECT: '' }
  });
  const deviceState = spawnSync(adbExe, ['-P', ADB_PORT, '-s', PERFORMANCE_SERIAL, 'get-state'], {
    encoding: 'utf8',
    env: { ...process.env, ANDROID_ADB_SERVER_PORT: ADB_PORT, ADB_MDNS_AUTO_CONNECT: '' }
  });
  if (deviceState.status !== 0 || String(deviceState.stdout ?? '').trim() !== 'device') {
    const emulatorExe = join(SDK, 'emulator', 'emulator');
    const child = spawn(emulatorExe, [
      `@${PERFORMANCE_AVD_NAME}`, '-id', 'TFTMAC-High-End-Tablet', '-port', '5592',
      '-gpu', 'host', '-skin', '1920x1080', '-cores', '8', '-memory', '8192',
      '-no-snapshot', '-no-metrics', '-no-boot-anim', '-crash-report-mode', 'disabled',
      '-feature', 'GLESDynamicVersion,Vulkan,GuestAngle,-GLPipeChecksum,AsyncComposeSupport,VirtioGpuFenceContexts',
      '-append-userspace-opt', 'androidboot.opengles.version=196610'
    ], {
      cwd: ROOT,
      env: { ...process.env, ANDROID_SDK_ROOT: SDK, ANDROID_AVD_HOME: AVD_HOME, ANDROID_ADB_SERVER_PORT: ADB_PORT, ADB_MDNS_AUTO_CONNECT: '' },
      detached: true,
      stdio: 'ignore'
    });
    child.unref();
  }
  const ready = args => {
    const result = spawnSync(adbExe, ['-P', ADB_PORT, '-s', PERFORMANCE_SERIAL, ...args], {
      encoding: 'utf8',
      env: { ...process.env, ANDROID_ADB_SERVER_PORT: ADB_PORT, ADB_MDNS_AUTO_CONNECT: '' },
      maxBuffer: 32 * 1024 * 1024
    });
    return result.status === 0 ? String(result.stdout ?? '').trim() : null;
  };
  await waitUntil('high-end tablet ADB', 240, () => ready(['get-state']) === 'device');
  await waitUntil('high-end tablet Android boot', 240, () => ready(['shell', 'getprop', 'sys.boot_completed'])?.replace(/\r/g, '') === '1');
  const activeGLES = ready(['shell', 'getprop', 'ro.opengles.version']);
  if (activeGLES !== '196610') die(`high-end tablet booted without ES 3.2 capability: ${activeGLES ?? 'unknown'}`);
  if (!existsSync(LIVE_MANIFEST) || !existsSync(join(LIVE_CURRENT, 'base.apk'))) {
    die('official Google Play TFT capture is missing');
  }
  const manifest = JSON.parse(await readFile(LIVE_MANIFEST, 'utf8'));
  const basePath = join(LIVE_CURRENT, 'base.apk');
  const actualHash = await hashFile(basePath, 'sha256');
  if (manifest.packageName !== PACKAGE || manifest.baseSHA256 !== actualHash) {
    die('official TFT APK hash no longer matches the captured Google Play manifest');
  }
  const executable = join(SDK, 'platform-tools', 'adb');
  const install = spawnSync(executable, [
    '-P', ADB_PORT, '-s', PERFORMANCE_SERIAL,
    'install', '--no-streaming', '-r', '-g', basePath
  ], {
    encoding: 'utf8',
    env: { ...process.env, ANDROID_ADB_SERVER_PORT: ADB_PORT, ADB_MDNS_AUTO_CONNECT: '' },
    maxBuffer: 32 * 1024 * 1024
  });
  const runPerf = args => {
    const result = spawnSync(executable, ['-P', ADB_PORT, '-s', PERFORMANCE_SERIAL, ...args], {
      encoding: 'utf8',
      env: { ...process.env, ANDROID_ADB_SERVER_PORT: ADB_PORT, ADB_MDNS_AUTO_CONNECT: '' },
      maxBuffer: 32 * 1024 * 1024
    });
    return { status: result.status, stdout: String(result.stdout ?? '').trim(), stderr: String(result.stderr ?? '').trim() };
  };
  const component = `${PACKAGE}/com.riotgames.leagueoflegends.RiotNativeActivity`;
  const query = runPerf(['shell', 'cmd', 'package', 'resolve-activity', '--brief', '-a', 'android.intent.action.MAIN', '-c', 'android.intent.category.LAUNCHER', PACKAGE]);
  const start = runPerf(['shell', 'am', 'start', '-W', '--user', '0', '-n', component]);
  await new Promise(resolveWait => setTimeout(resolveWait, 3000));
  const pid = runPerf(['shell', 'pidof', PACKAGE]);
  console.log(JSON.stringify({
    officialBaseSHA256: actualHash,
    install: {
      status: install.status,
      stdout: String(install.stdout ?? '').trim(),
      stderr: String(install.stderr ?? '').trim()
    },
    resolvedAfterInstall: query,
    start,
    pid: pid.stdout || null
  }, null, 2));
  if (install.status !== 0) die('reinstalling the exact Google Play APK onto the high-end clone failed');
  if (!pid.stdout) die('TFT still did not stay running after PackageManager refresh');
}

async function inspectHighEndPackageState() {
  await ensureCoreSDK();
  const runPerf = args => {
    const executable = join(SDK, 'platform-tools', 'adb');
    const result = spawnSync(executable, ['-P', ADB_PORT, '-s', PERFORMANCE_SERIAL, ...args], {
      encoding: 'utf8',
      env: { ...process.env, ANDROID_ADB_SERVER_PORT: ADB_PORT, ADB_MDNS_AUTO_CONNECT: '' },
      maxBuffer: 32 * 1024 * 1024
    });
    return { status: result.status, stdout: String(result.stdout ?? '').trim(), stderr: String(result.stderr ?? '').trim() };
  };
  const dump = runPerf(['shell', 'dumpsys', 'package', PACKAGE]);
  const lines = dump.stdout.split('\n');
  const userIndex = lines.findIndex(line => line.includes('User 0:'));
  const userState = userIndex >= 0 ? lines.slice(userIndex, userIndex + 80) : [];
  const activityIndex = lines.findIndex(line => line.includes(`${PACKAGE}/com.riotgames.leagueoflegends.RiotNativeActivity`));
  const activityContext = activityIndex >= 0 ? lines.slice(Math.max(0, activityIndex - 10), activityIndex + 30) : [];
  const disabledPackages = runPerf(['shell', 'pm', 'list', 'packages', '-d']);
  const enabledPackages = runPerf(['shell', 'pm', 'list', 'packages', '-e']);
  const queryMain = runPerf(['shell', 'cmd', 'package', 'query-activities', '--brief', '-a', 'android.intent.action.MAIN', '-c', 'android.intent.category.LAUNCHER', PACKAGE]);
  const resolveDefault = runPerf(['shell', 'cmd', 'package', 'resolve-activity', '--brief', PACKAGE]);
  const result = {
    packageDisabled: disabledPackages.stdout.includes(`package:${PACKAGE}`),
    packageEnabled: enabledPackages.stdout.includes(`package:${PACKAGE}`),
    queryMain,
    resolveDefault,
    userState,
    activityContext
  };
  console.log(JSON.stringify(result, null, 2));
}

async function diagnoseHighEndLaunch() {
  await ensureCoreSDK();
  const perfRun = args => {
    const executable = join(SDK, 'platform-tools', 'adb');
    const result = spawnSync(executable, ['-P', ADB_PORT, '-s', PERFORMANCE_SERIAL, ...args], {
      encoding: 'utf8',
      env: { ...process.env, ANDROID_ADB_SERVER_PORT: ADB_PORT, ADB_MDNS_AUTO_CONNECT: '' },
      maxBuffer: 32 * 1024 * 1024
    });
    return {
      status: result.status,
      stdout: String(result.stdout ?? '').trim(),
      stderr: String(result.stderr ?? '').trim()
    };
  };
  const packageDump = perfRun(['shell', 'dumpsys', 'package', PACKAGE]);
  const activities = packageDump.stdout.split('\n').filter(line =>
    /RiotNativeActivity|SplashActivity|MAIN|LAUNCHER|activity|enabled=|stopped=/i.test(line)
  ).slice(0, 500);
  const explicit = perfRun(['shell', 'am', 'start', '-W', '-n', `${PACKAGE}/com.riotgames.leagueoflegends.RiotNativeActivity`]);
  const monkey = perfRun(['shell', 'monkey', '-p', PACKAGE, '-c', 'android.intent.category.LAUNCHER', '1']);
  await new Promise(resolveWait => setTimeout(resolveWait, 2000));
  const pid = perfRun(['shell', 'pidof', PACKAGE]);
  const top = perfRun(['shell', 'dumpsys', 'activity', 'activities']);
  const log = perfRun(['logcat', '-d', '-t', '700']);
  const relevantLog = log.stdout.split('\n').filter(line =>
    /teamfighttactics|RiotNativeActivity|leagueoflegends|ActivityTaskManager|PackageManager|Permission Denial|SecurityException|FATAL EXCEPTION|AndroidRuntime|Unable to start|class.*not found/i.test(line)
  ).slice(-300);
  const result = {
    explicitStart: explicit,
    monkeyStart: monkey,
    pid: pid.stdout || null,
    topActivities: top.stdout.split('\n').filter(line => /topResumedActivity|mResumedActivity|teamfighttactics/i.test(line)).slice(0, 100),
    packageActivityEvidence: activities,
    relevantLog
  };
  console.log(JSON.stringify(result, null, 2));
}

async function inspectHighEndTablet() {
  await ensureCoreSDK();
  const perfADB = args => {
    const executable = join(SDK, 'platform-tools', 'adb');
    const result = spawnSync(executable, ['-P', ADB_PORT, '-s', PERFORMANCE_SERIAL, ...args], {
      encoding: 'utf8',
      env: { ...process.env, ANDROID_ADB_SERVER_PORT: ADB_PORT, ADB_MDNS_AUTO_CONNECT: '' },
      maxBuffer: 32 * 1024 * 1024
    });
    return {
      ok: result.status === 0,
      status: result.status,
      stdout: String(result.stdout ?? '').trim(),
      stderr: String(result.stderr ?? '').trim()
    };
  };
  const state = perfADB(['get-state']);
  const boot = perfADB(['shell', 'getprop', 'sys.boot_completed']);
  const packagePath = perfADB(['shell', 'pm', 'path', PACKAGE]);
  const resolve = perfADB(['shell', 'cmd', 'package', 'resolve-activity', '--brief', '-a', 'android.intent.action.MAIN', '-c', 'android.intent.category.LAUNCHER', PACKAGE]);
  const pid = perfADB(['shell', 'pidof', PACKAGE]);
  const activity = perfADB(['shell', 'dumpsys', 'activity', 'activities']);
  const packageDump = perfADB(['shell', 'dumpsys', 'package', PACKAGE]);
  const gles = perfADB(['shell', 'getprop', 'ro.opengles.version']);
  const bootGles = perfADB(['shell', 'getprop', 'ro.boot.opengles.version']);
  const vulkan = perfADB(['shell', 'getprop', 'ro.hardware.vulkan']);
  const angle = perfADB(['shell', 'getprop', 'ro.hardware.egl']);
  const size = perfADB(['shell', 'wm', 'size']);
  const density = perfADB(['shell', 'wm', 'density']);
  const display = perfADB(['shell', 'dumpsys', 'display']);
  const crash = perfADB(['logcat', '-d', '-t', '1200']);
  const filteredLog = crash.stdout.split('\n').filter(line =>
    /teamfighttactics|RiotNativeActivity|leagueoflegends|FATAL EXCEPTION|AndroidRuntime|SIG(SEGV|ABRT)|crash|vulkan|angle|egl|gles|linker/i.test(line)
  ).slice(-400);
  const topActivities = activity.stdout.split('\n').filter(line =>
    /topResumedActivity|mResumedActivity|teamfighttactics|AccountPicker|SignInHub/i.test(line)
  ).slice(0, 200);
  const result = {
    ok: state.ok && state.stdout === 'device' && boot.stdout.replace(/\r/g, '') === '1',
    state,
    boot: boot.stdout,
    packageInstalled: packagePath.ok && packagePath.stdout.includes('package:'),
    packagePath: packagePath.stdout,
    resolvedActivity: resolve.stdout,
    pid: pid.stdout || null,
    openGLESVersion: gles.stdout,
    bootOpenGLESVersion: bootGles.stdout,
    vulkanHardware: vulkan.stdout,
    eglHardware: angle.stdout,
    displaySize: size.stdout,
    displayDensity: density.stdout,
    displayTabletEvidence: display.stdout.split('\n').filter(line => /smallest|density|DisplayDeviceInfo|1920|1080/i.test(line)).slice(0, 100),
    topActivities,
    packageEnabledState: packageDump.stdout.split('\n').filter(line => /User 0:|enabled=|stopped=|hidden=|suspended=/i.test(line)).slice(0, 50),
    filteredLog
  };
  await writeFile(join(LIVE_ROOT, 'high-end-tablet-inspection.json'), `${JSON.stringify(result, null, 2)}\n`);
  console.log(JSON.stringify(result, null, 2));
}

async function inspectPostPatch() {
  await mkdir(ACQ, { recursive: true });
  await ensureCoreSDK();
  await ensurePlayImage();
  await ensureAcquisitionAVD();
  const adbExe = join(SDK, 'platform-tools', 'adb');
  run(adbExe, ['-P', ADB_PORT, 'start-server'], { env: { ...process.env, ANDROID_ADB_SERVER_PORT: ADB_PORT, ADB_MDNS_AUTO_CONNECT: '' } });
  if (!adbMaybe(['get-state'])) die('Google Play TFT device is not running; launch TFT before post-patch inspection');
  const pid = adbMaybe(['shell', 'pidof', PACKAGE]) ?? '';
  const activity = adbMaybe(['shell', 'dumpsys', 'activity', 'activities']) ?? '';
  const packageDump = adbMaybe(['shell', 'dumpsys', 'package', PACKAGE]) ?? '';
  const layers = adbMaybe(['shell', 'dumpsys', 'SurfaceFlinger', '--list']) ?? '';
  const gl = adbMaybe(['shell', 'getprop']) ?? '';
  const storageCandidates = [];
  for (const root of [
    `/sdcard/Android/data/${PACKAGE}`,
    `/storage/emulated/0/Android/data/${PACKAGE}`,
    `/sdcard/Android/obb/${PACKAGE}`,
    `/storage/emulated/0/Android/obb/${PACKAGE}`
  ]) {
    const listing = adbMaybe(['shell', 'find', root, '-maxdepth', '6', '-type', 'f']) ?? '';
    const matches = listing.split('\n').filter(Boolean).filter(name => /(?:unreal|\.pak$|\.ucas$|\.utoc$|deviceprofile|engine\.ini|rhi|vulkan|shader|patch)/i.test(name));
    if (matches.length) storageCandidates.push({ root, matches: matches.slice(0, 300) });
  }
  const maps = pid ? (adbMaybe(['shell', 'cat', `/proc/${pid.split(/\s+/)[0]}/maps`]) ?? '') : '';
  const mappedLibraries = maps.split('\n')
    .map(line => line.trim().split(/\s+/).pop())
    .filter(Boolean)
    .filter(path => /(?:unreal|leagueoflegends|riot|vulkan|angle|gles|egl|shader)/i.test(path));
  const topActivity = activity.split('\n').find(line => line.includes('topResumedActivity=ActivityRecord'))?.trim() ?? null;
  const gameLayers = layers.split('\n').filter(line => /teamfighttactics|unreal|surfaceview/i.test(line)).slice(0, 100);
  const graphicsProperties = gl.split('\n').filter(line => /(?:egl|gles|vulkan|angle|gpu)/i.test(line)).slice(0, 200);
  const result = {
    observedAt: new Date().toISOString(),
    packageName: PACKAGE,
    pid: pid || null,
    topActivity,
    versionName: packageDump.match(/versionName=([^\s]+)/)?.[1] ?? null,
    versionCode: packageDump.match(/versionCode=(\d+)/)?.[1] ?? null,
    unrealEvidence: mappedLibraries.some(path => /unreal/i.test(path)) || storageCandidates.some(entry => entry.matches.some(path => /unreal|\.pak$|\.ucas$|\.utoc$/i.test(path))),
    mappedLibraries: [...new Set(mappedLibraries)].slice(0, 300),
    gameLayers,
    graphicsProperties,
    storageCandidates
  };
  await writeFile(join(LIVE_ROOT, 'post-patch-inspection.json'), `${JSON.stringify(result, null, 2)}\n`);
  console.log(JSON.stringify(result, null, 2));
}

async function inspectLive() {
  if (!existsSync(LIVE_MANIFEST)) die('live TFT has not been acquired yet');
  const manifest = JSON.parse(await readFile(LIVE_MANIFEST, 'utf8'));
  if (manifest.packageName !== PACKAGE || !Array.isArray(manifest.apks) || manifest.apks.length < 1 || manifest.apks[0].name !== 'base.apk') die('live manifest identity is invalid');
  for (const apk of manifest.apks) {
    const path = join(LIVE_CURRENT, apk.name);
    if (!existsSync(path)) die(`missing live split ${apk.name}`);
    const info = await stat(path);
    const sha = await hashFile(path);
    if (info.size !== apk.size || sha !== apk.sha256) die(`chain-of-custody mismatch for ${apk.name}`);
  }
  const engineEvidence = [];
  for (const apk of manifest.apks) {
    const listing = run('/usr/bin/unzip', ['-l', join(LIVE_CURRENT, apk.name)], { capture: true });
    const names = listing
      .split('\n')
      .map(line => line.trim().split(/\s+/).pop())
      .filter(Boolean);
    const candidates = names.filter(name => /(?:libUnreal|libUE4|libmain|libGame|libRiot|libunity|libil2cpp|libmono|UECommandLine|DefaultEngine|DeviceProfiles|\.uproject)/i.test(name));
    const nativeLibraries = names.filter(name => /^lib\/arm64-v8a\/[^/]+\.so$/i.test(name));
    if (candidates.length || nativeLibraries.length) engineEvidence.push({
      apk: apk.name,
      candidates: [...new Set(candidates)].slice(0, 200),
      nativeLibraries: [...new Set(nativeLibraries)].slice(0, 300)
    });
  }
  console.log(JSON.stringify({
    ok: true,
    packageName: manifest.packageName,
    version: manifest.version,
    versionCode: manifest.versionCode,
    launchActivity: manifest.launchActivity ?? null,
    donorUECommandLineCompatible: manifest.donorUECommandLineCompatible === true,
    splits: manifest.apks.length,
    baseSHA256: manifest.baseSHA256,
    engineEvidence
  }, null, 2));
}

function runZsh(script, env = {}) {
  run('/bin/zsh', [script], { env: { ...process.env, ...env } });
}

async function playStock() {
  await mkdir(ACQ, { recursive: true });
  await ensureCoreSDK();
  await ensurePlayImage();
  await ensureAcquisitionAVD();
  const adbExe = join(SDK, 'platform-tools', 'adb');
  run(adbExe, ['-P', ADB_PORT, 'start-server'], { env: { ...process.env, ANDROID_ADB_SERVER_PORT: ADB_PORT, ADB_MDNS_AUTO_CONNECT: '' } });
  if (!adbMaybe(['get-state'])) {
    const emulatorExe = join(SDK, 'emulator', 'emulator');
    const child = spawn(emulatorExe, [`@${AVD_NAME}`, '-id', 'TFTMAC-Live', '-port', '5590', '-gpu', 'host', '-skin', '1920x1080', '-cores', '6', '-memory', '6144', '-no-snapshot', '-no-metrics', '-no-boot-anim', '-crash-report-mode', 'disabled'], {
      cwd: ROOT,
      env: { ...process.env, ANDROID_SDK_ROOT: SDK, ANDROID_AVD_HOME: AVD_HOME, ANDROID_ADB_SERVER_PORT: ADB_PORT, ADB_MDNS_AUTO_CONNECT: '' },
      detached: true,
      stdio: 'ignore'
    });
    child.unref();
  }
  await waitUntil('live TFT emulator ADB', 240, () => adbMaybe(['get-state']) === 'device');
  await waitUntil('Android boot', 240, () => adbMaybe(['shell', 'getprop', 'sys.boot_completed'])?.replace(/\r/g, '') === '1');
  const installed = adbMaybe(['shell', 'pm', 'path', PACKAGE]);
  if (!installed) die('live TFT is no longer installed in the Google Play device');
  const manifest = existsSync(LIVE_MANIFEST) ? JSON.parse(await readFile(LIVE_MANIFEST, 'utf8')) : null;
  const component = manifest?.launchActivity || `${PACKAGE}/com.riotgames.leagueoflegends.RiotNativeActivity`;
  adb(['shell', 'am', 'force-stop', PACKAGE], false);
  adb(['shell', 'am', 'start', '-n', component], false);
  const pid = await waitUntil('live TFT process', 120, () => adbMaybe(['shell', 'pidof', PACKAGE]));
  console.log(`TFTMAC_STOCK_LAUNCHED pid=${pid} component=${component}`);
  console.log('TFTMAC: Riot live TFT is running in the Google Play device.');
}

function loggedInUserHome() {
  const user = run('/usr/bin/id', ['-un'], { capture: true });
  const record = run('/usr/bin/dscl', ['.', '-read', `/Users/${user}`, 'NFSHomeDirectory'], { capture: true });
  const marker = 'NFSHomeDirectory:';
  if (!record.startsWith(marker)) die(`could not resolve home directory for ${user}`);
  return record.slice(marker.length).trim();
}

async function installStableRuntime() {
  const home = loggedInUserHome();
  const stable = join(home, 'Library', 'Application Support', 'TFTMAC');
  const stableNext = `${stable}.next`;
  const adbExe = join(SDK, 'platform-tools', 'adb');
  const adbState = serial => {
    const result = spawnSync(adbExe, ['-P', ADB_PORT, '-s', serial, 'get-state'], {
      encoding: 'utf8',
      env: { ...process.env, ANDROID_ADB_SERVER_PORT: ADB_PORT, ADB_MDNS_AUTO_CONNECT: '' }
    });
    return result.status === 0 ? String(result.stdout ?? '').trim() : null;
  };
  const killDevice = serial => {
    spawnSync(adbExe, ['-P', ADB_PORT, '-s', serial, 'emu', 'kill'], {
      encoding: 'utf8',
      env: { ...process.env, ANDROID_ADB_SERVER_PORT: ADB_PORT, ADB_MDNS_AUTO_CONNECT: '' }
    });
  };
  killDevice(SERIAL);
  killDevice(PERFORMANCE_SERIAL);
  const deadline = Date.now() + 60000;
  while (Date.now() < deadline && (adbState(SERIAL) || adbState(PERFORMANCE_SERIAL))) {
    await new Promise(resolveWait => setTimeout(resolveWait, 500));
  }
  if (adbState(SERIAL) || adbState(PERFORMANCE_SERIAL)) {
    die('Android devices did not shut down cleanly before runtime migration');
  }
  await rm(stableNext, { recursive: true, force: true });
  await mkdir(stableNext, { recursive: true });
  run('/bin/cp', ['-R', join(ACQ, 'sdk'), join(stableNext, 'sdk')]);
  run('/bin/cp', ['-R', join(ACQ, 'avd'), join(stableNext, 'avd')]);
  for (const avdName of [AVD_NAME, PERFORMANCE_AVD_NAME]) {
    const ini = join(stableNext, 'avd', `${avdName}.ini`);
    if (!existsSync(ini)) continue;
    const finalAVD = join(stable, 'avd', `${avdName}.avd`);
    await writeFile(ini, `avd.ini.encoding=UTF-8\npath=${finalAVD}\npath.rel=${avdName}.avd\ntarget=android-36\n`);
  }
  await writeFile(join(stableNext, 'runtime.json'), `${JSON.stringify({
    schemaVersion: 1,
    packageName: PACKAGE,
    launchActivity: `${PACKAGE}/com.riotgames.leagueoflegends.RiotNativeActivity`,
    acquiredVersion: existsSync(LIVE_MANIFEST) ? JSON.parse(await readFile(LIVE_MANIFEST, 'utf8')).version : null,
    source: 'Google Play',
    defaultAVD: PERFORMANCE_AVD_NAME,
    renderTarget: '1920x1080',
    densityDpi: 280,
    cpuCores: 8,
    ramMB: 8192,
    enhancedOpenGLESVersion: 196610,
    installedAt: new Date().toISOString()
  }, null, 2)}\n`);
  const backup = `${stable}.previous`;
  await rm(backup, { recursive: true, force: true });
  if (existsSync(stable)) await rename(stable, backup);
  await rename(stableNext, stable);
  await rm(backup, { recursive: true, force: true });
  console.log(`TFTMAC_RUNTIME_INSTALLED ${stable}`);
}

async function testAll() {
  runZsh(join(ROOT, 'scripts', 'test-mactician.command'));
  const source = join(ROOT, 'tftmac', 'Sources', 'TFTMACApp.swift');
  run('/usr/bin/xcrun', ['swiftc', '-parse-as-library', '-typecheck', '-target', 'arm64-apple-macosx12.0', source]);
  const shellSource = await readFile(source, 'utf8');
  if (!shellSource.includes('"1920x1080"') || !shellSource.includes('androidboot.opengles.version=196610')) {
    die('TFTMAC Enhanced 1080p graphics contract is missing');
  }
  const graphicsContract = await readFile(join(ROOT, 'docs', 'TFTMAC_GRAPHICS_ARCHITECTURE.md'), 'utf8');
  if (!graphicsContract.includes('Primary target') || !graphicsContract.includes('617dp tablet class') || !graphicsContract.includes('UnrealEnhancedAdapter')) {
    die('TFTMAC graphics architecture contract is incomplete');
  }
  console.log('TFTMAC_TESTS_OK donor=green native_shell=green graphics_contract=green');
}

async function build() {
  await inspectLive();
  const source = join(ROOT, 'tftmac', 'Sources', 'TFTMACApp.swift');
  const plist = join(ROOT, 'tftmac', 'Info.plist');
  const dist = join(ROOT, 'dist');
  const app = join(dist, 'TFTMAC.app');
  const contents = join(app, 'Contents');
  const macOS = join(contents, 'MacOS');
  const version = run('/usr/libexec/PlistBuddy', ['-c', 'Print :CFBundleShortVersionString', plist], { capture: true });
  const dmg = join(dist, `TFTMAC-${version}.dmg`);
  await rm(app, { recursive: true, force: true });
  await rm(dmg, { force: true });
  await mkdir(macOS, { recursive: true });
  await copyFile(plist, join(contents, 'Info.plist'));
  run('/usr/bin/xcrun', ['swiftc', '-O', '-parse-as-library', '-target', 'arm64-apple-macosx12.0', source, '-o', join(macOS, 'TFTMAC')]);
  run('/usr/bin/codesign', ['--force', '--sign', '-', '--timestamp=none', '--options', 'runtime', app]);
  run('/usr/bin/codesign', ['--verify', '--deep', '--strict', '--verbose=2', app]);
  const dmgRoot = join(dist, '.tftmac-dmg-root');
  await rm(dmgRoot, { recursive: true, force: true });
  await mkdir(dmgRoot, { recursive: true });
  run('/bin/cp', ['-R', app, join(dmgRoot, 'TFTMAC.app')]);
  run('/bin/ln', ['-s', '/Applications', join(dmgRoot, 'Applications')]);
  run('/usr/bin/hdiutil', ['create', '-size', '32m', '-fs', 'HFS+', '-volname', 'TFTMAC', '-srcfolder', dmgRoot, '-ov', '-format', 'UDZO', dmg]);
  await rm(dmgRoot, { recursive: true, force: true });
  console.log(`TFTMAC_BUILT app=${app}`);
  console.log(`TFTMAC_DMG ${dmg}`);
}

async function acceptance() {
  const app = join(ROOT, 'dist', 'TFTMAC.app');
  const version = run('/usr/libexec/PlistBuddy', ['-c', 'Print :CFBundleShortVersionString', join(ROOT, 'tftmac', 'Info.plist')], { capture: true });
  const dmg = join(ROOT, 'dist', `TFTMAC-${version}.dmg`);
  if (!existsSync(app) || !existsSync(dmg)) die('TFTMAC app/DMG build outputs are missing');
  run('/usr/bin/codesign', ['--verify', '--deep', '--strict', '--verbose=2', app]);
  const identifier = run('/usr/libexec/PlistBuddy', ['-c', 'Print :CFBundleIdentifier', join(app, 'Contents', 'Info.plist')], { capture: true });
  const displayName = run('/usr/libexec/PlistBuddy', ['-c', 'Print :CFBundleDisplayName', join(app, 'Contents', 'Info.plist')], { capture: true });
  if (identifier !== 'com.flashls1.tftmac' || displayName !== 'TFTMAC') die(`unexpected built identity: ${identifier} / ${displayName}`);
  await installStableRuntime();
  const installedApp = '/Applications/TFTMAC.app';
  await rm(installedApp, { recursive: true, force: true });
  run('/bin/cp', ['-R', app, installedApp]);
  run('/usr/bin/codesign', ['--verify', '--deep', '--strict', '--verbose=2', installedApp]);
  run('/usr/bin/open', ['-n', installedApp]);
  const home = loggedInUserHome();
  const stable = join(home, 'Library', 'Application Support', 'TFTMAC');
  const stableADB = join(stable, 'sdk', 'platform-tools', 'adb');
  const stableRun = args => {
    const result = spawnSync(stableADB, ['-P', ADB_PORT, '-s', PERFORMANCE_SERIAL, ...args], {
      encoding: 'utf8',
      env: { ...process.env, ANDROID_ADB_SERVER_PORT: ADB_PORT, ADB_MDNS_AUTO_CONNECT: '' },
      maxBuffer: 16 * 1024 * 1024
    });
    return result.status === 0 ? String(result.stdout ?? '').trim() : null;
  };
  await waitUntil('installed TFTMAC high-end tablet ADB', 240, () => stableRun(['get-state']) === 'device');
  await waitUntil('installed TFTMAC Android boot', 240, () => stableRun(['shell', 'getprop', 'sys.boot_completed'])?.replace(/\r/g, '') === '1');
  const pid = await waitUntil('installed TFTMAC Riot process', 120, () => stableRun(['shell', 'pidof', PACKAGE]));
  const gles = stableRun(['shell', 'getprop', 'ro.opengles.version']);
  const egl = stableRun(['shell', 'getprop', 'ro.hardware.egl']);
  const size = stableRun(['shell', 'wm', 'size']);
  const density = stableRun(['shell', 'wm', 'density']);
  const resolved = stableRun(['shell', 'cmd', 'package', 'resolve-activity', '--brief', '-a', 'android.intent.action.MAIN', '-c', 'android.intent.category.LAUNCHER', PACKAGE]);
  if (gles !== '196610' || egl !== 'angle' || !size?.includes('1920x1080') || !density?.includes('280') || !resolved?.includes(EXPECTED_ACTIVITY)) {
    die(`installed TFTMAC runtime did not match enhanced 1080p contract: gles=${gles} egl=${egl} size=${size} density=${density} activity=${resolved}`);
  }
  console.log(`TFTMAC_ACCEPTED app=${installedApp} pid=${pid} gles=${gles} egl=${egl} size=${size} density=${density}`);
}

const action = process.argv[2];
switch (action) {
  case 'test': await testAll(); break;
  case 'acquire-live': await acquireLive(); break;
  case 'inspect-live': await inspectLive(); break;
  case 'inspect-post-patch': await inspectPostPatch(); break;
  case 'stop-acquisition': await stopAcquisition(); break;
  case 'prepare-high-end-tablet': await prepareHighEndTablet(); break;
  case 'play-high-end-tablet': await playHighEndTablet(); break;
  case 'inspect-high-end-tablet': await inspectHighEndTablet(); break;
  case 'diagnose-high-end-launch': await diagnoseHighEndLaunch(); break;
  case 'inspect-high-end-package-state': await inspectHighEndPackageState(); break;
  case 'repair-high-end-launch-state': await repairHighEndLaunchState(); break;
  case 'reinstall-high-end-official-apk': await reinstallHighEndFromOfficialApk(); break;
  case 'play-stock': await playStock(); break;
  case 'build': await build(); break;
  case 'acceptance': await acceptance(); break;
  default: die('usage: node tools/clara-task.mjs test|acquire-live|inspect-live|inspect-post-patch|stop-acquisition|prepare-high-end-tablet|play-high-end-tablet|inspect-high-end-tablet|diagnose-high-end-launch|inspect-high-end-package-state|repair-high-end-launch-state|reinstall-high-end-official-apk|play-stock|build|acceptance');
}
