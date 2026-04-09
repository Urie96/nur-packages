{
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
}:
rustPlatform.buildRustPackage rec {
  pname = "lazycmd";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = pname;
    rev = "0.1.0";
    sha256 = "sha256-yE+KjYHDELUkDVfSJtVnOytWVVn4xmm/ZsX0c49Agcs=";
  };

  doCheck = false;

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    openssl
  ];

  cargoHash = "sha256-MA85baOTOLwG1PEdUjnsUIbCMJfXUqpX7QQ2jW5F7a0=";
  passthru.updateScript = ./update.sh;
}
