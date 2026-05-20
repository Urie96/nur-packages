{
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
}:
rustPlatform.buildRustPackage rec {
  pname = "lazydeck";
  version = "0.1.0-unstable-2026-05-19";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = pname;
    rev = "0171759678e322d25faebe20b1086a0f6b71e63d";
    sha256 = "sha256-DxWb0Gk77AzVPODM5mEJLNEkzCRiwccuRc0HeG9lSc0=";
  };

  doCheck = false;

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    openssl
  ];

  cargoHash = "sha256-O4D3D+t6AVZ5UontPx4DRhd1uZPPJMqMl+zrCI3eme0=";

  meta.mainProgram = "lazydeck";
}
