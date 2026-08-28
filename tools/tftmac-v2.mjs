#!/usr/bin/env node
import { createHash } from 'node:crypto';
import { createReadStream, existsSync } from 'node:fs';
import { chmod, copyFile, mkdir, readFile, rename, rm, stat, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { homedir } from 'node:os';
import { spawnSync } from 'node:child_process';

function resolveConsoleUserHome() {
  const userResult = spawnSync('/usr/bin/stat', ['-f', '%Su', '/dev/console'], { encoding: 'utf8' });
  const user = String(userResult.stdout ?? '').trim();
  if (user && user !== 'root' && user !== 'loginwindow') {
    const homeResult = spawnSync('/usr/bin/dscl', ['.', '-read', `/Users/${user}`, 'NFSHomeDirectory'], { encoding: 'utf8' });
    const match = String(homeResult.stdout ?? '').match(/NFSHomeDirectory:\s+(.+)/);
    if (match?.[1]) return match[1].trim();
  }
  return homedir();
}

const REPO = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const USER_HOME = resolveConsoleUserHome();
const SANDBOX_HOME = homedir();
const APP = join(USER_HOME, 'Library', 'Application Support', 'TFTMAC');
const DEFAULT_BUILD_VOLUME = '/Volumes/MAC MINI M4';
const DEFAULT_BUILD_ROOT = join(DEFAULT_BUILD_VOLUME, 'TFTMAC', 'Build');
const BUILD = resolve(process.env.TFTMAC_BUILD_ROOT ?? DEFAULT_BUILD_ROOT);
const RUNTIME = join(APP, 'Runtime');
const SDK = join(RUNTIME, 'SDK');
const AVD_HOME = join(RUNTIME, 'AVD');
const PACKAGES = join(RUNTIME, 'Packages');
const PROBES = join(RUNTIME, 'Probes');
const MANIFESTS = join(RUNTIME, 'Manifests');
const LOGS = join(APP, 'Logs');
const DIAGNOSTICS = join(APP, 'Diagnostics');
const ROLLBACK = join(APP, 'Rollback');
const SSOT = join(REPO, 'ssot');

const EXPECTED = Object.freeze({
  architecture: 'arm64',
  xcodeVersion: '26.6',
  xcodeBuild: '17F113',
  commandLineToolsArchive: 'commandlinetools-mac_arm64-15859902_latest.zip',
  commandLineToolsURL: 'https://dl.google.com/android/repository/commandlinetools-mac_arm64-15859902_latest.zip',
  commandLineToolsSHA256: '835b62a26162b229b441d1f6d4680383815a270809eb33522c0d480fa5002c4e',
  androidPackages: [
    'platform-tools',
    'emulator',
    'platforms;android-37',
    'build-tools;37.0.0',
    'system-images;android-37.0;google_apis_playstore_ps16k;arm64-v8a'
  ],
  playImagePackage: 'system-images;android-37.0;google_apis_playstore_ps16k;arm64-v8a',
  minimumPlayImageRevision: 5,
  avdName: 'TFTMAC_Live_API37',
  aemuBranch: 'emu-master-dev',
  vulkanSDKVersion: '1.4.357.0',
  vulkanSDKSHA256: '539433589c83522e6f31b1c7b418a4167e21597a4a361ab119e1dc0760cf3865',
  moltenVKReferenceTag: 'v1.4.2',
  glesCTSTag: 'opengl-es-cts-3.2.14.1',
  vulkanCTSTag: 'vulkan-cts-1.4.6.1',
  vulkanCTSCommit: '5c8aae22885448d70a2873e94a93b24b49505c32',
  vulkanSamplesCommit: '89dd3af22d41f9244eeab6e0650460112285c0e1'
});

function die(message, code = 1) {
  console.error(`TFTMAC_V2: ${message}`);
  process.exit(code);
}

function run(executable, args = [], options = {}) {
  const result = spawnSync(executable, args, {
    cwd: options.cwd ?? REPO,
    env: options.env ?? process.env,
    encoding: 'utf8',
    input: options.input,
    maxBuffer: options.maxBuffer ?? 64 * 1024 * 1024,
    stdio: ['pipe', 'pipe', 'pipe']
  });
  if (result.error) {
    throw new Error(`${executable} failed to start: ${result.error.message}`);
  }
  const stdout = String(result.stdout ?? '');
  const stderr = String(result.stderr ?? '');
  if (result.status !== 0 && !options.allowFailure) {
    const detail = [stdout.trim(), stderr.trim()].filter(Boolean).join('\n');
    throw new Error(`${executable} ${args.join(' ')} exited ${result.status}${detail ? `\n${detail}` : ''}`);
  }
  return { status: result.status ?? 1, stdout, stderr };
}

function firstExisting(paths) {
  return paths.find(path => path && existsSync(path)) ?? null;
}

async function sha256(path) {
  return new Promise((resolveHash, reject) => {
    const hash = createHash('sha256');
    const stream = createReadStream(path);
    stream.on('error', reject);
    stream.on('data', chunk => hash.update(chunk));
    stream.on('end', () => resolveHash(hash.digest('hex')));
  });
}

async function atomicWrite(path, content) {
  await mkdir(dirname(path), { recursive: true });
  const temp = `${path}.tmp-${process.pid}`;
  await writeFile(temp, content);
  await rename(temp, path);
}

async function ensureRoots() {
  if (!process.env.TFTMAC_BUILD_ROOT && !existsSync(DEFAULT_BUILD_VOLUME)) {
    die(`TFTMAC_BUILD_VOLUME_REQUIRED: ${DEFAULT_BUILD_VOLUME} is not mounted; refusing to fall back to the internal disk.`, 17);
  }
  for (const path of [BUILD, SDK, AVD_HOME, PACKAGES, PROBES, MANIFESTS, LOGS, DIAGNOSTICS, ROLLBACK, SSOT]) {
    await mkdir(path, { recursive: true });
  }
}

function parseXcode(text) {
  const version = text.match(/^Xcode\s+([^\s]+)/m)?.[1] ?? null;
  const build = text.match(/^Build version\s+([^\s]+)/m)?.[1] ?? null;
  return { version, build };
}

function discoverInstalledXcodes() {
  const applications = '/Applications';
  const listing = run('/bin/ls', ['-1', applications], { allowFailure: true }).stdout.split(/\r?\n/).filter(Boolean);
  const candidates = listing.filter(name => /^Xcode.*\.app$/i.test(name));
  const discovered = [];
  for (const name of candidates) {
    const app = join(applications, name);
    const developerDir = join(app, 'Contents', 'Developer');
    if (!existsSync(developerDir)) continue;
    const result = run('/usr/bin/xcodebuild', ['-version'], {
      env: { ...process.env, DEVELOPER_DIR: developerDir },
      allowFailure: true
    });
    discovered.push({ app, developerDir, status: result.status, version: parseXcode(result.stdout) });
  }
  return discovered;
}

function findRequiredXcode(discovered) {
  return discovered.find(item => item.status === 0 && item.version.version === EXPECTED.xcodeVersion && item.version.build === EXPECTED.xcodeBuild) ?? null;
}

function parseMacOS(text) {
  const values = {};
  for (const line of text.split(/\r?\n/)) {
    const [key, ...rest] = line.split(':');
    if (rest.length) values[key.trim()] = rest.join(':').trim();
  }
  return {
    productName: values.ProductName ?? null,
    productVersion: values.ProductVersion ?? null,
    buildVersion: values.BuildVersion ?? null
  };
}

function parseHardware(text) {
  const modelName = text.match(/^\s*Model Name:\s*(.+)$/m)?.[1]?.trim() ?? null;
  const modelIdentifier = text.match(/^\s*Model Identifier:\s*(.+)$/m)?.[1]?.trim() ?? null;
  const chip = text.match(/^\s*Chip:\s*(.+)$/m)?.[1]?.trim() ?? null;
  const memory = text.match(/^\s*Memory:\s*(.+)$/m)?.[1]?.trim() ?? null;
  return { modelName, modelIdentifier, chip, memory };
}

function parseProperties(text) {
  const result = {};
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const index = line.indexOf('=');
    if (index < 0) continue;
    result[line.slice(0, index).trim()] = line.slice(index + 1).trim();
  }
  return result;
}

function yamlScalar(value) {
  if (value === null) return 'null';
  if (typeof value === 'number' || typeof value === 'boolean') return String(value);
  return JSON.stringify(String(value));
}

function setYamlScalar(text, path, value) {
  const lines = text.split('\n');
  const stack = [];
  for (let index = 0; index < lines.length; index += 1) {
    const match = lines[index].match(/^(\s*)([A-Za-z0-9_]+):(?:\s*(.*))?$/);
    if (!match) continue;
    const indent = match[1].length;
    if (indent % 2 !== 0) continue;
    const level = indent / 2;
    stack.length = level;
    const key = match[2];
    const current = [...stack, key];
    if (current.length === path.length && current.every((part, i) => part === path[i])) {
      lines[index] = `${match[1]}${key}: ${yamlScalar(value)}`;
      return lines.join('\n');
    }
    const remainder = match[3];
    if (remainder === undefined || remainder === '') stack[level] = key;
  }
  throw new Error(`STACK.lock.yaml path not found: ${path.join('.')}`);
}

async function updateStackLock(updates) {
  const path = join(SSOT, 'STACK.lock.yaml');
  let text = await readFile(path, 'utf8');
  for (const [yamlPath, value] of updates) text = setYamlScalar(text, yamlPath, value);
  await atomicWrite(path, text);
}

function parseInstalledPackages(text) {
  const packages = new Map();
  for (const line of text.split(/\r?\n/)) {
    if (!line.includes('|')) continue;
    const columns = line.split('|').map(value => value.trim());
    if (columns.length < 2 || !columns[0] || columns[0] === 'Path' || /^-+$/.test(columns[0])) continue;
    packages.set(columns[0], columns[1]);
  }
  return packages;
}

const CRITICAL_LOCK_PATHS = Object.freeze([
  ['frozen_at'],
  ['host', 'architecture'],
  ['host', 'macos_version'],
  ['host', 'macos_build'],
  ['host', 'xcode_version'],
  ['host', 'xcode_build'],
  ['host', 'macos_sdk_path'],
  ['host', 'hardware_model'],
  ['android_command_line_tools', 'installed_revision'],
  ['android', 'play_image_revision'],
  ['android', 'platform_tools_revision'],
  ['android', 'emulator_revision'],
  ['android', 'platform_revision'],
  ['android', 'build_tools_revision'],
  ['aemu', 'resolved_manifest_sha256'],
  ['aemu', 'qemu_commit'],
  ['aemu', 'aemu_commit'],
  ['aemu', 'gfxstream_commit'],
  ['aemu', 'integrated_angle_commit'],
  ['aemu', 'integrated_moltenvk_commit'],
  ['aemu', 'guestangle_authority'],
  ['vulkan_sdk', 'vulkaninfo_version'],
  ['moltenvk', 'reference_commit'],
  ['generality', 'gles_cts_commit'],
  ['generality', 'vulkan_required_cases_sha256']
]);

function parseSimpleYamlScalars(text) {
  const scalars = new Map();
  const stack = [];
  for (const line of text.split(/\r?\n/)) {
    if (!line.trim() || line.trim().startsWith('#') || /^\s*-\s/.test(line)) continue;
    const match = line.match(/^(\s*)([A-Za-z0-9_]+):(?:\s*(.*))?$/);
    if (!match) continue;
    const indent = match[1].length;
    if (indent % 2 !== 0) continue;
    const level = indent / 2;
    stack.length = level;
    const key = match[2];
    const raw = match[3];
    const path = [...stack, key];
    if (raw === undefined || raw === '') {
      stack[level] = key;
      continue;
    }
    let value = raw.trim();
    if (value === 'null') value = null;
    else if (value === 'true') value = true;
    else if (value === 'false') value = false;
    else if (/^-?\d+(?:\.\d+)?$/.test(value)) value = Number(value);
    else if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      try { value = JSON.parse(value); } catch { value = value.slice(1, -1); }
    }
    scalars.set(path.join('.'), value);
  }
  return scalars;
}

async function phase0Host() {
  await ensureRoots();
  const arch = run('/usr/bin/uname', ['-m']).stdout.trim();
  const sw = parseMacOS(run('/usr/bin/sw_vers').stdout);
  const installedXcodes = discoverInstalledXcodes();
  const requiredXcode = findRequiredXcode(installedXcodes);
  const xcodeEnv = requiredXcode ? { ...process.env, DEVELOPER_DIR: requiredXcode.developerDir } : process.env;
  const xcodeRaw = run('/usr/bin/xcodebuild', ['-version'], { env: xcodeEnv }).stdout;
  const xcode = parseXcode(xcodeRaw);
  const sdkPath = run('/usr/bin/xcrun', ['--sdk', 'macosx', '--show-sdk-path'], { env: xcodeEnv }).stdout.trim();
  const hardwareRaw = run('/usr/sbin/system_profiler', ['SPHardwareDataType']).stdout;
  const hardware = parseHardware(hardwareRaw);

  const checks = {
    architecture: arch === EXPECTED.architecture,
    xcodeVersion: xcode.version === EXPECTED.xcodeVersion,
    xcodeBuild: xcode.build === EXPECTED.xcodeBuild,
    macosVersionPresent: Boolean(sw.productVersion),
    macosSDKPresent: Boolean(sdkPath),
    appleSiliconChip: /Apple\s+M\d|Apple Silicon/i.test(hardware.chip ?? '')
  };
  const pass = Object.values(checks).every(Boolean);
  const artifact = {
    schema: 1,
    observedAt: new Date().toISOString(),
    expected: {
      architecture: EXPECTED.architecture,
      xcodeVersion: EXPECTED.xcodeVersion,
      xcodeBuild: EXPECTED.xcodeBuild
    },
    observed: {
      architecture: arch,
      macOS: sw,
      xcode,
      selectedXcodeBundle: requiredXcode?.app ?? null,
      selectedDeveloperDir: requiredXcode?.developerDir ?? null,
      installedXcodes,
      macosSDKPath: sdkPath,
      hardware
    },
    checks,
    pass
  };
  await atomicWrite(join(SSOT, 'host-preflight.json'), `${JSON.stringify(artifact, null, 2)}\n`);
  const toolVersions = [
    `uname=${arch}`,
    `macos=${sw.productVersion ?? 'unknown'} (${sw.buildVersion ?? 'unknown'})`,
    `xcode=${xcode.version ?? 'unknown'} (${xcode.build ?? 'unknown'})`,
    `macos_sdk=${sdkPath}`,
    `node=${process.version}`,
    `git=${run('/usr/bin/git', ['--version']).stdout.trim()}`
  ];
  await atomicWrite(join(SSOT, 'tool-versions.txt'), `${toolVersions.join('\n')}\n`);
  await updateStackLock([
    [['host', 'architecture'], arch],
    [['host', 'macos_version'], sw.productVersion],
    [['host', 'macos_build'], sw.buildVersion],
    [['host', 'hardware_model'], hardware.modelIdentifier ?? hardware.modelName]
  ]);
  if (requiredXcode && checks.xcodeVersion && checks.xcodeBuild && checks.macosSDKPresent) {
    await updateStackLock([
      [['host', 'xcode_version'], xcode.version],
      [['host', 'xcode_build'], xcode.build],
      [['host', 'macos_sdk_path'], sdkPath]
    ]);
  }
  console.log(JSON.stringify({ phase: '0-host', pass, checks, observed: artifact.observed }, null, 2));
  if (!pass) die('PHASE_0_HOST_PREFLIGHT_FAILED', 2);
}

async function downloadVerified(url, destination, expectedSHA256) {
  await mkdir(dirname(destination), { recursive: true });
  if (existsSync(destination)) {
    const current = await sha256(destination);
    if (current === expectedSHA256) return;
    await rm(destination, { force: true });
  }
  const partial = `${destination}.partial`;
  run('/usr/bin/curl', ['-fL', '--retry', '3', '--retry-delay', '2', '--continue-at', '-', url, '-o', partial]);
  const actual = await sha256(partial);
  if (actual !== expectedSHA256) {
    await rm(partial, { force: true });
    throw new Error(`checksum mismatch for ${url}: expected ${expectedSHA256}, got ${actual}`);
  }
  await rename(partial, destination);
}

async function installCommandLineTools() {
  await ensureRoots();
  const archive = join(PACKAGES, EXPECTED.commandLineToolsArchive);
  await downloadVerified(EXPECTED.commandLineToolsURL, archive, EXPECTED.commandLineToolsSHA256);
  const sdkmanager = join(SDK, 'cmdline-tools', 'latest', 'bin', 'sdkmanager');
  if (!existsSync(sdkmanager)) {
    const stage = join(PACKAGES, '.cmdline-tools-stage');
    await rm(stage, { recursive: true, force: true });
    await mkdir(stage, { recursive: true });
    run('/usr/bin/unzip', ['-q', archive, '-d', stage]);
    const source = join(stage, 'cmdline-tools');
    if (!existsSync(source)) throw new Error('Android command-line tools archive has unexpected layout');
    const latest = join(SDK, 'cmdline-tools', 'latest');
    await rm(latest, { recursive: true, force: true });
    await mkdir(dirname(latest), { recursive: true });
    await rename(source, latest);
    await rm(stage, { recursive: true, force: true });
  }
  const hash = await sha256(archive);
  console.log(JSON.stringify({ archive, sha256: hash, sdkmanager }, null, 2));
}

async function seedPreviouslyAcceptedAndroidLicenses() {
  const target = join(SDK, 'licenses');
  if (existsSync(join(target, 'android-sdk-license'))) return { seeded: false, source: 'already-local' };
  const candidates = [
    process.env.ANDROID_SDK_ROOT,
    process.env.ANDROID_HOME,
    join(homedir(), 'Library', 'Android', 'sdk')
  ].filter(Boolean);
  for (const candidate of candidates) {
    const source = join(candidate, 'licenses');
    if (!existsSync(join(source, 'android-sdk-license'))) continue;
    await mkdir(target, { recursive: true });
    for (const name of ['android-sdk-license', 'android-sdk-preview-license', 'google-gdk-license']) {
      const from = join(source, name);
      if (existsSync(from)) await copyFile(from, join(target, name));
    }
    return { seeded: true, source };
  }
  return { seeded: false, source: null };
}

function androidEnv() {
  return {
    ...process.env,
    ANDROID_SDK_ROOT: SDK,
    ANDROID_HOME: SDK,
    ANDROID_AVD_HOME: AVD_HOME,
    ANDROID_ADB_SERVER_PORT: '5040',
    ADB_MDNS_AUTO_CONNECT: ''
  };
}

async function phase0Android() {
  await ensureRoots();
  await installCommandLineTools();
  const license = await seedPreviouslyAcceptedAndroidLicenses();
  const sdkmanager = join(SDK, 'cmdline-tools', 'latest', 'bin', 'sdkmanager');
  const avdmanager = join(SDK, 'cmdline-tools', 'latest', 'bin', 'avdmanager');
  if (!existsSync(join(SDK, 'licenses', 'android-sdk-license'))) {
    await atomicWrite(join(SSOT, 'android-license-status.json'), `${JSON.stringify({ acceptedLicenseEvidenceFound: false, checkedAt: new Date().toISOString() }, null, 2)}\n`);
    die('ANDROID_LICENSE_ACCEPTANCE_REQUIRED: no previously accepted Android SDK license evidence was found; no license was accepted automatically.', 3);
  }
  run(sdkmanager, [`--sdk_root=${SDK}`, '--install', ...EXPECTED.androidPackages], { env: androidEnv(), maxBuffer: 128 * 1024 * 1024 });
  const installed = run(sdkmanager, [`--sdk_root=${SDK}`, '--list_installed'], { env: androidEnv(), maxBuffer: 128 * 1024 * 1024 }).stdout;
  await atomicWrite(join(SSOT, 'android-sdk-packages.txt'), installed);
  const packages = parseInstalledPackages(installed);
  const requiredVersions = Object.fromEntries(EXPECTED.androidPackages.map(path => [path, packages.get(path) ?? null]));
  const missingPackages = Object.entries(requiredVersions).filter(([, version]) => !version).map(([path]) => path);
  if (missingPackages.length) throw new Error(`required Android packages missing after install: ${missingPackages.join(', ')}`);
  const playRevision = Number.parseInt(requiredVersions[EXPECTED.playImagePackage], 10);
  if (!Number.isFinite(playRevision) || playRevision < EXPECTED.minimumPlayImageRevision) {
    throw new Error(`Android Play image revision ${requiredVersions[EXPECTED.playImagePackage]} is below required ${EXPECTED.minimumPlayImageRevision}`);
  }
  const cmdlinePropertiesPath = join(SDK, 'cmdline-tools', 'latest', 'source.properties');
  const cmdlineRevision = existsSync(cmdlinePropertiesPath) ? parseProperties(await readFile(cmdlinePropertiesPath, 'utf8'))['Pkg.Revision'] ?? null : null;
  if (!cmdlineRevision) throw new Error('could not resolve installed Android command-line tools revision');

  const ini = join(AVD_HOME, `${EXPECTED.avdName}.ini`);
  const configPath = join(AVD_HOME, `${EXPECTED.avdName}.avd`, 'config.ini');
  if (!existsSync(configPath) || !existsSync(ini)) {
    run(avdmanager, [
      'create', 'avd', '--name', EXPECTED.avdName,
      '--package', EXPECTED.playImagePackage,
      '--device', 'pixel_tablet', '--force'
    ], { env: androidEnv(), input: 'no\n' });
  }
  let config = existsSync(configPath) ? await readFile(configPath, 'utf8') : '';
  const values = {
    AvdId: EXPECTED.avdName,
    'avd.ini.displayname': 'TFTMAC Live',
    'hw.device.manufacturer': 'Google',
    'hw.device.name': 'pixel_tablet',
    'hw.initialOrientation': 'Landscape',
    'hw.cpu.arch': 'arm64',
    'hw.cpu.ncore': '8',
    'hw.ramSize': '8192',
    'hw.vmHeapSize': '768',
    'hw.lcd.width': '1920',
    'hw.lcd.height': '1080',
    'hw.lcd.density': '280',
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
  for (const [key, value] of Object.entries(values)) {
    const escaped = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const pattern = new RegExp(`^${escaped}=.*$`, 'm');
    config = pattern.test(config) ? config.replace(pattern, `${key}=${value}`) : `${config.replace(/\s*$/, '')}\n${key}=${value}\n`;
  }
  await atomicWrite(configPath, config);
  await atomicWrite(join(SSOT, 'android-license-status.json'), `${JSON.stringify({ acceptedLicenseEvidenceFound: true, seededFrom: license.source, checkedAt: new Date().toISOString() }, null, 2)}\n`);
  await updateStackLock([
    [['android_command_line_tools', 'installed_revision'], cmdlineRevision],
    [['android', 'play_image_revision'], playRevision],
    [['android', 'platform_tools_revision'], requiredVersions['platform-tools']],
    [['android', 'emulator_revision'], requiredVersions['emulator']],
    [['android', 'platform_revision'], requiredVersions['platforms;android-37']],
    [['android', 'build_tools_revision'], requiredVersions['build-tools;37.0.0']]
  ]);
  console.log(JSON.stringify({ phase: '0-android', pass: true, license, avd: EXPECTED.avdName, sdk: SDK, commandLineToolsRevision: cmdlineRevision, requiredVersions }, null, 2));
}

async function phase0Vulkan() {
  await ensureRoots();
  const expectedUserSDKRoot = join(USER_HOME, 'VulkanSDK', EXPECTED.vulkanSDKVersion, 'macOS');
  const vulkanInfo = firstExisting([
    process.env.VULKAN_SDK ? join(process.env.VULKAN_SDK, 'bin', 'vulkaninfo') : null,
    join(expectedUserSDKRoot, 'bin', 'vulkaninfo'),
    '/opt/homebrew/bin/vulkaninfo',
    '/usr/local/bin/vulkaninfo'
  ]);
  if (!vulkanInfo) die(`VULKAN_SDK_${EXPECTED.vulkanSDKVersion}_REQUIRED: vulkaninfo was not found in the active Vulkan SDK or expected paths.`, 4);
  const versionOutput = run(vulkanInfo, ['--version'], { allowFailure: true }).stdout.trim();
  const sdkPathVersionMatch = vulkanInfo.includes(`/VulkanSDK/${EXPECTED.vulkanSDKVersion}/`);
  const envVersionMatch = Boolean(process.env.VULKAN_SDK?.includes(EXPECTED.vulkanSDKVersion));
  if (!sdkPathVersionMatch && !envVersionMatch) {
    die(`VULKAN_SDK_VERSION_NOT_PROVEN: found ${vulkanInfo}, but frozen ${EXPECTED.vulkanSDKVersion} identity is not proven.`, 16);
  }
  const summary = run(vulkanInfo, ['--summary'], { maxBuffer: 64 * 1024 * 1024 }).stdout;
  await atomicWrite(join(SSOT, 'vulkaninfo-summary.txt'), summary);
  await updateStackLock([[['vulkan_sdk', 'vulkaninfo_version'], versionOutput || EXPECTED.vulkanSDKVersion]]);
  console.log(JSON.stringify({ phase: '0-vulkan', pass: true, vulkaninfo: vulkanInfo, version: versionOutput || null }, null, 2));
}

async function ensureRepoTool() {
  const systemRepo = firstExisting(['/opt/homebrew/bin/repo', '/usr/local/bin/repo']);
  if (systemRepo) return systemRepo;
  const localRepo = join(BUILD, 'bin', 'repo');
  if (!existsSync(localRepo)) {
    await mkdir(dirname(localRepo), { recursive: true });
    run('/usr/bin/curl', ['-fL', '--retry', '3', 'https://storage.googleapis.com/git-repo-downloads/repo', '-o', localRepo]);
    await chmod(localRepo, 0o755);
  }
  return localRepo;
}

function gitCommit(path) {
  return run('/usr/bin/git', ['-C', path, 'rev-parse', 'HEAD']).stdout.trim();
}

function lineEvidence(text, patterns) {
  const lines = text.split(/\r?\n/);
  const evidence = [];
  for (let index = 0; index < lines.length; index += 1) {
    if (patterns.some(pattern => pattern.test(lines[index]))) {
      evidence.push({ line: index + 1, text: lines[index].trim() });
    }
  }
  return evidence;
}

function resolveRemoteTag(url, tag) {
  const output = run('/usr/bin/git', ['ls-remote', '--tags', url, `refs/tags/${tag}`, `refs/tags/${tag}^{}`]).stdout;
  const rows = output.trim().split(/\r?\n/).filter(Boolean).map(line => line.split(/\s+/));
  const peeled = rows.find(row => row[1]?.endsWith('^{}'));
  const direct = rows.find(row => row[1] === `refs/tags/${tag}`);
  return peeled?.[0] ?? direct?.[0] ?? null;
}

async function phase0Source() {
  await ensureRoots();
  const repoTool = await ensureRepoTool();
  const aemuRoot = join(BUILD, 'aemu');
  await mkdir(aemuRoot, { recursive: true });
  const repoEnv = { ...process.env, HOME: USER_HOME };
  run(repoTool, ['init', '-u', 'https://android.googlesource.com/platform/manifest', '-b', EXPECTED.aemuBranch], {
    cwd: aemuRoot,
    env: repoEnv,
    maxBuffer: 128 * 1024 * 1024
  });
  run(repoTool, ['sync', '-c', '-j8'], {
    cwd: aemuRoot,
    env: repoEnv,
    maxBuffer: 256 * 1024 * 1024
  });

  const resolvedManifest = run(repoTool, ['manifest', '-r'], {
    cwd: aemuRoot,
    env: repoEnv,
    maxBuffer: 256 * 1024 * 1024
  }).stdout;
  const manifestPath = join(SSOT, 'upstreams-aemu.lock.xml');
  await atomicWrite(manifestPath, resolvedManifest);
  const manifestSHA256 = await sha256(manifestPath);

  const components = {
    qemu: join(aemuRoot, 'external', 'qemu'),
    aemu: join(aemuRoot, 'hardware', 'google', 'aemu'),
    gfxstream: join(aemuRoot, 'hardware', 'google', 'gfxstream'),
    angle: join(aemuRoot, 'external', 'angle'),
    moltenvk: join(aemuRoot, 'external', 'moltenvk')
  };
  for (const [name, path] of Object.entries(components)) {
    if (!existsSync(path)) throw new Error(`locked AEMU manifest is missing required component ${name}: ${path}`);
  }
  const commits = Object.fromEntries(Object.entries(components).map(([name, path]) => [name, gitCommit(path)]));

  const guestAngleSource = join(components.qemu, 'android', 'android-emu', 'android', 'userspace-boot-properties.cpp');
  const sourceText = await readFile(guestAngleSource, 'utf8');
  const sourceSHA256 = await sha256(guestAngleSource);
  const checks = {
    guestAngleFeatureGate: /fc::isEnabled\(fc::GuestAngle\)/.test(sourceText),
    hardwareEGLAngle: /params\.push_back\(\{\"androidboot\.hardwareegl\",\s*\"angle\"\}\)/.test(sourceText),
    guestAngleRequiresVulkan: /Cannot use GuestAngle without Vulkan enabled/.test(sourceText),
    hardwareVulkanRanchu: /params\.push_back\(\{\"androidboot\.hardware\.vulkan\",\s*\"ranchu\"\}\)/.test(sourceText),
    nonconformantExposureExplicitlyDisabled: /Without turning off exposeNonConformantExtensionsAndVersions/.test(sourceText) && /extensionLimitStr\s*=\s*\"exposeN\*\"/.test(sourceText) && /angle_overrides_disabled\s*\+=\s*extensionLimitStr/.test(sourceText)
  };
  const guestAnglePass = Object.values(checks).every(Boolean);
  const guestAngleArtifact = {
    schema: 1,
    observedAt: new Date().toISOString(),
    branchAuthority: EXPECTED.aemuBranch,
    qemuCommit: commits.qemu,
    sourcePath: 'external/qemu/android/android-emu/android/userspace-boot-properties.cpp',
    sourceSHA256,
    checks,
    evidence: lineEvidence(sourceText, [
      /GuestAngle/,
      /androidboot\.hardwareegl/,
      /androidboot\.hardware\.vulkan/,
      /exposeNonConformantExtensionsAndVersions/,
      /extensionLimitStr/
    ]),
    pass: guestAnglePass
  };
  await atomicWrite(join(SSOT, 'guestangle-authority.json'), `${JSON.stringify(guestAngleArtifact, null, 2)}\n`);

  const referenceRoot = join(BUILD, 'references');
  await mkdir(referenceRoot, { recursive: true });
  const moltenVKReference = join(referenceRoot, 'MoltenVK-1.4.2');
  if (!existsSync(join(moltenVKReference, '.git'))) {
    await rm(moltenVKReference, { recursive: true, force: true });
    run('/usr/bin/git', ['clone', '--depth', '1', '--branch', EXPECTED.moltenVKReferenceTag, 'https://github.com/KhronosGroup/MoltenVK.git', moltenVKReference], { maxBuffer: 128 * 1024 * 1024 });
  }
  const moltenVKReferenceCommit = gitCommit(moltenVKReference);
  const glesCTSCommit = resolveRemoteTag('https://github.com/KhronosGroup/VK-GL-CTS.git', EXPECTED.glesCTSTag);
  if (!glesCTSCommit) throw new Error(`could not resolve ${EXPECTED.glesCTSTag}`);

  const repoVersion = run(repoTool, ['--version'], { cwd: aemuRoot, env: repoEnv, allowFailure: true }).stdout.trim();
  const repoToolSHA256 = await sha256(repoTool);
  const sourceArtifact = {
    schema: 1,
    observedAt: new Date().toISOString(),
    aemuBranch: EXPECTED.aemuBranch,
    manifestSHA256,
    commits,
    guestAnglePass,
    moltenVKReference: { tag: EXPECTED.moltenVKReferenceTag, commit: moltenVKReferenceCommit },
    generality: {
      glesCTSTag: EXPECTED.glesCTSTag,
      glesCTSCommit,
      vulkanCTSTag: EXPECTED.vulkanCTSTag,
      vulkanCTSCommit: EXPECTED.vulkanCTSCommit,
      vulkanSamplesCommit: EXPECTED.vulkanSamplesCommit
    },
    repoTool: { path: repoTool, sha256: repoToolSHA256, version: repoVersion }
  };
  await atomicWrite(join(SSOT, 'phase0-source.json'), `${JSON.stringify(sourceArtifact, null, 2)}\n`);
  await atomicWrite(join(SSOT, 'source-hashes.txt'), [
    `upstreams-aemu.lock.xml sha256=${manifestSHA256}`,
    `userspace-boot-properties.cpp sha256=${sourceSHA256}`,
    `repo sha256=${repoToolSHA256}`,
    `moltenvk-reference commit=${moltenVKReferenceCommit}`,
    `gles-cts commit=${glesCTSCommit}`
  ].join('\n') + '\n');
  await updateStackLock([
    [['aemu', 'resolved_manifest_sha256'], manifestSHA256],
    [['aemu', 'qemu_commit'], commits.qemu],
    [['aemu', 'aemu_commit'], commits.aemu],
    [['aemu', 'gfxstream_commit'], commits.gfxstream],
    [['aemu', 'integrated_angle_commit'], commits.angle],
    [['aemu', 'integrated_moltenvk_commit'], commits.moltenvk],
    [['aemu', 'guestangle_authority'], guestAnglePass ? 'PASS' : 'FAIL'],
    [['moltenvk', 'reference_commit'], moltenVKReferenceCommit],
    [['generality', 'gles_cts_commit'], glesCTSCommit]
  ]);
  console.log(JSON.stringify(sourceArtifact, null, 2));
  if (!guestAnglePass) die('GUESTANGLE_AUTHORITY_FAILED: locked source semantics do not satisfy the SSOT.', 7);
}

const AUTHORITY_FILES = Object.freeze([
  {
    source: '/mnt/data/TFTMAC_FULL_IMPLEMENTATION_PLAN_REVISED(1).md',
    path: join(REPO, 'TFTMAC_FULL_IMPLEMENTATION_PLAN.md'),
    sha256: 'd074a0561d40813258c24bddb87a870a3bb62e634257674ebef55f0539492e4e'
  },
  {
    source: '/mnt/data/TFTMAC_GPU_RUNTIME_SSOT_REVISED(1).md',
    path: join(REPO, 'TFTMAC_GPU_RUNTIME_SSOT.md'),
    sha256: '6672347368c4adc007073a87a5b3dddda211f3c30bb80580f26de2d33d71dd7e'
  }
]);

async function importAuthorityFiles() {
  const imported = [];
  for (const entry of AUTHORITY_FILES) {
    if (!existsSync(entry.source)) throw new Error(`approved authority source is unavailable: ${entry.source}`);
    const sourceSHA256 = await sha256(entry.source);
    if (sourceSHA256 !== entry.sha256) {
      throw new Error(`approved authority source hash mismatch for ${entry.source}: expected ${entry.sha256}, got ${sourceSHA256}`);
    }
    await copyFile(entry.source, entry.path);
    const destinationSHA256 = await sha256(entry.path);
    if (destinationSHA256 !== entry.sha256) {
      throw new Error(`authority destination hash mismatch for ${entry.path}: expected ${entry.sha256}, got ${destinationSHA256}`);
    }
    imported.push({ source: entry.source, destination: entry.path.replace(`${REPO}/`, ''), sha256: destinationSHA256 });
  }
  console.log(JSON.stringify({ phase: '0-authority-import', pass: true, imported }, null, 2));
}

async function phase0Policy() {
  await ensureRoots();
  const authority = [];
  for (const entry of AUTHORITY_FILES) {
    if (!existsSync(entry.path)) {
      authority.push({ path: entry.path.replace(`${REPO}/`, ''), expectedSHA256: entry.sha256, exists: false, hashMatches: false });
      continue;
    }
    const actualSHA256 = await sha256(entry.path);
    authority.push({
      path: entry.path.replace(`${REPO}/`, ''),
      expectedSHA256: entry.sha256,
      actualSHA256,
      exists: true,
      hashMatches: actualSHA256 === entry.sha256
    });
  }

  const legacyChecks = [];
  const legacyFiles = [
    ['tftmac/Sources/TFTMACApp.swift', [
      ['opengles-version-boot-property', 'androidboot.opengles.version=196610'],
      ['legacy-avd-name', 'TftHighEndTablet']
    ]],
    ['tools/clara-task.mjs', [
      ['legacy-api36-image', 'system-images;android-36;google_apis_playstore;arm64-v8a'],
      ['legacy-acquisition-avd', "const AVD_NAME = 'TftLiveStore'"],
      ['legacy-performance-avd', "const PERFORMANCE_AVD_NAME = 'TftHighEndTablet'"]
    ]],
    ['TFTMAC.md', [
      ['legacy-api36-doc', 'Android 16 / API 36'],
      ['legacy-196610-proof-doc', 'OpenGL ES: **3.2** (`196610`)']
    ]]
  ];
  for (const [relative, checks] of legacyFiles) {
    const path = join(REPO, relative);
    const text = existsSync(path) ? await readFile(path, 'utf8') : '';
    for (const [id, needle] of checks) {
      legacyChecks.push({ id, path: relative, present: text.includes(needle), classification: 'LEGACY_DONOR_NOT_V2_ACCEPTANCE' });
    }
  }

  const forbiddenRuntimeProof = legacyChecks.filter(item => item.present).map(item => item.id);
  const authorityPass = authority.every(item => item.exists && item.hashMatches);
  const result = {
    schema: 1,
    observedAt: new Date().toISOString(),
    authority,
    legacyChecks,
    authorityPass,
    legacyRuntimeClaimsQuarantined: true,
    forbiddenRuntimeProof,
    pass: authorityPass
  };
  await atomicWrite(join(SSOT, 'phase0-policy.json'), `${JSON.stringify(result, null, 2)}\n`);
  console.log(JSON.stringify(result, null, 2));
  if (!result.pass) die('PHASE_0_POLICY_FAILED: canonical authority documents are missing or do not match approved hashes.', 14);
}

async function preflightReport() {
  await ensureRoots();
  const artifactNames = [
    'AUTHORITY_INPUTS.sha256',
    'STACK.lock.yaml',
    'host-preflight.json',
    'xcode-discovery.json',
    'android-license-status.json',
    'android-sdk-packages.txt',
    'vulkaninfo-summary.txt',
    'upstreams-aemu.lock.xml',
    'phase0-source.json',
    'source-hashes.txt',
    'guestangle-authority.json',
    'vulkan-required-cases.spec.json',
    'vulkan-required-cases.txt',
    'phase0-policy.json'
  ];
  const rows = [];
  for (const name of artifactNames) {
    const path = join(SSOT, name);
    if (!existsSync(path)) {
      rows.push({ name, state: 'MISSING', sha256: null });
      continue;
    }
    rows.push({ name, state: 'PRESENT', sha256: await sha256(path) });
  }
  const host = existsSync(join(SSOT, 'host-preflight.json')) ? JSON.parse(await readFile(join(SSOT, 'host-preflight.json'), 'utf8')) : null;
  const policy = existsSync(join(SSOT, 'phase0-policy.json')) ? JSON.parse(await readFile(join(SSOT, 'phase0-policy.json'), 'utf8')) : null;
  const guestAngle = existsSync(join(SSOT, 'guestangle-authority.json')) ? JSON.parse(await readFile(join(SSOT, 'guestangle-authority.json'), 'utf8')) : null;
  const stackText = await readFile(join(SSOT, 'STACK.lock.yaml'), 'utf8');
  const stackScalars = parseSimpleYamlScalars(stackText);
  const unresolvedCriticalLockFields = CRITICAL_LOCK_PATHS
    .map(path => path.join('.'))
    .filter(path => !stackScalars.has(path) || stackScalars.get(path) === null || stackScalars.get(path) === '');
  const blockers = [];
  if (!host?.pass) blockers.push('Host preflight is not green (frozen Xcode 26.6 / 17F113 required).');
  if (!policy?.pass) blockers.push('Canonical authority documents are missing or hash-mismatched.');
  if (!existsSync(join(SSOT, 'android-sdk-packages.txt'))) blockers.push('Android API 37 package freeze is incomplete.');
  if (!existsSync(join(SSOT, 'vulkaninfo-summary.txt'))) blockers.push('Vulkan SDK 1.4.357.0 validation is incomplete.');
  if (!existsSync(join(SSOT, 'upstreams-aemu.lock.xml'))) blockers.push('Resolved emu-master-dev manifest is not frozen.');
  if (!guestAngle?.pass) blockers.push('Locked-source GuestAngle authority proof is not green.');
  if (!existsSync(join(SSOT, 'vulkan-required-cases.txt'))) blockers.push('Exact Vulkan CTS required-case list is not frozen.');
  if (unresolvedCriticalLockFields.length) blockers.push(`STACK.lock.yaml has ${unresolvedCriticalLockFields.length} unresolved critical field(s): ${unresolvedCriticalLockFields.join(', ')}`);

  const markdown = [
    '# TFTMAC GPU Runtime v2.0 — Phase 0 Preflight Report',
    '',
    `Generated: ${new Date().toISOString()}`,
    '',
    `Status: **${blockers.length === 0 ? 'PASS' : 'BLOCKED'}**`,
    '',
    '## Blockers',
    '',
    ...(blockers.length ? blockers.map(item => `- ${item}`) : ['- None.']),
    '',
    '## Artifact inventory',
    '',
    '| Artifact | State | SHA-256 |',
    '|---|---|---|',
    ...rows.map(row => `| \`ssot/${row.name}\` | ${row.state} | ${row.sha256 ?? '—'} |`),
    '',
    'Phase 0 may be declared complete only when this report is PASS and `STACK.lock.yaml` contains no unresolved critical-path null.'
  ].join('\n') + '\n';
  await atomicWrite(join(SSOT, 'preflight-report.md'), markdown);
  console.log(markdown);
  if (blockers.length) die(`PHASE_0_BLOCKED: ${blockers.length} unresolved blocker(s).`, 15);
}

async function cleanupSandboxBootstrap() {
  const sandboxApp = join(SANDBOX_HOME, 'Library', 'Application Support', 'TFTMAC');
  if (sandboxApp === APP) {
    console.log(JSON.stringify({ removed: false, reason: 'sandbox-home-is-console-home', path: sandboxApp }, null, 2));
    return;
  }
  if (!sandboxApp.includes('/CLARA-RUNTIME/process-home/')) {
    die(`REFUSING_SANDBOX_CLEANUP_OUTSIDE_CLARA_RUNTIME: ${sandboxApp}`, 6);
  }
  const existed = existsSync(sandboxApp);
  if (existed) await rm(sandboxApp, { recursive: true, force: true });
  console.log(JSON.stringify({ removed: existed, path: sandboxApp, canonicalAppRoot: APP }, null, 2));
}

async function discoverXcodes() {
  const discovered = discoverInstalledXcodes();
  const match = findRequiredXcode(discovered);
  await atomicWrite(join(SSOT, 'xcode-discovery.json'), `${JSON.stringify({ observedAt: new Date().toISOString(), required: { version: EXPECTED.xcodeVersion, build: EXPECTED.xcodeBuild }, selected: match, discovered }, null, 2)}\n`);
  console.log(JSON.stringify({ phase: '0-xcode-discovery', required: { version: EXPECTED.xcodeVersion, build: EXPECTED.xcodeBuild }, selected: match, discovered }, null, 2));
  if (!match) die(`XCODE_${EXPECTED.xcodeVersion}_${EXPECTED.xcodeBuild}_NOT_FOUND`, 5);
}

async function status() {
  await ensureRoots();
  const paths = [
    'STACK.lock.yaml', 'host-preflight.json', 'android-sdk-packages.txt', 'tool-versions.txt',
    'source-hashes.txt', 'guestangle-authority.json', 'vulkan-required-cases.txt', 'preflight-report.md',
    'upstreams-aemu.lock.xml', 'vulkaninfo-summary.txt'
  ];
  const artifacts = {};
  for (const name of paths) {
    const path = join(SSOT, name);
    artifacts[name] = existsSync(path) ? { exists: true, bytes: (await stat(path)).size, sha256: await sha256(path) } : { exists: false };
  }
  console.log(JSON.stringify({
    appRoot: APP,
    buildRoot: BUILD,
    buildRootSource: process.env.TFTMAC_BUILD_ROOT ? 'TFTMAC_BUILD_ROOT' : 'default-external',
    repository: REPO,
    artifacts
  }, null, 2));
}

const action = process.argv[2] ?? 'status';
try {
  switch (action) {
    case 'phase0-host': await phase0Host(); break;
    case 'phase0-android': await phase0Android(); break;
    case 'phase0-vulkan': await phase0Vulkan(); break;
    case 'phase0-source': await phase0Source(); break;
    case 'phase0-authority': await importAuthorityFiles(); break;
    case 'phase0-policy': await phase0Policy(); break;
    case 'phase0-report': await preflightReport(); break;
    case 'phase0-xcode-discovery': await discoverXcodes(); break;
    case 'cleanup-sandbox-bootstrap': await cleanupSandboxBootstrap(); break;
    case 'status': await status(); break;
    default: die(`unknown action: ${action}`);
  }
} catch (error) {
  die(error instanceof Error ? error.message : String(error));
}
