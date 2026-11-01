{
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage {
  pname = "preview";
  version = "0-unstable-2026-11-01";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = "preview-bin.yazi";
    rev = "b9ce4a5f85fc6e7473c543263065325da80ec2a2";
    sha256 = "sha256-puzwS39u35hb3xlv0hD/BOkKz4HT0j3X6/1jKUlT0KM=";
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
