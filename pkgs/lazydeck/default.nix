{
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
}:
rustPlatform.buildRustPackage rec {
  pname = "lazydeck";
  version = "0.1.0-unstable-2026-05-23";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = pname;
    rev = "8bd25e3ecd0a96be167656d64ce1cea231b483e0";
    sha256 = "sha256-C2PDjsKIo/FPjr2Z2jxTlk2p3YTLv590USvEHliEUgQ=";
  };

  doCheck = false;

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    openssl
  ];

  cargoHash = "sha256-/510A1L9KjeAh0zlQX9CczMs8v8ZTMpVuKwIsFVGshE=";

  meta.mainProgram = "lazydeck";
}
