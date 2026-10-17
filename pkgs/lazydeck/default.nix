{
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
}:
rustPlatform.buildRustPackage rec {
  pname = "lazydeck";
  version = "0.1.0-unstable-2026-10-15";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = pname;
    rev = "0d83c70e6901d1007b12069d60b90ffd09252bd7";
    sha256 = "sha256-VYbyIboFvPZVnwTAIHnHc4Eo3m2LduRyDub6qeKJkI0=";
  };

  doCheck = false;

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    openssl
  ];

  cargoHash = "sha256-KnhbGT+kZRINFn6gi/qBuj3bI6UhP6c/AFSNXqrvRxI=";

  meta.mainProgram = "lazydeck";
}
