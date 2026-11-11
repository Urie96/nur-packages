{
  lib,
  buildNpmPackage,
  fakeroot,
  stdenv,
  src,
  version,
}:

buildNpmPackage {
  pname = "paperless-gpt-frontend";
  inherit src version;

  sourceRoot = "${src.name}/web-app";
  npmDepsHash = "sha256-6ZkO5pVQfJKYGpgUEKS/AXy/bfuot8cOJ2o+Z087HWM=";

  # Testcontainers pulls in native SSH addons that are not needed for the UI
  # build and do not support Node 24. Vite/SWC use their locked platform packages.
  npmRebuildFlags = [ "--ignore-scripts" ];

  # Do not persist or replace SWC's compressed native addon during the build.
  env.SWC_NATIVE_BINDING_CACHE = "0";

  nativeBuildInputs = [ fakeroot ];

  # SWC verifies every ancestor of its cache, including /. In the Nix sandbox
  # that directory can belong to unmapped UID 65534, which SWC rejects. fakeroot
  # supplies consistent ownership for this build step only; it is not shipped.
  buildPhase = ''
    runHook preBuild
    fakeroot npm run build
    runHook postBuild
  '';

  # SWC's prebuilt native binding needs libstdc++ when Vite loads it on Linux.
  preBuild = ''
    export LD_LIBRARY_PATH=${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}
  '';

  installPhase = ''
    runHook preInstall
    cp -r dist "$out"
    runHook postInstall
  '';

  meta.license = lib.licenses.mit;
}
