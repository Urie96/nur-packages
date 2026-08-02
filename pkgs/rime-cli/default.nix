{
  rustPlatform,
  fetchFromGitHub,
  lib,
  pkg-config,
  librime,
}:
rustPlatform.buildRustPackage {
  pname = "rime-cli";
  version = "0-unstable-2026-08-02";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = "rime-cli";
    rev = "e41b5183e36333677a796ab7de518265e25e1fd7";
    hash = "sha256-zDLxmk6lyh8nsAV2dEhT4U11r94cwc1pn8io1N+ou/g=";
  };

  cargoHash = "sha256-OlSoQ8jXEW/7RM7BBwVfqifeYLKfQkaged+1b/n9BdY=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ librime ];

  # 告诉 rime-sys/build.rs 去 store 里找 librime
  preBuild = ''
    export RIME_LIB_DIR=${librime}/lib
    export RIME_INCLUDE_DIR=${librime}/include
  '';

  meta = with lib; {
    description = "Terminal client for rime-daemon: 2-line IME display (preedit / candidates)";
    homepage = "https://github.com/Urie96/rime-cli";
    maintainers = [ ];
    platforms = platforms.unix;
    mainProgram = "rime-cli";
  };
}
