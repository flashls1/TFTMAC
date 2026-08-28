#!/usr/bin/env node
import { createHash } from 'node:crypto';
import { closeSync, createReadStream, existsSync, openSync } from 'node:fs';
import { chmod, copyFile, mkdir, readFile, readdir, rename, rm, stat, symlink, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { homedir } from 'node:os';
import { spawn, spawnSync } from 'node:child_process';
import { DatabaseSync } from 'node:sqlite';

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
const DEFAULT_RUNTIME_ROOT = join(DEFAULT_BUILD_VOLUME, 'TFTMAC', 'Runtime');
const RUNTIME = resolve(process.env.TFTMAC_RUNTIME_ROOT ?? DEFAULT_RUNTIME_ROOT);
const SDK = join(RUNTIME, 'SDK');
const AVD_HOME = join(RUNTIME, 'AVD');
const PACKAGES = join(RUNTIME, 'Packages');
const PROBES = join(RUNTIME, 'Probes');
const MANIFESTS = join(RUNTIME, 'Manifests');
const LOGS = join(APP, 'Logs');
const DIAGNOSTICS = join(APP, 'Diagnostics');
const ROLLBACK = join(APP, 'Rollback');
const SSOT = join(REPO, 'ssot');
const SOURCE_WORKER_STATE = join(LOGS, 'phase0-source-worker.json');
const SOURCE_WORKER_STDOUT = join(LOGS, 'phase0-source-worker.stdout.log');
const SOURCE_WORKER_STDERR = join(LOGS, 'phase0-source-worker.stderr.log');
const PHASE1_BUILD_STATE = join(MANIFESTS, 'phase1-build-worker.json');
const PHASE1_BUILD_LOG_ROOT = join(BUILD, 'logs');
const PHASE1_BUILD_STDOUT = join(PHASE1_BUILD_LOG_ROOT, 'phase1-build.stdout.log');
const PHASE1_BUILD_STDERR = join(PHASE1_BUILD_LOG_ROOT, 'phase1-build.stderr.log');
const PHASE1_AEMU_ALIAS = '/private/tmp/tftmac-aemu';
const DIRECT_CONTROL_REQUEST = join(REPO, '.tftmac-direct-control-request.json');

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
    'platforms;android-36',
    'build-tools;37.0.0',
    'system-images;android-36;google_apis_playstore;arm64-v8a'
  ],
  playImagePackage: 'system-images;android-36;google_apis_playstore;arm64-v8a',
  minimumPlayImageRevision: 7,
  avdName: 'TFTMAC_Live_API36',
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

function runInherited(executable, args = [], options = {}) {
  const result = spawnSync(executable, args, {
    cwd: options.cwd ?? REPO,
    env: options.env ?? process.env,
    stdio: 'inherit'
  });
  if (result.error) {
    throw new Error(`${executable} failed to start: ${result.error.message}`);
  }
  if (result.status !== 0) {
    throw new Error(`${executable} ${args.join(' ')} exited ${result.status}`);
  }
  return { status: result.status ?? 1 };
}

function pidIsAlive(pid) {
  if (!Number.isInteger(pid) || pid <= 0) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

async function readSourceWorkerState() {
  if (!existsSync(SOURCE_WORKER_STATE)) return null;
  try {
    return JSON.parse(await readFile(SOURCE_WORKER_STATE, 'utf8'));
  } catch {
    return { schema: 1, status: 'INVALID_STATE_FILE', path: SOURCE_WORKER_STATE };
  }
}

async function readPhase1BuildState() {
  if (!existsSync(PHASE1_BUILD_STATE)) return null;
  try {
    return JSON.parse(await readFile(PHASE1_BUILD_STATE, 'utf8'));
  } catch {
    return { schema: 1, status: 'INVALID_STATE_FILE', path: PHASE1_BUILD_STATE };
  }
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
  const usesDefaultExternalBuild = !process.env.TFTMAC_BUILD_ROOT;
  const usesDefaultExternalRuntime = !process.env.TFTMAC_RUNTIME_ROOT;
  if ((usesDefaultExternalBuild || usesDefaultExternalRuntime) && !existsSync(DEFAULT_BUILD_VOLUME)) {
    die(`TFTMAC_EXTERNAL_VOLUME_REQUIRED: ${DEFAULT_BUILD_VOLUME} is not mounted; refusing to create Build or Runtime data on the internal disk.`, 17);
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
  const applicationCandidates = listing.filter(name => /^Xcode.*\.app$/i.test(name)).map(name => join(applications, name));
  const spotlight = run('/usr/bin/mdfind', ["kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'"], { allowFailure: true }).stdout
    .split(/\r?\n/).map(value => value.trim()).filter(value => /Xcode.*\.app$/i.test(value));
  const candidateApps = [...new Set([
    ...applicationCandidates,
    ...spotlight,
    join(USER_HOME, 'Downloads', 'Xcode.app'),
    join(USER_HOME, 'Applications', 'Xcode.app')
  ])];
  const discovered = [];
  for (const app of candidateApps) {
    if (!existsSync(app)) continue;
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
  const spotlightLicenses = run('/usr/bin/mdfind', ["kMDItemFSName == 'android-sdk-license'"], { allowFailure: true }).stdout
    .split(/\r?\n/).map(value => value.trim()).filter(Boolean).map(path => dirname(dirname(path)));
  const candidates = [...new Set([
    process.env.ANDROID_SDK_ROOT,
    process.env.ANDROID_HOME,
    join(USER_HOME, 'Library', 'Android', 'sdk'),
    ...spotlightLicenses
  ].filter(Boolean))];
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

function resolveJavaHome() {
  const tool = run('/usr/libexec/java_home', ['-v', '17'], { allowFailure: true }).stdout.trim();
  const candidates = [
    process.env.JAVA_HOME,
    tool,
    '/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home',
    '/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home',
    '/Applications/Android Studio.app/Contents/jbr/Contents/Home',
    '/Applications/Android Studio.app/Contents/jre/Contents/Home'
  ].filter(Boolean);
  return candidates.find(home => existsSync(join(home, 'bin', 'java'))) ?? null;
}

function androidEnv() {
  const javaHome = resolveJavaHome();
  if (!javaHome) throw new Error('JAVA_17_REQUIRED: no usable Java 17 runtime was found for Android sdkmanager.');
  return {
    ...process.env,
    JAVA_HOME: javaHome,
    PATH: `${join(javaHome, 'bin')}:${process.env.PATH ?? ''}`,
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
  const androidCli = join(SDK, 'cmdline-tools', 'latest', 'bin', 'android');
  const avdmanager = join(SDK, 'cmdline-tools', 'latest', 'bin', 'avdmanager');
  if (!existsSync(join(SDK, 'licenses', 'android-sdk-license'))) {
    await atomicWrite(join(SSOT, 'android-license-status.json'), `${JSON.stringify({ acceptedLicenseEvidenceFound: false, checkedAt: new Date().toISOString() }, null, 2)}\n`);
    die('ANDROID_LICENSE_ACCEPTANCE_REQUIRED: no previously accepted Android SDK license evidence was found; no license was accepted automatically.', 3);
  }
  if (!existsSync(androidCli)) throw new Error(`ANDROID_CLI_REQUIRED: ${androidCli} was not found.`);
  const env = androidEnv();
  const api36CatalogResult = run(androidCli, [`--sdk=${SDK}`, 'sdk', 'list', '.*(36|Baklava).*', '--all', '--all-versions'], { env, allowFailure: true, maxBuffer: 128 * 1024 * 1024 });
  await atomicWrite(join(SSOT, 'android-api36-catalog.txt'), `${api36CatalogResult.stdout}${api36CatalogResult.stderr}`);
  run(androidCli, [`--sdk=${SDK}`, 'sdk', 'install', 'platform-tools', 'emulator', 'build-tools/37.0.0'], { env, maxBuffer: 128 * 1024 * 1024 });
  run(androidCli, [`--sdk=${SDK}`, 'sdk', 'install', '--canary', 'platforms/android-36', 'system-images/android-36/google_apis_playstore/arm64-v8a'], { env, maxBuffer: 128 * 1024 * 1024 });

  const revisionAt = async relative => {
    const propertiesPath = join(SDK, relative, 'source.properties');
    if (!existsSync(propertiesPath)) return null;
    return parseProperties(await readFile(propertiesPath, 'utf8'))['Pkg.Revision'] ?? null;
  };
  const discoverPlatform36 = async () => {
    const root = join(SDK, 'platforms');
    if (!existsSync(root)) return null;
    for (const entry of await readdir(root, { withFileTypes: true })) {
      if (!entry.isDirectory()) continue;
      const propertiesPath = join(root, entry.name, 'source.properties');
      if (!existsSync(propertiesPath)) continue;
      const properties = parseProperties(await readFile(propertiesPath, 'utf8'));
      if (!String(properties['AndroidVersion.ApiLevel'] ?? '').startsWith('36')) continue;
      return { directory: entry.name, revision: properties['Pkg.Revision'] ?? null, codeName: properties['AndroidVersion.CodeName'] ?? null };
    }
    return null;
  };
  const platform36 = await discoverPlatform36();
  const requiredVersions = {
    'platform-tools': await revisionAt('platform-tools'),
    'emulator': await revisionAt('emulator'),
    'platforms;android-36': platform36?.revision ?? null,
    'build-tools;37.0.0': await revisionAt('build-tools/37.0.0'),
    [EXPECTED.playImagePackage]: await revisionAt('system-images/android-36/google_apis_playstore/arm64-v8a')
  };
  const missingPackages = Object.entries(requiredVersions).filter(([, version]) => !version).map(([path]) => path);
  if (missingPackages.length) throw new Error(`required Android packages missing after install: ${missingPackages.join(', ')}`);
  const installed = `${JSON.stringify({ schema: 1, observedAt: new Date().toISOString(), requiredVersions }, null, 2)}\n`;
  await atomicWrite(join(SSOT, 'android-sdk-packages.txt'), installed);
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
    [['android', 'platform_revision'], requiredVersions['platforms;android-36']],
    [['android', 'build_tools_revision'], requiredVersions['build-tools;37.0.0']]
  ]);
  console.log(JSON.stringify({ phase: '0-android', pass: true, license, avd: EXPECTED.avdName, sdk: SDK, commandLineToolsRevision: cmdlineRevision, requiredVersions }, null, 2));
}

async function phase0Vulkan() {
  await ensureRoots();
  const externalSDKRoot = join(RUNTIME, 'VulkanSDK', EXPECTED.vulkanSDKVersion);
  const externalVulkanInfo = join(externalSDKRoot, 'macOS', 'bin', 'vulkaninfo');
  const expectedUserSDKRoot = join(USER_HOME, 'VulkanSDK', EXPECTED.vulkanSDKVersion, 'macOS');
  let vulkanInfo = firstExisting([
    process.env.VULKAN_SDK ? join(process.env.VULKAN_SDK, 'bin', 'vulkaninfo') : null,
    externalVulkanInfo,
    join(expectedUserSDKRoot, 'bin', 'vulkaninfo'),
    '/opt/homebrew/bin/vulkaninfo',
    '/usr/local/bin/vulkaninfo'
  ]);

  if (!vulkanInfo) {
    const archive = join(PACKAGES, `vulkansdk-macos-${EXPECTED.vulkanSDKVersion}.zip`);
    await downloadVerified(`https://sdk.lunarg.com/sdk/download/${EXPECTED.vulkanSDKVersion}/mac/vulkan_sdk.zip`, archive, EXPECTED.vulkanSDKSHA256);
    const stage = join(PACKAGES, `vulkansdk-macos-${EXPECTED.vulkanSDKVersion}-installer`);
    if (!existsSync(stage)) {
      await mkdir(stage, { recursive: true });
      run('/usr/bin/unzip', ['-q', archive, '-d', stage], { maxBuffer: 128 * 1024 * 1024 });
    }
    const installerApp = run('/usr/bin/find', [stage, '-maxdepth', '3', '-name', 'vulkansdk-macOS-*.app', '-print'], { allowFailure: true }).stdout
      .split(/\r?\n/).map(value => value.trim()).find(Boolean) ?? null;
    const installerBinary = installerApp ? join(installerApp, 'Contents', 'MacOS', installerApp.split('/').pop().replace(/\.app$/, '')) : null;
    await atomicWrite(join(SSOT, 'vulkan-install-required.json'), `${JSON.stringify({
      schema: 1,
      version: EXPECTED.vulkanSDKVersion,
      archive,
      archiveSHA256: EXPECTED.vulkanSDKSHA256,
      installerApp,
      installerBinary,
      installRoot: externalSDKRoot,
      copyOnly: true,
      licenseAcceptanceRequired: true
    }, null, 2)}\n`);
    die(`VULKAN_SDK_LICENSE_ACCEPTANCE_REQUIRED: verified installer staged at ${installerApp ?? stage}; install root must be ${externalSDKRoot}.`, 4);
  }

  const versionOutput = run(vulkanInfo, ['--version'], { allowFailure: true }).stdout.trim();
  const sdkPathVersionMatch = vulkanInfo.includes(`/${EXPECTED.vulkanSDKVersion}/`);
  const envVersionMatch = Boolean(process.env.VULKAN_SDK?.includes(EXPECTED.vulkanSDKVersion));
  if (!sdkPathVersionMatch && !envVersionMatch) {
    die(`VULKAN_SDK_VERSION_NOT_PROVEN: found ${vulkanInfo}, but frozen ${EXPECTED.vulkanSDKVersion} identity is not proven.`, 16);
  }
  const sdkRoot = resolve(vulkanInfo, '..', '..');
  const env = {
    ...process.env,
    VULKAN_SDK: sdkRoot,
    PATH: `${join(sdkRoot, 'bin')}:${process.env.PATH ?? ''}`,
    DYLD_LIBRARY_PATH: `${join(sdkRoot, 'lib')}:${process.env.DYLD_LIBRARY_PATH ?? ''}`,
    VK_ICD_FILENAMES: join(sdkRoot, 'share', 'vulkan', 'icd.d', 'MoltenVK_icd.json'),
    VK_LAYER_PATH: join(sdkRoot, 'share', 'vulkan', 'explicit_layer.d')
  };
  const summary = run(vulkanInfo, ['--summary'], { env, maxBuffer: 64 * 1024 * 1024 }).stdout;
  await atomicWrite(join(SSOT, 'vulkaninfo-summary.txt'), summary);
  await updateStackLock([[['vulkan_sdk', 'vulkaninfo_version'], versionOutput || EXPECTED.vulkanSDKVersion]]);
  console.log(JSON.stringify({ phase: '0-vulkan', pass: true, vulkaninfo: vulkanInfo, sdkRoot, version: versionOutput || null }, null, 2));
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

async function discoverIntegratedMoltenVK(components, commits) {
  const probes = [];
  for (const [component, path] of Object.entries(components)) {
    const grep = run('/usr/bin/git', ['-C', path, 'grep', '-n', '-i', 'MoltenVK', '--', '.'], {
      allowFailure: true,
      maxBuffer: 32 * 1024 * 1024
    });
    const matches = grep.stdout.split(/\r?\n/).filter(Boolean);
    const hashCandidates = [...new Set(matches.flatMap(line => line.match(/\b[0-9a-f]{40}\b/g) ?? []))];
    probes.push({
      component,
      path,
      commit: commits[component],
      matchCount: matches.length,
      hashCandidates,
      matches: matches.slice(0, 80)
    });
  }
  const artifact = {
    schema: 1,
    observedAt: new Date().toISOString(),
    branchAuthority: EXPECTED.aemuBranch,
    probes
  };
  await atomicWrite(join(SSOT, 'moltenvk-integration-discovery.json'), `${JSON.stringify(artifact, null, 2)}\n`);
  return artifact;
}

async function phase0SourceForeground() {
  await ensureRoots();
  const repoTool = await ensureRepoTool();
  const aemuRoot = join(BUILD, 'aemu');
  await mkdir(aemuRoot, { recursive: true });
  const repoEnv = { ...process.env, HOME: USER_HOME };
  runInherited(repoTool, ['init', '-u', 'https://android.googlesource.com/platform/manifest', '-b', EXPECTED.aemuBranch], {
    cwd: aemuRoot,
    env: repoEnv
  });
  runInherited(repoTool, ['sync', '-c', '-j8'], {
    cwd: aemuRoot,
    env: repoEnv
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
    moltenvkPrebuilt: join(aemuRoot, 'prebuilts', 'android-emulator')
  };
  for (const [name, path] of Object.entries(components)) {
    if (!existsSync(path)) throw new Error(`locked AEMU manifest is missing required component ${name}: ${path}`);
  }
  const commits = Object.fromEntries(Object.entries(components).map(([name, path]) => [name, gitCommit(path)]));
  const moltenVKConfigPath = join(components.qemu, 'android', 'build', 'cmake', 'config', 'emu-vulkan-config.cmake');
  const moltenVKConfigText = await readFile(moltenVKConfigPath, 'utf8');
  const moltenVKPrebuiltEvidence = lineEvidence(moltenVKConfigText, [/PREBUILT_ROOT.*libMoltenVK\.dylib/, /PREBUILT_ROOT.*MoltenVK_icd\.json/]);
  if (moltenVKPrebuiltEvidence.length < 2) {
    throw new Error('MOLTENVK_PREBUILT_AUTHORITY_NOT_PROVEN: qemu does not prove MoltenVK is supplied from PREBUILT_ROOT/icds.');
  }
  const integratedMoltenVKCommit = commits.moltenvkPrebuilt;
  await atomicWrite(join(SSOT, 'moltenvk-integration-discovery.json'), `${JSON.stringify({
    schema: 2,
    observedAt: new Date().toISOString(),
    branchAuthority: EXPECTED.aemuBranch,
    authorityType: 'resolved-manifest-prebuilt',
    authorityPath: 'prebuilts/android-emulator',
    authorityCommit: integratedMoltenVKCommit,
    qemuCommit: commits.qemu,
    qemuEvidencePath: 'external/qemu/android/build/cmake/config/emu-vulkan-config.cmake',
    evidence: moltenVKPrebuiltEvidence,
    pass: true
  }, null, 2)}\n`);

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
    moltenVKIntegration: { authority: 'prebuilts/android-emulator', commit: integratedMoltenVKCommit, discovery: 'ssot/moltenvk-integration-discovery.json' },
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
    `integrated-moltenvk commit=${integratedMoltenVKCommit}`,
    `moltenvk-reference commit=${moltenVKReferenceCommit}`,
    `gles-cts commit=${glesCTSCommit}`
  ].join('\n') + '\n');
  await updateStackLock([
    [['aemu', 'resolved_manifest_sha256'], manifestSHA256],
    [['aemu', 'qemu_commit'], commits.qemu],
    [['aemu', 'aemu_commit'], commits.aemu],
    [['aemu', 'gfxstream_commit'], commits.gfxstream],
    [['aemu', 'integrated_angle_commit'], commits.angle],
    [['aemu', 'integrated_moltenvk_commit'], integratedMoltenVKCommit],
    [['aemu', 'guestangle_authority'], guestAnglePass ? 'PASS' : 'FAIL'],
    [['moltenvk', 'reference_commit'], moltenVKReferenceCommit],
    [['generality', 'gles_cts_commit'], glesCTSCommit]
  ]);
  console.log(JSON.stringify(sourceArtifact, null, 2));
  if (!guestAnglePass) throw new Error('GUESTANGLE_AUTHORITY_FAILED: locked source semantics do not satisfy the SSOT.');
}

async function phase0SourceWorker() {
  await ensureRoots();
  const startedAt = process.env.TFTMAC_SOURCE_WORKER_STARTED_AT ?? new Date().toISOString();
  const baseState = {
    schema: 1,
    pid: process.pid,
    startedAt,
    buildRoot: BUILD,
    aemuRoot: join(BUILD, 'aemu'),
    branch: EXPECTED.aemuBranch,
    stdoutPath: SOURCE_WORKER_STDOUT,
    stderrPath: SOURCE_WORKER_STDERR
  };
  await atomicWrite(SOURCE_WORKER_STATE, `${JSON.stringify({ ...baseState, status: 'RUNNING' }, null, 2)}\n`);
  try {
    await phase0SourceForeground();
    await atomicWrite(SOURCE_WORKER_STATE, `${JSON.stringify({ ...baseState, status: 'SUCCEEDED', endedAt: new Date().toISOString() }, null, 2)}\n`);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    await atomicWrite(SOURCE_WORKER_STATE, `${JSON.stringify({ ...baseState, status: 'FAILED', endedAt: new Date().toISOString(), error: message }, null, 2)}\n`);
    throw error;
  }
}

async function phase0Source() {
  await ensureRoots();
  const existing = await readSourceWorkerState();
  if (existing?.pid && pidIsAlive(existing.pid)) {
    console.log(JSON.stringify({
      phase: '0-source',
      launched: false,
      alreadyRunning: true,
      worker: existing
    }, null, 2));
    return;
  }

  const startedAt = new Date().toISOString();
  const stdoutFd = openSync(SOURCE_WORKER_STDOUT, 'a');
  const stderrFd = openSync(SOURCE_WORKER_STDERR, 'a');
  try {
    const child = spawn(process.execPath, [fileURLToPath(import.meta.url), 'phase0-source-worker'], {
      cwd: REPO,
      env: { ...process.env, TFTMAC_SOURCE_WORKER_STARTED_AT: startedAt },
      detached: true,
      stdio: ['ignore', stdoutFd, stderrFd]
    });
    child.unref();
    console.log(JSON.stringify({
      phase: '0-source',
      launched: true,
      pid: child.pid,
      startedAt,
      buildRoot: BUILD,
      branch: EXPECTED.aemuBranch,
      statePath: SOURCE_WORKER_STATE,
      stdoutPath: SOURCE_WORKER_STDOUT,
      stderrPath: SOURCE_WORKER_STDERR
    }, null, 2));
  } finally {
    closeSync(stdoutFd);
    closeSync(stderrFd);
  }
}

const AUTHORITY_FILES = Object.freeze([
  {
    path: join(REPO, 'TFTMAC_FULL_IMPLEMENTATION_PLAN.md'),
    sha256: '81bd386c1d9d47f26659c93af914ec9a92568ee689e7bed47eb0f2afd6dd5f1a'
  },
  {
    path: join(REPO, 'TFTMAC_GPU_RUNTIME_SSOT.md'),
    sha256: '4c905ad35a676aa8f4ad0a22416e73d640120851ce9f41e742349ac61ceab1ea'
  }
]);

async function importAuthorityFiles() {
  const verified = [];
  for (const entry of AUTHORITY_FILES) {
    if (!existsSync(entry.path)) throw new Error(`canonical authority document is unavailable: ${entry.path}`);
    const actualSHA256 = await sha256(entry.path);
    if (actualSHA256 !== entry.sha256) {
      throw new Error(`canonical authority hash mismatch for ${entry.path}: expected ${entry.sha256}, got ${actualSHA256}`);
    }
    verified.push({ path: entry.path.replace(`${REPO}/`, ''), sha256: actualSHA256 });
  }
  console.log(JSON.stringify({ phase: '0-authority-verify', pass: true, verified }, null, 2));
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

async function ensureVulkanRequiredCases() {
  await ensureRoots();
  const outputPath = join(SSOT, 'vulkan-required-cases.txt');
  const selectionPath = join(SSOT, 'vulkan-required-cases-selection.json');
  const ctsRoot = join(BUILD, 'references', `VK-GL-CTS-${EXPECTED.vulkanCTSTag}`);

  if (!existsSync(join(ctsRoot, '.git'))) {
    await rm(ctsRoot, { recursive: true, force: true });
    run('/usr/bin/git', [
      'clone', '--filter=blob:none', '--no-checkout', '--depth', '1',
      '--branch', EXPECTED.vulkanCTSTag,
      'https://github.com/KhronosGroup/VK-GL-CTS.git', ctsRoot
    ], { maxBuffer: 128 * 1024 * 1024 });
  } else {
    run('/usr/bin/git', ['-C', ctsRoot, 'fetch', '--depth', '1', 'origin', `refs/tags/${EXPECTED.vulkanCTSTag}:refs/tags/${EXPECTED.vulkanCTSTag}`], { allowFailure: true, maxBuffer: 128 * 1024 * 1024 });
  }
  run('/usr/bin/git', ['-C', ctsRoot, 'sparse-checkout', 'init', '--cone'], { allowFailure: true });
  run('/usr/bin/git', ['-C', ctsRoot, 'sparse-checkout', 'set', 'external/vulkancts/mustpass/main']);
  let checkout = run('/usr/bin/git', ['-C', ctsRoot, 'checkout', '--detach', EXPECTED.vulkanCTSCommit], { allowFailure: true, maxBuffer: 128 * 1024 * 1024 });
  if (checkout.status !== 0) {
    run('/usr/bin/git', ['-C', ctsRoot, 'fetch', '--depth', '1', 'origin', EXPECTED.vulkanCTSCommit], { maxBuffer: 128 * 1024 * 1024 });
    run('/usr/bin/git', ['-C', ctsRoot, 'checkout', '--detach', EXPECTED.vulkanCTSCommit], { maxBuffer: 128 * 1024 * 1024 });
  }
  const observedCommit = gitCommit(ctsRoot);
  if (observedCommit !== EXPECTED.vulkanCTSCommit) {
    throw new Error(`VULKAN_CTS_COMMIT_MISMATCH: expected ${EXPECTED.vulkanCTSCommit}, got ${observedCommit}`);
  }

  const mustpassRoot = join(ctsRoot, 'external', 'vulkancts', 'mustpass', 'main');
  const indexPath = join(mustpassRoot, 'vk-default.txt');
  if (!existsSync(indexPath)) throw new Error(`VULKAN_CTS_MUSTPASS_MISSING: ${indexPath}`);

  const visited = new Set();
  const allCases = [];
  async function collectList(path) {
    const absolute = resolve(path);
    if (visited.has(absolute)) return;
    visited.add(absolute);
    const text = await readFile(absolute, 'utf8');
    for (const raw of text.split(/\r?\n/)) {
      const line = raw.trim();
      if (!line || line.startsWith('#')) continue;
      if (line.startsWith('dEQP-VK.')) {
        allCases.push(line);
        continue;
      }
      const candidates = [join(dirname(absolute), line), join(mustpassRoot, line), join(mustpassRoot, 'vk-default', line)];
      const nested = candidates.find(candidate => existsSync(candidate));
      if (nested) await collectList(nested);
    }
  }
  await collectList(indexPath);
  const uniqueCases = [...new Set(allCases)].sort();
  if (!uniqueCases.length) throw new Error('VULKAN_CTS_MUSTPASS_EMPTY: no dEQP-VK cases found in pinned mustpass tree.');

  const boundaries = [
    ['core-draw', [/^dEQP-VK\.draw\./i, /\.draw\./i]],
    ['geometry', [/geometry/i]],
    ['tessellation', [/tessellation/i]],
    ['shader-cull-distance', [/cull_distance/i, /culldistance/i]],
    ['compute', [/^dEQP-VK\.compute\./i, /\.compute\./i]],
    ['images', [/copy_and_blit/i, /\.image/i, /images?/i]],
    ['descriptors', [/binding_model/i, /descriptor/i]],
    ['indirect-draw', [/indirect.*draw/i, /draw.*indirect/i, /indirect/i]],
    ['timeline-semaphore', [/timeline.*semaphore/i, /semaphore.*timeline/i]],
    ['synchronization2', [/synchronization2/i, /sync2/i]],
    ['dynamic-rendering', [/dynamic_rendering/i]],
    ['buffer-device-address', [/buffer_device_address/i]],
    ['subgroups', [/subgroup/i]],
    ['sampler-filter', [/sampler/i, /filter/i]],
    ['wsi-presentation', [/^dEQP-VK\.wsi\./i, /present/i]]
  ];
  const selection = {};
  for (const [id, patterns] of boundaries) {
    const matches = uniqueCases.filter(test => patterns.some(pattern => pattern.test(test))).slice(0, 2);
    if (!matches.length) throw new Error(`VULKAN_CTS_REQUIRED_BOUNDARY_UNRESOLVED: ${id}`);
    selection[id] = matches;
  }
  const selectedCases = [...new Set(Object.values(selection).flat())].sort();
  await atomicWrite(outputPath, `${selectedCases.join('\n')}\n`);
  const outputSHA256 = await sha256(outputPath);
  await atomicWrite(selectionPath, `${JSON.stringify({
    schema: 1,
    ctsTag: EXPECTED.vulkanCTSTag,
    ctsCommit: EXPECTED.vulkanCTSCommit,
    mustpassRoot: 'external/vulkancts/mustpass/main',
    totalMustpassCasesObserved: uniqueCases.length,
    selection,
    selectedCaseCount: selectedCases.length,
    output: 'ssot/vulkan-required-cases.txt',
    outputSHA256
  }, null, 2)}\n`);
  await updateStackLock([[['generality', 'vulkan_required_cases_sha256'], outputSHA256]]);
  return { outputPath, outputSHA256, selectedCaseCount: selectedCases.length, totalMustpassCasesObserved: uniqueCases.length };
}

async function preflightReport() {
  await ensureVulkanRequiredCases();
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

async function phase1BuildWorker() {
  await ensureRoots();
  await mkdir(PHASE1_BUILD_LOG_ROOT, { recursive: true });
  const aemuRoot = join(BUILD, 'aemu');
  const qemuRoot = join(aemuRoot, 'external', 'qemu');
  const outRoot = join(qemuRoot, 'objs');
  const toolchainGeneratorPath = join(qemuRoot, 'android', 'scripts', 'unix', 'gen-android-sdk-toolchain.sh');
  const toolchainBackupPath = join(BUILD, 'compat', 'gen-android-sdk-toolchain.original.sh');
  await mkdir(dirname(toolchainBackupPath), { recursive: true });
  if (existsSync(toolchainBackupPath) && existsSync(toolchainGeneratorPath)) {
    const backupText = await readFile(toolchainBackupPath, 'utf8');
    const currentText = await readFile(toolchainGeneratorPath, 'utf8');
    if (backupText !== currentText && currentText.includes('26.5')) {
      await writeFile(toolchainGeneratorPath, backupText);
    }
  }
  await rm(PHASE1_AEMU_ALIAS, { recursive: true, force: true });
  await symlink(aemuRoot, PHASE1_AEMU_ALIAS, 'dir');
  const buildAemuRoot = PHASE1_AEMU_ALIAS;
  const buildQemuRoot = join(buildAemuRoot, 'external', 'qemu');
  const buildOutRoot = join(buildQemuRoot, 'objs');
  const startedAt = process.env.TFTMAC_PHASE1_BUILD_STARTED_AT ?? new Date().toISOString();
  const stackText = await readFile(join(SSOT, 'STACK.lock.yaml'), 'utf8');
  const stack = parseSimpleYamlScalars(stackText);
  if (stack.get('phase0_status') !== 'PASS') throw new Error('PHASE1_REQUIRES_PHASE0_PASS');
  const lockedQemuCommit = stack.get('aemu.qemu_commit');
  if (!lockedQemuCommit) throw new Error('PHASE1_QEMU_LOCK_MISSING');
  if (!existsSync(qemuRoot)) throw new Error(`PHASE1_QEMU_SOURCE_MISSING: ${qemuRoot}`);
  const observedQemuCommit = gitCommit(qemuRoot);
  if (observedQemuCommit !== lockedQemuCommit) {
    throw new Error(`PHASE1_QEMU_COMMIT_MISMATCH: expected ${lockedQemuCommit}, got ${observedQemuCommit}`);
  }
  const xcode = findRequiredXcode(discoverInstalledXcodes());
  if (!xcode) throw new Error(`PHASE1_XCODE_${EXPECTED.xcodeVersion}_${EXPECTED.xcodeBuild}_REQUIRED`);
  const env = {
    ...process.env,
    DEVELOPER_DIR: xcode.developerDir,
    ANDROID_SDK_ROOT: SDK,
    ANDROID_HOME: SDK,
    ANDROID_AVD_HOME: AVD_HOME,
    ANDROID_ADB_SERVER_PORT: '5040'
  };
  const ninjaCandidates = run('/usr/bin/find', [join(aemuRoot, 'prebuilts'), '-type', 'f', '-name', 'ninja', '-print'], { allowFailure: true, maxBuffer: 4 * 1024 * 1024 }).stdout
    .split(/\r?\n/).map(value => value.trim()).filter(Boolean);
  const ninjaPhysical = ninjaCandidates[0] ?? null;
  const ninjaBinary = ninjaPhysical ? ninjaPhysical.replace(aemuRoot, buildAemuRoot) : null;
  if (ninjaBinary) env.PATH = `${dirname(ninjaBinary)}:${env.PATH ?? ''}`;
  const baseState = {
    schema: 1,
    pid: process.pid,
    startedAt,
    qemuCommit: observedQemuCommit,
    xcode: { version: EXPECTED.xcodeVersion, build: EXPECTED.xcodeBuild, developerDir: xcode.developerDir },
    sourceRoot: qemuRoot,
    buildAliasRoot: buildAemuRoot,
    outRoot,
    stdoutPath: PHASE1_BUILD_STDOUT,
    stderrPath: PHASE1_BUILD_STDERR
  };
  const writeState = async state => atomicWrite(PHASE1_BUILD_STATE, `${JSON.stringify({ ...baseState, ...state }, null, 2)}\n`);
  const qtRoot = join(aemuRoot, 'prebuilts', 'android-emulator-build', 'qt');
  const qtRegularLibexec = join(qtRoot, 'darwin-aarch64', 'libexec');
  const qtNoWebLibexec = join(qtRoot, 'darwin-aarch64-nowebengine', 'libexec');
  let qtLibexecBridgeCreated = false;
  if (!existsSync(qtRegularLibexec)) {
    if (!existsSync(qtNoWebLibexec)) throw new Error(`PHASE1_QT_HOST_TOOLS_MISSING: ${qtNoWebLibexec}`);
    await symlink(qtNoWebLibexec, qtRegularLibexec, 'dir');
    qtLibexecBridgeCreated = true;
  }
  const removeQtLibexecBridge = async () => {
    if (qtLibexecBridgeCreated && existsSync(qtRegularLibexec)) {
      await rm(qtRegularLibexec, { force: true });
    }
  };
  const originalToolchainGenerator = await readFile(toolchainGeneratorPath, 'utf8');
  const originalToolchainGeneratorSHA256 = await sha256(toolchainGeneratorPath);
  await writeFile(toolchainBackupPath, originalToolchainGenerator);
  const sourceLines = originalToolchainGenerator.split(/\r?\n/);
  const patchedLines = [];
  let supportedSdkEdits = 0;
  let sdkProbeEdits = 0;
  let xcodePathEdits = 0;
  let xcodeClangEdits = 0;
  for (let index = 0; index < sourceLines.length; index += 1) {
    let line = sourceLines[index];
    if (line.includes('OSX_SDK_SUPPORTED=') && line.includes('15.2') && !line.includes('26.5')) {
      line = line.replace('15.2"', '15.2 26.5"');
      supportedSdkEdits += 1;
    }
    if (line.includes('OSX_SDK_INSTALLED_LIST=$(xcodebuild -showsdks')) {
      const indent = line.match(/^\s*/)?.[0] ?? '';
      patchedLines.push(`${indent}OSX_SDK_INSTALLED_LIST=$(xcrun --sdk macosx --show-sdk-version 2>/dev/null)`);
      index += 2;
      sdkProbeEdits += 1;
      continue;
    }
    if (line.includes('XCODE_PATH=$(xcode-select -print-path 2>/dev/null)')) {
      line = line.replace('XCODE_PATH=$(xcode-select -print-path 2>/dev/null)', 'XCODE_PATH="${DEVELOPER_DIR:-$(xcode-select -print-path 2>/dev/null)}"');
      xcodePathEdits += 1;
    }
    if (line.trim() === 'CLANG_BINDIR=$PREBUILT_TOOLCHAIN_DIR/bin') {
      line = `${line.match(/^\s*/)?.[0] ?? ''}CLANG_BINDIR="$XCODE_PATH/Toolchains/XcodeDefault.xctoolchain/usr/bin"`;
      xcodeClangEdits += 1;
    }
    patchedLines.push(line);
  }
  if (supportedSdkEdits < 1 || sdkProbeEdits < 1 || xcodePathEdits < 1 || xcodeClangEdits < 1) {
    throw new Error(`PHASE1_SDK_COMPAT_PATCH_SHAPE_CHANGED: supported=${supportedSdkEdits} probe=${sdkProbeEdits} xcode=${xcodePathEdits} clang=${xcodeClangEdits}`);
  }
  const patchedToolchainGenerator = patchedLines.join('\n');
  await writeFile(toolchainGeneratorPath, patchedToolchainGenerator);
  const patchedToolchainGeneratorSHA256 = await sha256(toolchainGeneratorPath);
  const restoreToolchainGenerator = async () => {
    await writeFile(toolchainGeneratorPath, originalToolchainGenerator);
    const restoredSHA256 = await sha256(toolchainGeneratorPath);
    if (restoredSHA256 !== originalToolchainGeneratorSHA256) {
      throw new Error(`PHASE1_TOOLCHAIN_RESTORE_FAILED: expected ${originalToolchainGeneratorSHA256}, got ${restoredSHA256}`);
    }
    return restoredSHA256;
  };
  try {
    await rm(outRoot, { recursive: true, force: true });
    const toolchainRoot = join(outRoot, 'toolchain');
    await mkdir(toolchainRoot, { recursive: true });
    const xcodeToolBin = join(xcode.developerDir, 'Toolchains', 'XcodeDefault.xctoolchain', 'usr', 'bin');
    const xcodeClang = join(xcodeToolBin, 'clang');
    const xcodeClangXX = join(xcodeToolBin, 'clang++');
    if (!existsSync(xcodeClang) || !existsSync(xcodeClangXX)) {
      throw new Error(`PHASE1_XCODE_CLANG_MISSING: ${xcodeToolBin}`);
    }
    const macosSDKPath = run('/usr/bin/xcrun', ['--sdk', 'macosx', '--show-sdk-path'], { env }).stdout.trim();
    const makeCompilerWrapper = async (name, compiler) => {
      const path = join(toolchainRoot, name);
      await writeFile(path, [
        '#!/bin/bash',
        `export SDKROOT=${JSON.stringify(macosSDKPath)}`,
        `exec ${JSON.stringify(compiler)} -mmacosx-version-min=10.14 \"$@\"`,
        ''
      ].join('\n'));
      await chmod(path, 0o755);
      return path;
    };
    const compilerWrappers = [];
    for (const name of ['cc', 'gcc', 'clang']) compilerWrappers.push(await makeCompilerWrapper(name, xcodeClang));
    for (const name of ['c++', 'g++', 'clang++']) compilerWrappers.push(await makeCompilerWrapper(name, xcodeClangXX));
    const hostToolWrappers = [];
    const makeHostToolWrapper = async (name, candidates) => {
      const executable = firstExisting(candidates);
      if (!executable) return null;
      const path = join(toolchainRoot, name);
      await writeFile(path, [
        '#!/bin/bash',
        `exec ${JSON.stringify(executable)} \"$@\"`,
        ''
      ].join('\n'));
      await chmod(path, 0o755);
      hostToolWrappers.push({ name, path, executable });
      return path;
    };
    await makeHostToolWrapper('ranlib', [join(xcodeToolBin, 'ranlib'), '/usr/bin/ranlib']);
    await makeHostToolWrapper('ar', [join(xcodeToolBin, 'ar'), '/usr/bin/ar']);
    await makeHostToolWrapper('nm', [join(xcodeToolBin, 'nm'), '/usr/bin/nm']);
    await makeHostToolWrapper('strip', [join(xcodeToolBin, 'strip'), '/usr/bin/strip']);
    await makeHostToolWrapper('ld', [join(xcodeToolBin, 'ld'), '/usr/bin/ld']);
    await makeHostToolWrapper('libtool', [join(xcodeToolBin, 'libtool'), '/usr/bin/libtool']);
    await makeHostToolWrapper('strings', [join(xcodeToolBin, 'strings'), '/usr/bin/strings']);
    await makeHostToolWrapper('otool', [join(xcodeToolBin, 'otool'), '/usr/bin/otool']);
    await makeHostToolWrapper('install_name_tool', [join(xcodeToolBin, 'install_name_tool'), '/usr/bin/install_name_tool']);
    await makeHostToolWrapper('dsymutil', [join(xcodeToolBin, 'dsymutil'), '/usr/bin/dsymutil']);
    await writeState({
      status: 'RUNNING', stage: 'BUILD',
      compatibility: {
        kind: 'temporary-host-sdk-parity',
        sdk: '26.5',
        sourceSHA256: originalToolchainGeneratorSHA256,
        patchedSHA256: patchedToolchainGeneratorSHA256,
        supportedSdkEdits,
        sdkProbeEdits,
        xcodePathEdits,
        xcodeClangEdits,
        ninjaBinary,
        ninjaCandidates: ninjaCandidates.slice(0, 20),
        compilerWrappers,
        hostToolWrappers,
        macosSDKPath,
        qtLibexecBridgeCreated,
        qtLibexecBridgeTarget: qtNoWebLibexec
      }
    });
    const buildPython = firstExisting([
      join(buildAemuRoot, 'prebuilts', 'python', 'darwin-x86', 'bin', 'python3'),
      join(buildAemuRoot, 'prebuilts', 'python', 'darwin-arm64', 'bin', 'python3')
    ]);
    if (!buildPython) throw new Error(`PHASE1_AOSP_PREBUILT_PYTHON_MISSING: ${join(aemuRoot, 'prebuilts', 'python')}`);
    const cmakeCompatLauncher = '/private/tmp/tftmac-aemu-cmake-compat.py';
    await writeFile(cmakeCompatLauncher, [
      'import argparse, sys',
      'from pathlib import Path',
      `sys.path.insert(0, ${JSON.stringify(join(buildQemuRoot, 'android', 'build', 'python'))})`,
      '_orig = argparse.ArgumentParser.parse_known_args',
      'def _parse(self, *args, **kwargs):',
      '    ns, rest = _orig(self, *args, **kwargs)',
      '    for name in ("aosp", "out", "dist"):',
      '        if hasattr(ns, name):',
      '            value = getattr(ns, name)',
      '            if isinstance(value, str): setattr(ns, name, Path(value))',
      '    return ns, rest',
      'argparse.ArgumentParser.parse_known_args = _parse',
      'from aemu.tasks.configure import ConfigureTask',
      'def _without_webengine(self): return self',
      'ConfigureTask.with_webengine = _without_webengine',
      'from aemu import cmake',
      'cmake.launch()',
      ''
    ].join('\n'));
    runInherited(buildPython, [
      cmakeCompatLauncher,
      '--aosp', buildAemuRoot,
      '--out', buildOutRoot,
      '--ccache', 'auto',
      '--task-disable', 'clean',
      '--verbose'
    ], { cwd: buildQemuRoot, env });

    await writeState({ status: 'RUNNING', stage: 'CTEST' });
    const ctestBinary = join(buildAemuRoot, 'prebuilts', 'cmake', 'darwin-x86', 'bin', 'ctest');
    if (!existsSync(ctestBinary)) throw new Error(`PHASE1_CTEST_MISSING: ${ctestBinary}`);
    runInherited(ctestBinary, ['-j8', '--output-on-failure'], { cwd: buildOutRoot, env });

    await writeState({ status: 'RUNNING', stage: 'GFXSTREAM_BUILD_CHECK' });
    runInherited(buildPython, [
      cmakeCompatLauncher,
      '--aosp', buildAemuRoot,
      '--out', buildOutRoot,
      '--gfxstream',
      '--task-disable', 'clean'
    ], { cwd: buildQemuRoot, env });

    await removeQtLibexecBridge();
    const restoredToolchainSHA256 = await restoreToolchainGenerator();
    const emulatorCandidates = run('/usr/bin/find', [outRoot, '-type', 'f', '-name', 'emulator', '-perm', '+111', '-print'], { allowFailure: true, maxBuffer: 8 * 1024 * 1024 }).stdout
      .split(/\r?\n/).map(value => value.trim()).filter(Boolean);
    const emulatorBinary = emulatorCandidates[0] ?? null;
    const artifact = {
      schema: 1,
      phase: 1,
      pass: true,
      completedAt: new Date().toISOString(),
      qemuCommit: observedQemuCommit,
      xcode: baseState.xcode,
      sourceRoot: qemuRoot,
      outRoot,
      emulatorBinary,
      checks: { build: 'PASS', ctest: 'PASS', gfxstreamBuildCheck: 'PASS', toolchainSourceRestored: restoredToolchainSHA256 === originalToolchainGeneratorSHA256 },
      hostCompatibility: {
        macosSDK: '26.5',
        originalToolchainGeneratorSHA256,
        patchedToolchainGeneratorSHA256,
        restoredToolchainSHA256
      }
    };
    await atomicWrite(join(DIAGNOSTICS, 'phase1-build.json'), `${JSON.stringify(artifact, null, 2)}\n`);
    await writeState({ status: 'SUCCEEDED', stage: 'COMPLETE', endedAt: new Date().toISOString(), emulatorBinary });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    let restoreError = null;
    try {
      await removeQtLibexecBridge();
      await restoreToolchainGenerator();
    } catch (failure) {
      restoreError = failure instanceof Error ? failure.message : String(failure);
    }
    await writeState({ status: 'FAILED', endedAt: new Date().toISOString(), error: message, restoreError });
    if (restoreError) throw new Error(`${message}; ${restoreError}`);
    throw error;
  }
}

async function phase1Build() {
  await ensureRoots();
  await mkdir(PHASE1_BUILD_LOG_ROOT, { recursive: true });
  const existing = await readPhase1BuildState();
  if (existing?.pid && pidIsAlive(existing.pid)) {
    console.log(JSON.stringify({ phase: '1-build', launched: false, alreadyRunning: true, worker: existing }, null, 2));
    return;
  }
  const startedAt = new Date().toISOString();
  const stdoutFd = openSync(PHASE1_BUILD_STDOUT, 'w');
  const stderrFd = openSync(PHASE1_BUILD_STDERR, 'w');
  try {
    const child = spawn(process.execPath, [fileURLToPath(import.meta.url), 'phase1-build-worker'], {
      cwd: REPO,
      env: { ...process.env, TFTMAC_PHASE1_BUILD_STARTED_AT: startedAt },
      detached: true,
      stdio: ['ignore', stdoutFd, stderrFd]
    });
    child.unref();
    console.log(JSON.stringify({
      phase: '1-build', launched: true, pid: child.pid, startedAt,
      sourceRoot: join(BUILD, 'aemu', 'external', 'qemu'), outRoot: join(BUILD, 'aemu', 'external', 'qemu', 'objs'),
      statePath: PHASE1_BUILD_STATE, stdoutPath: PHASE1_BUILD_STDOUT, stderrPath: PHASE1_BUILD_STDERR
    }, null, 2));
  } finally {
    closeSync(stdoutFd);
    closeSync(stderrFd);
  }
}

async function validateEngineeringMap() {
  const mapPath = join(SSOT, 'TFTMAC_ENGINEERING_MAP.sql');
  if (!existsSync(mapPath)) return { pass: false, error: 'ENGINEERING_MAP_MISSING', path: mapPath };
  const sql = await readFile(mapPath, 'utf8');
  const db = new DatabaseSync(':memory:');
  try {
    db.exec(sql);
    const foreignKeyProblems = db.prepare('PRAGMA foreign_key_check').all();
    const schemaVersion = db.prepare("SELECT value FROM map_meta WHERE key='schema_version'").get()?.value ?? null;
    const tableCount = Number(db.prepare("SELECT COUNT(*) AS count FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'").get().count);
    const viewCount = Number(db.prepare("SELECT COUNT(*) AS count FROM sqlite_master WHERE type='view'").get().count);
    const fieldMetadataCount = Number(db.prepare('SELECT COUNT(*) AS count FROM field_metadata').get().count);
    const versionCount = Number(db.prepare('SELECT COUNT(*) AS count FROM version_catalog').get().count);
    const compatibilityClaimCount = Number(db.prepare('SELECT COUNT(*) AS count FROM compatibility_claims').get().count);
    const environmentCount = Number(db.prepare('SELECT COUNT(*) AS count FROM environment_snapshots').get().count);
    const documentCount = Number(db.prepare('SELECT COUNT(*) AS count FROM source_documents').get().count);
    const deploymentCandidateCount = Number(db.prepare('SELECT COUNT(*) AS count FROM deployment_target_candidates').get().count);
    const openBlockingUnknowns = Number(db.prepare("SELECT COUNT(*) AS count FROM unknowns WHERE blocking=1 AND status IN ('OPEN','TESTING')").get().count);
    return {
      pass: foreignKeyProblems.length === 0 && schemaVersion === '3',
      path: mapPath,
      sha256: await sha256(mapPath),
      bytes: (await stat(mapPath)).size,
      schemaVersion,
      tableCount,
      viewCount,
      fieldMetadataCount,
      versionCount,
      compatibilityClaimCount,
      environmentCount,
      documentCount,
      deploymentCandidateCount,
      openBlockingUnknowns,
      foreignKeyProblems
    };
  } catch (error) {
    return { pass: false, path: mapPath, error: error instanceof Error ? error.message : String(error) };
  } finally {
    db.close();
  }
}

function directControl(action, args = []) {
  return runInherited(process.execPath, [join(REPO, 'tools', 'tftmac-direct-control.mjs'), action, ...args]);
}

async function consumeDirectControlRequest() {
  if (!existsSync(DIRECT_CONTROL_REQUEST)) return null;
  const request = JSON.parse(await readFile(DIRECT_CONTROL_REQUEST, 'utf8'));
  const allowed = new Set(['inventory', 'prepare', 'lab-selftest', 'build', 'launch-app', 'open-play-web', 'runtime-process-audit', 'cleanup-tftmac-adb-residue', 'single-runtime-preflight', 'launch-mactician-control', 'stop-mactician-control', 'mactician-runtime-audit', 'cleanup-observer-adb-5037', 'start', 'start-donor-control', 'play-action', 'play-probe', 'gles-capability-probe', 'launch-failure-probe', 'recover-anr-wait', 'logger-health', 'restart-game', 'analyze-session', 'ingest-analysis', 'trace-capabilities', 'native-trace-smoke', 'native-trace-combat', 'presentation-probe', 'window-inventory', 'fit-window', 'play-certification', 'play-diagnose', 'google-account-ui', 'image-check', 'device-profiles', 'image-upgrade-start', 'image-upgrade-status', 'launch-game', 'status', 'marker', 'game-settings','quality-report','match-boundary-probe','analyze-approx-match','ingest-approx-match', 'match-entry', 'combat-start', 'first-place', 'stop', 'package-state', 'auth-brief', 'install-diagnose', 'play-install-brief', 'play-store-repair']);
  const placementAction = /^placement-[1-8]$/.test(request?.action ?? '');
  if (!allowed.has(request?.action) && !placementAction) throw new Error(`DIRECT_CONTROL_ACTION_INVALID: ${request?.action ?? '<missing>'}`);
  await rm(DIRECT_CONTROL_REQUEST, { force: true });
  const startedAt = new Date().toISOString();
  const requestArgs = Array.isArray(request?.args) ? request.args.map(value => String(value)).slice(0, 8) : [];
  const result = run(process.execPath, [join(REPO, 'tools', 'tftmac-direct-control.mjs'), request.action, ...requestArgs], {
    allowFailure: true,
    timeout: 900000,
    maxBuffer: 128 * 1024 * 1024
  });
  let parsed = null;
  try { parsed = JSON.parse(result.stdout); } catch {}
  return {
    action: request.action,
    startedAt,
    endedAt: new Date().toISOString(),
    exitCode: result.status,
    result: parsed,
    stdout: parsed ? null : result.stdout.trim() || null,
    stderr: result.stderr.trim() || null
  };
}

async function status() {
  await ensureRoots();
  const directControlResult = await consumeDirectControlRequest();
  if (directControlResult) {
    console.log(JSON.stringify({
      appRoot: APP,
      buildRoot: BUILD,
      runtimeRoot: RUNTIME,
      repository: REPO,
      directControlResult
    }, null, 2));
    return;
  }
  const paths = [
    'STACK.lock.yaml', 'host-preflight.json', 'android-sdk-packages.txt', 'tool-versions.txt',
    'source-hashes.txt', 'guestangle-authority.json', 'vulkan-required-cases.txt', 'preflight-report.md',
    'upstreams-aemu.lock.xml', 'vulkaninfo-summary.txt', 'TFTMAC_ENGINEERING_MAP.sql'
  ];
  const artifacts = {};
  for (const name of paths) {
    const path = join(SSOT, name);
    artifacts[name] = existsSync(path) ? { exists: true, bytes: (await stat(path)).size, sha256: await sha256(path) } : { exists: false };
  }
  const sourceWorker = await readSourceWorkerState();
  const sourceWorkerAlive = Boolean(sourceWorker?.pid && pidIsAlive(sourceWorker.pid));
  const sourceWorkerObservedStatus = sourceWorker?.status === 'RUNNING' && !sourceWorkerAlive
    ? 'INTERRUPTED'
    : sourceWorker?.status ?? 'NOT_STARTED';
  const phase1BuildWorker = await readPhase1BuildState();
  const phase1BuildAlive = Boolean(phase1BuildWorker?.pid && pidIsAlive(phase1BuildWorker.pid));
  const phase1BuildObservedStatus = phase1BuildWorker?.status === 'RUNNING' && !phase1BuildAlive
    ? 'INTERRUPTED'
    : phase1BuildWorker?.status ?? 'NOT_STARTED';
  let phase1BuildLogTail = null;
  if (phase1BuildWorker && phase1BuildObservedStatus !== 'RUNNING') {
    const tail = async path => {
      if (!existsSync(path)) return null;
      const text = await readFile(path, 'utf8');
      return text.slice(-8192);
    };
    const rebuildPath = join(BUILD, 'aemu', 'external', 'qemu', 'android', 'rebuild.sh');
    let rebuildSnippet = null;
    if (existsSync(rebuildPath)) {
      const lines = (await readFile(rebuildPath, 'utf8')).split(/\r?\n/);
      rebuildSnippet = lines.slice(38, 62).map((text, index) => ({ line: index + 39, text }));
    }
    const filteredSourceLines = async (path, pattern, maximum = 120) => {
      if (!existsSync(path)) return null;
      return (await readFile(path, 'utf8')).split(/\r?\n/)
        .map((text, index) => ({ line: index + 1, text }))
        .filter(item => pattern.test(item.text))
        .slice(0, maximum);
    };
    const phase1AliasPython = firstExisting([
      join(PHASE1_AEMU_ALIAS, 'prebuilts', 'python', 'darwin-x86', 'bin', 'python3'),
      join(PHASE1_AEMU_ALIAS, 'prebuilts', 'python', 'darwin-arm64', 'bin', 'python3')
    ]);
    const cmakeHelp = phase1AliasPython ? run(phase1AliasPython, [
      join(PHASE1_AEMU_ALIAS, 'external', 'qemu', 'android', 'build', 'python', 'cmake.py'), '--help'
    ], { allowFailure: true, maxBuffer: 4 * 1024 * 1024 }) : null;
    phase1BuildLogTail = {
      stdout: await tail(PHASE1_BUILD_STDOUT),
      stderr: await tail(PHASE1_BUILD_STDERR),
      rebuildSnippet,
      toolchainGenerator: await filteredSourceLines(
        join(BUILD, 'aemu', 'external', 'qemu', 'android', 'scripts', 'unix', 'gen-android-sdk-toolchain.sh'),
        /AOSP|aosp|gcc|g\+\+|clang|xcrun|ln |toolchain|realpath|dirname|SDK|sdk|xcodebuild|showsdks|SUPPORTED/
      ),
      cmakeDriver: await filteredSourceLines(
        join(BUILD, 'aemu', 'external', 'qemu', 'android', 'build', 'python', 'cmake.py'),
        /aosp|AOSP|out-dir|argparse|ccache|toolchain/
      ),
      cmakeHelp: cmakeHelp ? { status: cmakeHelp.status, stdout: cmakeHelp.stdout, stderr: cmakeHelp.stderr } : null,
      cmakeAospParserUse: await filteredSourceLines(
        join(BUILD, 'aemu', 'external', 'qemu', 'android', 'build', 'python', 'cmake.py'),
        /aosp|Path\(|argument_parser|ArgumentParser|add_argument/,
        160
      ),
      cmakeLauncherHead: (() => null)(),
      cmakeModuleAospUse: await filteredSourceLines(
        join(BUILD, 'aemu', 'external', 'qemu', 'android', 'build', 'python', 'aemu', 'cmake.py'),
        /aosp|Path\(|add_argument|ArgumentParser|parser|args\./,
        220
      ),
      sdkGateSnippet: null,
      phase1FilesystemProbe: {
        toolchain: run('/bin/ls', ['-la', join(BUILD, 'aemu', 'external', 'qemu', 'objs', 'toolchain')], { allowFailure: true, maxBuffer: 4 * 1024 * 1024 }),
        clangHosts: run('/usr/bin/find', [join(BUILD, 'aemu', 'prebuilts', 'clang', 'host'), '-maxdepth', '4', '-type', 'f', '-name', 'clang', '-print'], { allowFailure: true, maxBuffer: 4 * 1024 * 1024 }),
        ninja: run('/usr/bin/find', [join(BUILD, 'aemu', 'prebuilts'), '-type', 'f', '-name', 'ninja', '-print'], { allowFailure: true, maxBuffer: 4 * 1024 * 1024 }),
        qtTools: run('/usr/bin/find', [join(BUILD, 'aemu', 'prebuilts', 'android-emulator-build', 'qt'), '-maxdepth', '5', '-type', 'f', '(', '-name', 'uic', '-o', '-name', 'moc', '-o', '-name', 'qmake', '-o', '-name', 'qtpaths', ')', '-print'], { allowFailure: true, maxBuffer: 8 * 1024 * 1024 }),
        qtDirs: run('/usr/bin/find', [join(BUILD, 'aemu', 'prebuilts', 'android-emulator-build', 'qt'), '-maxdepth', '2', '-type', 'd', '-print'], { allowFailure: true, maxBuffer: 8 * 1024 * 1024 }),
        qtWebengineLogic: run('/usr/bin/grep', ['-RniE', 'noqtwebengine|QTWEBENGINE|qtwebengine', join(BUILD, 'aemu', 'external', 'qemu', 'android', 'build', 'python', 'aemu')], { allowFailure: true, maxBuffer: 8 * 1024 * 1024 }),
        qtConfigureSnippet: run('/usr/bin/sed', ['-n', '160,185p', join(BUILD, 'aemu', 'external', 'qemu', 'android', 'build', 'python', 'aemu', 'tasks', 'configure.py')], { allowFailure: true, maxBuffer: 2 * 1024 * 1024 })
      }
    };
    {
      const generatorPath = join(BUILD, 'aemu', 'external', 'qemu', 'android', 'scripts', 'unix', 'gen-android-sdk-toolchain.sh');
      if (existsSync(generatorPath)) {
        const lines = (await readFile(generatorPath, 'utf8')).split(/\r?\n/);
        phase1BuildLogTail.sdkGateSnippet = lines.slice(512, 566).map((text, index) => ({ line: index + 513, text }));
        phase1BuildLogTail.wrapperProgramSnippet = lines.slice(150, 401).map((text, index) => ({ line: index + 151, text }));
        phase1BuildLogTail.wrapperGeneratorSnippet = lines.slice(400, 475).map((text, index) => ({ line: index + 401, text }));
      }
    }
    {
      const cmakeLauncherPath = join(BUILD, 'aemu', 'external', 'qemu', 'android', 'build', 'python', 'cmake.py');
      if (existsSync(cmakeLauncherPath)) {
        const text = await readFile(cmakeLauncherPath, 'utf8');
        phase1BuildLogTail.cmakeLauncherHead = text.split(/\r?\n/).slice(0, 260).map((line, index) => ({ line: index + 1, text: line }));
      }
    }
  }
  const engineeringMap = await validateEngineeringMap();
  console.log(JSON.stringify({
    appRoot: APP,
    buildRoot: BUILD,
    buildRootSource: process.env.TFTMAC_BUILD_ROOT ? 'TFTMAC_BUILD_ROOT' : 'default-external',
    runtimeRoot: RUNTIME,
    runtimeRootSource: process.env.TFTMAC_RUNTIME_ROOT ? 'TFTMAC_RUNTIME_ROOT' : 'default-external',
    repository: REPO,
    directControlResult,
    sourceWorker: sourceWorker ? { ...sourceWorker, alive: sourceWorkerAlive, observedStatus: sourceWorkerObservedStatus } : null,
    phase1BuildWorker: phase1BuildWorker ? { ...phase1BuildWorker, alive: phase1BuildAlive, observedStatus: phase1BuildObservedStatus } : null,
    phase1BuildLogTail,
    engineeringMap,
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
    case 'phase0-source-worker': await phase0SourceWorker(); break;
    case 'phase0-authority': await importAuthorityFiles(); break;
    case 'phase0-policy': await phase0Policy(); break;
    case 'phase0-report': await preflightReport(); break;
    case 'phase0-xcode-discovery': await discoverXcodes(); break;
    case 'phase1-build': await phase1Build(); break;
    case 'phase1-build-worker': await phase1BuildWorker(); break;
    case 'cleanup-sandbox-bootstrap': await cleanupSandboxBootstrap(); break;
    case 'direct-inventory': directControl('inventory'); break;
    case 'direct-build': directControl('build'); break;
    case 'direct-launch-app': directControl('launch-app'); break;
    case 'direct-start': directControl('start'); break;
    case 'direct-play-action': directControl('play-action'); break;
    case 'direct-launch-game': directControl('launch-game'); break;
    case 'direct-status': directControl('status'); break;
    case 'direct-stop': directControl('stop'); break;
    case 'direct-package-state': directControl('package-state'); break;
    case 'status': await status(); break;
    default: die(`unknown action: ${action}`);
  }
} catch (error) {
  die(error instanceof Error ? error.message : String(error));
}
