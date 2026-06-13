{
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
}:
rustPlatform.buildRustPackage rec {
  pname = "lazydeck";
  version = "0.1.0-unstable-2026-06-13";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = pname;
    rev = "872b1b830a0ee2f6898f618374c6fe1db776a702";
    sha256 = "sha256-ra3JFpnOnQhsI5gNIRl0wqK+y7TKiSu+YJ3k7ITHnXc=";
  };

  doCheck = false;

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    openssl
  ];

  cargoHash = "sha256-KnhbGT+kZRINFn6gi/qBuj3bI6UhP6c/AFSNXqrvRxI=";

  meta.mainProgram = "lazydeck";
}
