{
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
}:
rustPlatform.buildRustPackage rec {
  pname = "lazydeck";
  version = "0.1.0-unstable-2026-05-14";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = pname;
    rev = "adf8ca1a7d557218f45ece2719e45e2b66ab54a2";
    sha256 = "sha256-9yiYGUrsfSlkIGAm8cGmGhoKzGlMbEvdfC1gPVFpR9U=";
  };

  doCheck = false;

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    openssl
  ];

  cargoHash = "sha256-x/3GC1PguqdB0e0eWuIjvzQQI+x3hmirkkcSAr+EtUs=";

  meta.mainProgram = "lazydeck";
}
