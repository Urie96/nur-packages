# piExtensions

pi.dev extensions sourced from npm, driven by a generated registry instead of a
hand-written `default.nix` per plugin. Same idea as
[`pi-packages.nix`](https://github.com/Leoguy77/pi-packages.nix), scoped to a
curated list.

## Layout

| File | Role |
| ---- | ---- |
| `registry.names` | input: one npm package per line, `name` or `name@1.2.3` |
| `generate.mjs` | generator: writes `registry.json` and Tier B lockfiles |
| `update.py` | glue so `pkgs/updater` / `just update piExtensions` drives the generator |
| `registry.json` | generated manifest (name, version, tarball, SRI hash, tier, deps) |
| `lib/mkPiPackage.nix` | builder: Tier A unpack / Tier B `buildNpmPackage` |
| `<key>/package-lock.json` | generated lockfile for packages with dependencies |

`key` is the npm name with `@` and `/` replaced by `-`
(`@acme/pi-x` → `acme-pi-x`).

## Adding a plugin

```bash
echo 'some-pi-plugin' >> pkgs/piExtensions/registry.names
just update piExtensions
nix build .#legacyPackages.x86_64-linux.piExtensions.some-pi-plugin
```

If the package has runtime dependencies, the generator downloads it and produces
`pkgs/piExtensions/some-pi-plugin/package-lock.json` automatically.

## Updating

```bash
just update piExtensions
```

`pkgs/piExtensions/update.py` makes the existing `pkgs/updater` treat this
directory like any other package, so it re-resolves every entry in
`registry.names` against npm:

- bare `name` → bumps to npm's `latest`, regenerating the lockfile when the
  version changed;
- `name@1.2.3` → stays pinned;
- entries removed from `registry.names` → dropped from `registry.json` (and
  their generated lockfile directory is deleted).

The updater package bundles `nodejs`, so no extra tooling is needed. There is no
`npmDepsHash` to maintain either: `lib/mkPiPackage.nix` feeds the lockfile to
`pkgs.importNpmLock`.

Then build and commit:

```bash
nix build .#legacyPackages.x86_64-linux.piExtensions.all
git commit -am "chore(piExtensions): update registry"
```

CI then builds and pushes the derivations to the cachix cache via `build.yml`
(`recurseForDerivations = true` makes `ci.nix` pick up every plugin).

## Generator flags

`generate.mjs` can also be run directly (e.g. from CI or for debugging):

```bash
node pkgs/piExtensions/generate.mjs                 # use registry.names
node pkgs/piExtensions/generate.mjs --prune         # also drop untracked entries
node pkgs/piExtensions/generate.mjs --no-locks      # metadata only, no npm
node pkgs/piExtensions/generate.mjs --force-locks   # rebuild lockfiles anyway
node pkgs/piExtensions/generate.mjs --locked        # CI check: exit 1 on drift
node pkgs/piExtensions/generate.mjs --all           # mirror keywords:pi-package (8000+)
```
