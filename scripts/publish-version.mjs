#!/usr/bin/env node
/**
 * Append a release to CloudronVersions.json with a resolved manifest + dockerImage.
 * Cloudron's `cloudron versions add` only reads the image from a prior `cloudron build` config,
 * so CI uses this script with:  node scripts/publish-version.mjs 'ghcr.io/org/repo:0.82.1'
 */
import fs from 'node:fs'
import path from 'node:path'
import manifestFormat from '@cloudron/manifest-format'
const root = process.cwd()
const image = process.argv[2]
if (!image) {
  console.error('Usage: node scripts/publish-version.mjs <docker-image:tag>')
  process.exit(1)
}

function parseChangelog (file, version) {
  const data = fs.readFileSync(file, 'utf8')
  if (!data) return null
  const lines = data.split('\n')
  const v = String(version).replace(/-.*/, '')
  let i
  for (i = 0; i < lines.length; i++) {
    if (lines[i] === `[${v}]`) break
  }
  if (i >= lines.length) {
    return null
  }
  let changelog = ''
  for (i = i + 1; i < lines.length; i++) {
    if (lines[i] === '') continue
    if (lines[i][0] === '[') break
    changelog += lines[i] + '\n'
  }
  return changelog
}

const manifestFilePath = path.join(root, 'CloudronManifest.json')
const result = manifestFormat.parseFile(manifestFilePath)
if (result.error) {
  console.error(result.error.message)
  process.exit(1)
}
const manifest = { ...result.manifest }
const baseDir = path.dirname(manifestFilePath)

if (String(manifest.description).startsWith('file://')) {
  let p = String(manifest.description).slice(7)
  p = path.isAbsolute(p) ? p : path.join(baseDir, p)
  manifest.description = fs.readFileSync(p, 'utf8')
}
if (manifest.changelog && String(manifest.changelog).startsWith('file://')) {
  let p = String(manifest.changelog).slice(7)
  p = path.isAbsolute(p) ? p : path.join(baseDir, p)
  manifest.changelog = parseChangelog(p, manifest.version)
  if (!manifest.changelog) {
    console.error('Bad CHANGELOG: missing block for', manifest.version)
    process.exit(1)
  }
}
if (manifest.postInstallMessage && String(manifest.postInstallMessage).startsWith('file://')) {
  let p = String(manifest.postInstallMessage).slice(7)
  p = path.isAbsolute(p) ? p : path.join(baseDir, p)
  manifest.postInstallMessage = fs.readFileSync(p, 'utf8')
}

if (String(image).indexOf('docker.io/') === 0) {
  manifest.dockerImage = image.slice('docker.io/'.length)
} else {
  manifest.dockerImage = image
}

const versionsFilePath = path.join(root, 'CloudronVersions.json')
const data = JSON.parse(fs.readFileSync(versionsFilePath, 'utf8'))
const err = manifestFormat.parseVersions(data)
if (err) {
  console.error('CloudronVersions.json:', err)
  process.exit(1)
}

if (data.versions[manifest.version]) {
  console.error(`Version ${manifest.version} is already in CloudronVersions.json`)
  process.exit(1)
}

const now = new Date().toUTCString()
data.versions[manifest.version] = {
  manifest,
  creationDate: now,
  ts: now,
  publishState: 'published',
}

const check = manifestFormat.checkVersionsRequirements(manifest)
if (check) {
  console.error(check)
  process.exit(1)
}

fs.writeFileSync(versionsFilePath, JSON.stringify(data, null, 4) + '\n')
console.log(`Updated CloudronVersions.json: ${manifest.version} -> ${manifest.dockerImage}`)
