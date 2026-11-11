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
    rev = "73608b36db52b4015afe938fb0d7960ca193f429";
    sha256 = "sha256-0indxiSovq2/Sx8M01ExoiZywyReWn3doI7/8rYMNOs=";
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
