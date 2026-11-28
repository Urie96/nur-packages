{
  rustPlatform,
  fetchFromGitHub,
  lib,
  zlib,
  libgit2,
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

  # nixpkgs 的 cargo-setup-hook 导出 LIBGIT2_NO_VENDOR=1，
  # 所以 libgit2-sys 必须能找到系统 libgit2（kosync 用 git2 做版本信息）。
  buildInputs = [
    zlib
    libgit2
  ];

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
