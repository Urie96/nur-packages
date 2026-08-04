{
  lib,
  swiftPackages,
  swift,
}:

swiftPackages.stdenv.mkDerivation {
  pname = "app-switch-watcher";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [ swift ];

  buildPhase = ''
    runHook preBuild
    swiftc -O -o app-switch-watcher main.swift
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -m 755 app-switch-watcher $out/bin/app-switch-watcher
    runHook postInstall
  '';

  meta = {
    platforms = lib.platforms.darwin;
    mainProgram = "app-switch-watcher";
  };
}
