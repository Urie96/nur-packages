{
  rustPlatform,
  fetchFromGitHub,
  lib,
  zlib,
  pkg-config,
}:
rustPlatform.buildRustPackage rec {
  pname = "kosync";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "lzyor";
    repo = pname;
    rev = "acab3ac84b0f95df6e21a006175043ec26515104";
    hash = "sha256-CvF2mW+qhKluwWriH+OtRr+KiAVK9ZBOMzIM3wjAvJE=";
  };

  # 把 Cargo.lock 换成 regenerated 版本，避免 time 0.3.23 的编译问题
  prePatch = ''
    cp ${./Cargo.lock} ./Cargo.lock
  '';

  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [ zlib ];

  env = {
    KOSYNC_ADDR = "127.0.0.1:3000";
  };

  meta = with lib; {
    description = "KOReader sync server";
    homepage = "https://github.com/lzyor/kosync";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.unix;
    mainProgram = "kosync";
  };
}
