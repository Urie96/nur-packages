{
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
}:
rustPlatform.buildRustPackage rec {
  pname = "lazydeck";
  version = "0.1.0-unstable-2026-09-03";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = pname;
    rev = "c48c1ea03b8f7857db71db7b6cf2d7996a2a6e5c";
    sha256 = "sha256-kKiWwBNwdNGUEQzNRhJbmUYZbswbkW5VJLnvHmvSVC8=";
  };

  doCheck = false;

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    openssl
  ];

  cargoHash = "sha256-KnhbGT+kZRINFn6gi/qBuj3bI6UhP6c/AFSNXqrvRxI=";

  meta.mainProgram = "lazydeck";
}
