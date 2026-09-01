{
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
}:
rustPlatform.buildRustPackage rec {
  pname = "lazydeck";
  version = "0.1.0-unstable-2026-09-01";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = pname;
    rev = "72f3f4af149668a213d326cb6412d104c353460e";
    sha256 = "sha256-3/7hxTcB1rbC4SXpEO4zHXPyW7r6fm24ZJi3eD+GUZA=";
  };

  doCheck = false;

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    openssl
  ];

  cargoHash = "sha256-KnhbGT+kZRINFn6gi/qBuj3bI6UhP6c/AFSNXqrvRxI=";

  meta.mainProgram = "lazydeck";
}
