{
  lib,
  swiftPackages,
  swift,
}:

swiftPackages.stdenv.mkDerivation {
  pname = "cliclick";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [ swift ];

  buildPhase = ''
    runHook preBuild
    swiftc -O -o cliclick cliclick.swift
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -m 755 cliclick $out/bin/cliclick
    runHook postInstall
  '';

  meta = {
    platforms = lib.platforms.darwin;
    mainProgram = "cliclick";
  };
}
