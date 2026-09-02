#!/usr/bin/env node

import { readFileSync, writeFileSync } from "node:fs";
import { createHash, createPrivateKey, sign, X509Certificate } from "node:crypto";

const APK_SIGNATURE_SCHEME_V2_ID = 0x7109871a;
const RSA_PKCS1_SHA256_ID = 0x0103;
const EOCD_SIGNATURE = 0x06054b50;
const APK_SIGNING_BLOCK_MAGIC = Buffer.from("APK Sig Block 42", "ascii");
const CHUNK_SIZE = 1024 * 1024;

function fail(message) {
  throw new Error(`APK v2 signing failed: ${message}`);
}

function u32(value) {
  const result = Buffer.alloc(4);
  result.writeUInt32LE(value >>> 0);
  return result;
}

function u64(value) {
  const result = Buffer.alloc(8);
  result.writeBigUInt64LE(BigInt(value));
  return result;
}

function lengthPrefixed(bytes) {
  return Buffer.concat([u32(bytes.length), bytes]);
}

function findEocd(apk) {
  const minimumOffset = Math.max(0, apk.length - 65_557);
  for (let offset = apk.length - 22; offset >= minimumOffset; offset -= 1) {
    if (apk.readUInt32LE(offset) !== EOCD_SIGNATURE) continue;
    const commentLength = apk.readUInt16LE(offset + 20);
    if (offset + 22 + commentLength === apk.length) return offset;
  }
  fail("ZIP end-of-central-directory record was not found");
}

function chunkedContentDigest(sections) {
  const digests = [];
  for (const section of sections) {
    for (let offset = 0; offset < section.length; offset += CHUNK_SIZE) {
      const chunk = section.subarray(offset, Math.min(section.length, offset + CHUNK_SIZE));
      digests.push(createHash("sha256")
        .update(Buffer.from([0xa5]))
        .update(u32(chunk.length))
        .update(chunk)
        .digest());
    }
  }
  return createHash("sha256")
    .update(Buffer.from([0x5a]))
    .update(u32(digests.length))
    .update(Buffer.concat(digests))
    .digest();
}

function parseArguments(argv) {
  const values = new Map();
  for (let index = 2; index < argv.length; index += 2) {
    values.set(argv[index], argv[index + 1]);
  }
  for (const name of ["--input", "--key", "--cert", "--output"]) {
    if (!values.get(name)) fail(`missing ${name}`);
  }
  return values;
}

const args = parseArguments(process.argv);
const apk = readFileSync(args.get("--input"));
const eocdOffset = findEocd(apk);
const centralDirectoryOffset = apk.readUInt32LE(eocdOffset + 16);
const centralDirectorySize = apk.readUInt32LE(eocdOffset + 12);
if (centralDirectoryOffset + centralDirectorySize !== eocdOffset) {
  fail("ZIP64 or a non-contiguous central directory is not supported");
}

const beforeCentralDirectory = apk.subarray(0, centralDirectoryOffset);
const centralDirectory = apk.subarray(centralDirectoryOffset, eocdOffset);
const digestEocd = Buffer.from(apk.subarray(eocdOffset));
// Verification removes the signing block and rewrites this field to the
// signing-block start before calculating the protected content digest.
digestEocd.writeUInt32LE(centralDirectoryOffset, 16);
const contentDigest = chunkedContentDigest([
  beforeCentralDirectory,
  centralDirectory,
  digestEocd,
]);

const certificate = new X509Certificate(readFileSync(args.get("--cert")));
const certificateDer = certificate.raw;
const publicKeyDer = certificate.publicKey.export({ type: "spki", format: "der" });
const digestRecord = Buffer.concat([u32(RSA_PKCS1_SHA256_ID), lengthPrefixed(contentDigest)]);
const signedData = Buffer.concat([
  lengthPrefixed(lengthPrefixed(digestRecord)),
  lengthPrefixed(lengthPrefixed(certificateDer)),
  lengthPrefixed(Buffer.alloc(0)),
]);
const privateKey = createPrivateKey(readFileSync(args.get("--key")));
const signature = sign("sha256", signedData, privateKey);
const signatureRecord = Buffer.concat([u32(RSA_PKCS1_SHA256_ID), lengthPrefixed(signature)]);
const signer = Buffer.concat([
  lengthPrefixed(signedData),
  lengthPrefixed(lengthPrefixed(signatureRecord)),
  lengthPrefixed(publicKeyDer),
]);
const v2Value = lengthPrefixed(lengthPrefixed(signer));
const pair = Buffer.concat([
  u64(4 + v2Value.length),
  u32(APK_SIGNATURE_SCHEME_V2_ID),
  v2Value,
]);
const blockSize = pair.length + 24;
const signingBlock = Buffer.concat([
  u64(blockSize),
  pair,
  u64(blockSize),
  APK_SIGNING_BLOCK_MAGIC,
]);

const outputEocd = Buffer.from(apk.subarray(eocdOffset));
outputEocd.writeUInt32LE(centralDirectoryOffset + signingBlock.length, 16);
const output = Buffer.concat([
  beforeCentralDirectory,
  signingBlock,
  centralDirectory,
  outputEocd,
]);
writeFileSync(args.get("--output"), output, { mode: 0o644 });
