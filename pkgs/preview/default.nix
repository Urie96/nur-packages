{
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage {
  pname = "preview";
  version = "0-unstable-2026-11-11";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = "preview-bin.yazi";
    rev = "73e32eecd52e704f79bcf22cc32d3bde5a6ecb76";
    sha256 = "sha256-SuV6l0e/9rOGXA1DmQiAOdqghiFkcgSm6lCscvzA/H8=";
  };

  cargoRoot = "preview";
  buildAndTestSubdir = "preview";

  doCheck = false;

  cargoHash = "sha256-8m6cJwpMXY7ykkloWv2U5T95CI1yaycV8Cj2SJzC6bs=";

  postInstall = ''
    install -Dm644 $src/main.lua $out/preview-bin.yazi/main.lua
    substituteInPlace $out/preview-bin.yazi/main.lua \
      --replace-fail 'local CMD = "preview"' 'local CMD = "${placeholder "out"}/bin/preview"'
  '';

  meta.mainProgram = "preview";
}
