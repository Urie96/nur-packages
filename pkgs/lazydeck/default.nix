{
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
}:
rustPlatform.buildRustPackage rec {
  pname = "lazydeck";
  version = "0-unstable-2025-05-10";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = pname;
    rev = "f7f81d4daf9b2d5fb12e04e9081cf2e307763508";
    sha256 = "sha256-yE+KjYHDELUkDVfSJtVnOytWVVn4xmm/ZsX0c49Agcs=";
  };

  doCheck = false;

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    openssl
  ];

  cargoHash = "sha256-MA85baOTOLwG1PEdUjnsUIbCMJfXUqpX7QQ2jW5F7a0=";

  meta.mainProgram = "lazydeck";
}
