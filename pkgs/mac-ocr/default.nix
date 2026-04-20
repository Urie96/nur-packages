{
  lib,
  swiftPackages,
  swift,
}:

swiftPackages.stdenv.mkDerivation {
  pname = "mac-ocr";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [ swift ];

  buildPhase = ''
    runHook preBuild
    swiftc -O -o mac-ocr main.swift
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -m 755 mac-ocr $out/bin/mac-ocr
    runHook postInstall
  '';

  meta = {
    platforms = lib.platforms.darwin;
    mainProgram = "mac-ocr";
  };
}
