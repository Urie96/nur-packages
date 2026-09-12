#!/usr/bin/env node
// generate.mjs — build registry.json for pkgs/piExtensions
//
// Inspired by github:Leoguy77/pi-packages.nix, but scoped to a curated list so
// nur-packages stays a personal repo instead of an 8000-package mirror.
//
// For every tracked npm package we record:
//   name, version, tarball, hash (npm dist.integrity, SRI), tier,
//   piManifest, dependencies, peerDependencies, keywords, description
//
// Packages with runtime dependencies (Tier B) additionally get a
// package-lock.json stored at pkgs/piExtensions/<key>/package-lock.json.
// lib/mkPiPackage.nix feeds that lockfile to pkgs.importNpmLock, so no
// npmDepsHash has to be maintained by hand.
//
// Usage:
//   just update piExtensions        # via pkgs/updater (runs with --prune)
//
//   node pkgs/piExtensions/generate.mjs                 # use registry.names
//   node pkgs/piExtensions/generate.mjs --all           # crawl keywords:pi-package
//   node pkgs/piExtensions/generate.mjs --names a,b,c   # explicit names
//   node pkgs/piExtensions/generate.mjs --force-locks   # rebuild lockfiles
//   node pkgs/piExtensions/generate.mjs --no-locks      # metadata only
//   node pkgs/piExtensions/generate.mjs --prune         # drop untracked entries
//   node pkgs/piExtensions/generate.mjs --locked        # CI check, no writes
//
// Requires nodejs (>=18, for fetch) and npm on PATH; `pkgs/updater` bundles
// nodejs so `just update piExtensions` works out of the box.

import { execFileSync, execSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, rmSync, rmdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const REGISTRY_PATH = join(HERE, 'registry.json');
const NAMES_PATH = join(HERE, 'registry.names');
const NPM_REGISTRY = 'https://registry.npmjs.org';
const SEARCH_URL = `${NPM_REGISTRY}/-/v1/search`;
const SEARCH_KEYWORD = process.env.PI_KEYWORD || 'pi-package';
const TMP = process.env.PI_TMP || '/tmp/pi-registry-gen';
const NPM_CACHE = join(TMP, 'npm-cache');

// ---------------------------------------------------------------- args

function parseArgs(argv) {
  const opts = {
    all: false,
    names: null,
    forceLocks: false,
    locks: true,
    prune: false,
    locked: false,
    concurrency: parseInt(process.env.CONCURRENCY || '4', 10),
    help: false,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--all') opts.all = true;
    else if (a === '--force-locks') opts.forceLocks = true;
    else if (a === '--no-locks') opts.locks = false;
    else if (a === '--prune') opts.prune = true;
    else if (a === '--locked') opts.locked = true;
    else if (a === '--help' || a === '-h') opts.help = true;
    else if (a === '--names') opts.names = argv[++i];
    else if (a.startsWith('--names=')) opts.names = a.slice('--names='.length);
    else if (a.startsWith('--concurrency=')) opts.concurrency = parseInt(a.split('=')[1], 10);
    else {
      console.error(`Unknown argument: ${a}`);
      process.exit(2);
    }
  }
  return opts;
}

const USAGE = `generate.mjs — regenerate pkgs/piExtensions/registry.json

Options:
  --all               crawl npm for every package tagged "keywords:${SEARCH_KEYWORD}"
  --names a,b,c       track an explicit comma-separated list of npm packages
  --no-locks          only refresh registry.json, never run npm
  --force-locks       regenerate lockfiles even if they already exist
  --prune             drop registry entries that are no longer tracked
  --locked            check that registry.json/lockfiles are current; exit 1 if not
  --concurrency N     parallel npm/registry requests (default 4)
  -h, --help          show this help

registry.names entries may pin a version with "name@1.2.3"; a bare "name"
tracks npm's latest tag.`;

// ---------------------------------------------------------------- http

let lastRequest = 0;
const MIN_GAP_MS = 200;

async function rateLimit() {
  const wait = MIN_GAP_MS - (Date.now() - lastRequest);
  if (wait > 0) await new Promise((r) => setTimeout(r, wait));
  lastRequest = Date.now();
}

async function fetchJSON(url, retries = 3) {
  for (let attempt = 0; attempt < retries; attempt++) {
    await rateLimit();
    try {
      const res = await fetch(url, { headers: { accept: 'application/json' } });
      if (res.status === 429 || res.status >= 500) {
        const wait = Math.min(3000 * 2 ** attempt, 30000);
        process.stderr.write(`  HTTP ${res.status}, retrying in ${wait}ms...\n`);
        await new Promise((r) => setTimeout(r, wait));
        continue;
      }
      if (!res.ok) throw new Error(`HTTP ${res.status}: ${url}`);
      return await res.json();
    } catch (err) {
      if (attempt === retries - 1) throw err;
      const wait = Math.min(1500 * 2 ** attempt, 10000);
      process.stderr.write(`  ${err.message}, retrying in ${wait}ms...\n`);
      await new Promise((r) => setTimeout(r, wait));
    }
  }
  throw new Error(`giving up on ${url}`);
}

// ---------------------------------------------------------------- metadata

const keyFor = (npmName) => npmName.replace(/@/g, '').replace(/\//g, '-');

// Parse a registry.names line: "name", "name@1.2.3" or "@scope/name@1.2.3".
function parseSpec(text) {
  const spec = text.replace(/#.*$/, '').trim();
  if (!spec) return null;
  const at = spec.lastIndexOf('@');
  if (at > 0) return { name: spec.slice(0, at), version: spec.slice(at + 1) };
  return { name: spec, version: null };
}

const encodeName = (name) =>
  name.startsWith('@')
    ? '@' + encodeURIComponent(name.slice(1).split('/')[0]) + '%2F' + encodeURIComponent(name.split('/')[1])
    : encodeURIComponent(name);

async function getPackageMetadata(npmName, wanted) {
  const meta = await fetchJSON(`${NPM_REGISTRY}/${encodeName(npmName)}`);
  const version = wanted || meta['dist-tags']?.latest;
  if (!version) return null;

  const v = meta.versions?.[version];
  if (!v) throw new Error(`version ${version} not found on npm`);

  const dependencies = v.dependencies || {};
  return {
    name: v.name || npmName,
    version,
    tarball: v.dist?.tarball,
    hash: v.dist?.integrity,
    tier: Object.keys(dependencies).length === 0 ? 'A' : 'B',
    piManifest: v.pi || {},
    dependencies,
    peerDependencies: v.peerDependencies || {},
    keywords: v.keywords || [],
    description: v.description || '',
  };
}

async function searchAll() {
  const pageSize = 250;
  const results = [];
  let from = 0;
  let total = null;
  let emptyPages = 0;

  while (total === null || from < total) {
    if (emptyPages > 3) break;
    const url = `${SEARCH_URL}?text=keywords:${encodeURIComponent(SEARCH_KEYWORD)}&size=${pageSize}&from=${from}`;
    process.stderr.write(`search from=${from}...\n`);
    const page = await fetchJSON(url);
    total = page.total ?? total;
    const objects = page.objects || [];
    if (objects.length === 0) {
      emptyPages++;
    } else {
      emptyPages = 0;
      for (const o of objects) if (o.package?.name) results.push(o.package.name);
    }
    from += pageSize;
    await new Promise((r) => setTimeout(r, 300));
  }
  return results;
}

// ---------------------------------------------------------------- lockfiles

// Version recorded at the root of an existing lockfile, or null.
function lockVersion(lockPath) {
  if (!existsSync(lockPath)) return null;
  try {
    const lock = JSON.parse(readFileSync(lockPath, 'utf8'));
    return lock.packages?.['']?.version ?? lock.version ?? null;
  } catch {
    return null;
  }
}

async function generateLockfile(key, entry) {
  const pkgDir = join(HERE, key);
  const lockPath = join(pkgDir, 'package-lock.json');
  const workDir = join(TMP, key);
  const pkgRoot = join(workDir, 'pkg');

  rmSync(workDir, { recursive: true, force: true });
  mkdirSync(pkgRoot, { recursive: true });

  try {
    const res = await fetch(entry.tarball);
    if (!res.ok) throw new Error(`HTTP ${res.status} for tarball`);
    writeFileSync(join(workDir, 'pkg.tgz'), Buffer.from(await res.arrayBuffer()));
    execFileSync('tar', ['-xzf', join(workDir, 'pkg.tgz'), '--strip-components=1', '-C', pkgRoot]);

    // Strip things standalone npm cannot resolve / does not need.
    const pjPath = join(pkgRoot, 'package.json');
    const pj = JSON.parse(readFileSync(pjPath, 'utf8'));
    for (const field of ['dependencies', 'devDependencies', 'peerDependencies', 'optionalDependencies']) {
      if (!pj[field]) continue;
      for (const [dep, range] of Object.entries(pj[field])) {
        if (typeof range === 'string' && range.startsWith('workspace:')) delete pj[field][dep];
      }
    }
    delete pj.devDependencies;
    delete pj.devEngines;
    writeFileSync(pjPath, JSON.stringify(pj, null, 2) + '\n');

    const npm = (args) =>
      execFileSync('npm', args, {
        cwd: pkgRoot,
        env: { ...process.env, HOME: workDir, npm_config_cache: NPM_CACHE },
        stdio: ['ignore', 'ignore', 'pipe'],
        timeout: 300000,
      });

    // 1. Resolve the tree, 2. full install to fill in integrity hashes.
    npm(['install', '--package-lock-only', '--ignore-scripts', '--no-audit', '--no-fund', '--legacy-peer-deps', '--ignore-platform', '--loglevel=error']);
    npm(['install', '--ignore-scripts', '--no-audit', '--no-fund', '--legacy-peer-deps', '--ignore-platform', '--loglevel=error']);
    rmSync(join(pkgRoot, 'node_modules'), { recursive: true, force: true });

    mkdirSync(pkgDir, { recursive: true });
    writeFileSync(lockPath, readFileSync(join(pkgRoot, 'package-lock.json')));
    process.stderr.write(`  lockfile ok (${key})\n`);
    return true;
  } catch (err) {
    process.stderr.write(`  lockfile FAILED (${key}): ${err.message.split('\n')[0]}\n`);
    return false;
  } finally {
    rmSync(workDir, { recursive: true, force: true });
  }
}

// ---------------------------------------------------------------- main

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (opts.help) {
    process.stdout.write(USAGE);
    return;
  }

  let specs;
  if (opts.names) {
    specs = opts.names.split(',').map(parseSpec).filter(Boolean);
  } else if (opts.all) {
    const all = await searchAll();
    process.stderr.write(`found ${all.length} packages with keywords:${SEARCH_KEYWORD}\n`);
    specs = all.map((name) => ({ name, version: null }));
  } else {
    if (!existsSync(NAMES_PATH)) {
      console.error(`Missing ${NAMES_PATH}; create it or pass --all/--names.`);
      process.exit(1);
    }
    specs = readFileSync(NAMES_PATH, 'utf8').split('\n').map(parseSpec).filter(Boolean);
  }
  // De-duplicate by npm name (later entries win) and keep output deterministic.
  specs = [...new Map(specs.map((s) => [s.name, s])).values()].sort((a, b) => a.name.localeCompare(b.name));
  const names = specs;

  const existing = existsSync(REGISTRY_PATH)
    ? JSON.parse(readFileSync(REGISTRY_PATH, 'utf8')).packages || {}
    : {};
  const packages = { ...existing };
  const trackedKeys = new Set(names.map((s) => keyFor(s.name)));

  let done = 0;
  let failed = 0;
  const lockJobs = [];

  for (let i = 0; i < names.length; i += opts.concurrency) {
    const batch = names.slice(i, i + opts.concurrency);
    await Promise.all(
      batch.map(async (spec) => {
        const npmName = spec.name;
        const key = keyFor(npmName);
        done++;
        try {
          const entry = await getPackageMetadata(npmName, spec.version);
          if (!entry || !entry.tarball || !entry.hash) throw new Error('incomplete npm metadata');
          packages[key] = entry;
          process.stderr.write(`[${done}/${names.length}] ${npmName}@${entry.version} (tier ${entry.tier})\n`);

          if (entry.tier === 'B' && opts.locks) {
            const lockPath = join(HERE, key, 'package-lock.json');
            if (opts.forceLocks || lockVersion(lockPath) !== entry.version) {
              lockJobs.push([key, entry]);
            }
          }
        } catch (err) {
          failed++;
          process.stderr.write(`[${done}/${names.length}] ${npmName} FAILED: ${err.message}\n`);
        }
      }),
    );
  }

  if (opts.prune) {
    for (const key of Object.keys(packages)) {
      if (trackedKeys.has(key)) continue;
      delete packages[key];
      // Drop the generated lockfile too; keep the directory if anything else
      // (e.g. a hand-written helper) lives in it. Never touch the working tree
      // in --locked (CI check) mode.
      if (!opts.locked) {
        const lockDir = join(HERE, key);
        rmSync(join(lockDir, 'package-lock.json'), { force: true });
        try {
          rmdirSync(lockDir);
        } catch {
          /* directory not empty */
        }
      }
      process.stderr.write(`pruned ${key}\n`);
    }
  }

  // Keep registry.json stable & diff-friendly.
  const sorted = Object.fromEntries(Object.entries(packages).sort(([a], [b]) => a.localeCompare(b)));
  const nextContent = JSON.stringify({ packages: sorted }, null, 2) + '\n';

  if (opts.locked) {
    const current = existsSync(REGISTRY_PATH) ? readFileSync(REGISTRY_PATH, 'utf8') : '';
    const problems = [];
    if (failed) problems.push(`${failed} package(s) could not be resolved`);
    if (current !== nextContent) problems.push('registry.json is out of date');
    for (const [key, entry] of Object.entries(sorted)) {
      if (entry.tier === 'B' && lockVersion(join(HERE, key, 'package-lock.json')) !== entry.version) {
        problems.push(`${key}: missing or stale package-lock.json`);
      }
    }
    if (problems.length) {
      console.error(problems.map((p) => `  - ${p}`).join('\n'));
      process.exit(1);
    }
    console.error('registry.json is up to date');
    return;
  }

  writeFileSync(REGISTRY_PATH, nextContent);

  if (lockJobs.length) {
    process.stderr.write(`\ngenerating ${lockJobs.length} lockfile(s)...\n`);
    for (let i = 0; i < lockJobs.length; i += opts.concurrency) {
      await Promise.all(lockJobs.slice(i, i + opts.concurrency).map(([key, entry]) => generateLockfile(key, entry)));
    }
  }

  const tierA = Object.values(sorted).filter((e) => e.tier === 'A').length;
  const tierB = Object.values(sorted).filter((e) => e.tier === 'B').length;
  process.stderr.write(`\nregistry.json: ${Object.keys(sorted).length} packages (${tierA} tier A, ${tierB} tier B)`);
  if (failed) process.stderr.write(`, ${failed} failed`);
  process.stderr.write('\n');
}

main().catch((err) => {
  console.error('Fatal:', err);
  process.exit(1);
});
