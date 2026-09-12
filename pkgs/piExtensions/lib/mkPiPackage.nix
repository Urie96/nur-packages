# mkPiPackage.nix — turn a registry.json entry into a Nix derivation.
#
# Tiers (mirrors github:Leoguy77/pi-packages.nix):
#   A — the npm package has no runtime dependencies. We fetch the tarball with
#       its npm integrity hash and unpack it. Fixed-output, instant, cacheable.
#   B — the npm package has runtime dependencies. We build it with
#       buildNpmPackage, feeding pkgs.importNpmLock the lockfile that
#       ./generate.mjs wrote to <registry dir>/<key>/package-lock.json.
#       Because importNpmLock derives the dependency cache from that lockfile,
#       there is *no* npmDepsHash to compute or keep in sync.
#
# Registry entries come from ./generate.mjs (see also ./registry.names).

{ pkgs, lib ? pkgs.lib }:

{
  # attribute name / lockfile directory, e.g. "pi-web-access" or "scope-name"
  key,
  # npm package name, e.g. "pi-web-access" or "@scope/name"
  name,
  version ? "0.0.0",
  # npm tarball URL
  tarball,
  # SRI hash of the tarball (npm's dist.integrity)
  hash,
  tier ? "A",
  dependencies ? { },
  peerDependencies ? { },
  piManifest ? { },
  description ? "",
  keywords ? [ ],
  # directory holding registry.json and the per-key package-lock.json
  packagesDir,
  ...
}@entry:

let
  hasDependencies = dependencies != { };
  useNpmBuild = tier == "B" || hasDependencies;

  tarballSrc = pkgs.fetchurl {
    url = tarball;
    inherit hash;
  };

  lockPath = packagesDir + "/${key}/package-lock.json";
  hasLock = builtins.pathExists lockPath;

  # buildNpmPackage cannot read a lockfile out of an unbuilt derivation at
  # evaluation time, so the lockfile is parsed straight from the repository
  # path and handed to importNpmLock explicitly. The same lockfile is also
  # copied into the source tree for npm itself during configurePhase.
  lock = lib.optionalAttrs hasLock (builtins.fromJSON (builtins.readFile lockPath));

  unpacked = pkgs.runCommand "pi-${key}-src" {
    nativeBuildInputs = [ pkgs.gnutar ];
  } ''
    mkdir -p $out
    tar -xzf ${tarballSrc} --strip-components=1 -C $out
    ${lib.optionalString hasLock ''
      cp ${lockPath} $out/package-lock.json
    ''}
  '';

  meta = {
    inherit description;
    homepage = "https://www.npmjs.com/package/${name}";
    platforms = lib.platforms.all;
    # No maintainers/licenses: npm metadata is not authoritative SPDX here.
  };

  common = {
    inherit meta;
    passthru = {
      inherit entry piManifest keywords peerDependencies;
    };
  };
in

if !useNpmBuild then

  # Tier A: nothing to install, just the unpacked tarball.
  pkgs.runCommand "pi-${key}-${version}" common ''
    mkdir -p $out
    cp -r ${unpacked}/. $out/
  ''

else if !hasLock then

  throw ''
    piExtensions: no package-lock.json for '${key}' (${name}@${version}).

    This package has runtime dependencies, so a lockfile is required to build
    it reproducibly. Generate one with:

      nix shell nixpkgs#nodejs -c node ${toString packagesDir}/generate.mjs --names ${name}
  ''

else

  pkgs.buildNpmPackage (common // {
    pname = "pi-${key}";
    inherit version;
    src = unpacked;

    npmDeps = pkgs.importNpmLock {
      package = lock.packages.${""} or { };
      packageLock = lock;
    };
    # importNpmLock rewrites `resolved` fields to store paths, so the stock
    # buildNpmPackage hook (which byte-compares lockfiles) cannot be used.
    npmConfigHook = pkgs.importNpmLock.npmConfigHook;

    dontNpmBuild = true;
    production = true;

    # buildNpmPackage's default installPhase (npmInstallHook) installs to
    # $out/lib/node_modules/<name> and creates $out/bin wrappers. pi treats a
    # path in settings.packages as the *package root* and resolves the `pi`
    # manifest / conventional directories relative to it, so we keep the package
    # flat at $out instead — same as the Tier A path and pi-packages.nix.
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r . $out/
      rm -rf $out/node_modules/.cache
      runHook postInstall
    '';

    # Keep the same flags pi-packages.nix settled on: extension packages don't
    # need postinstall scripts, and optional platform binaries only bloat size.
    npmFlags = [
      "--ignore-scripts"
      "--omit=optional"
      "--no-audit"
      "--no-fund"
    ];
    npmInstallFlags = [ "--legacy-peer-deps" ];

    # @earendil-works/* ships npm-shrinkwrap.json entries without integrity, so
    # npm may fall back to fetching tarballs by URL and wants a writable cache.
    makeCacheWritable = true;
  })
