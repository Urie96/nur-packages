{
  lib,
  fetchFromGitHub,
  swiftPackages,
  swift,
  makeWrapper,
}:

swiftPackages.stdenv.mkDerivation {
  pname = "confetti";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = "confetti";
    rev = "b0d673e64b547877dd577cb2f0c5372e10199ec2";
    hash = "sha256-J0AIo3BUboTURkXPoytiOf1lk70nHbEV8aTatAEqgm0=";
  };

  nativeBuildInputs = [
    swift
    makeWrapper
  ];

  buildPhase = ''
    runHook preBuild
    swiftc -O -o confetti confetti.swift
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share/confetti
    install -m 755 confetti $out/bin/confetti
    install -m 644 confetti.png $out/share/confetti/confetti.png
    install -m 644 confetti.mp3 $out/share/confetti/confetti.mp3
    # 通过环境变量注入资源目录（源码优先读 CONFETTI_DATA_DIR）
    wrapProgram $out/bin/confetti --set CONFETTI_DATA_DIR $out/share/confetti
    runHook postInstall
  '';

  meta = {
    description = "Full-screen confetti burst triggered from the command line (port of SwiftConfettiView's Perfect preset)";
    homepage = "https://github.com/Urie96/confetti";
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin;
    mainProgram = "confetti";
  };
}
