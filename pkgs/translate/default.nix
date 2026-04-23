{
  rustPlatform,
  openssl,
  pkg-config,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "translate";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = pname;
    rev = version;
    sha256 = "sha256-Tb6mWG0AD754iJ4YHOkr7o0JiqnytH4DvtMAgQtP9cI=";
  };

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [ openssl ];
  cargoHash = "sha256-lrlUd289rQmfUMNccJo7rxI9A86ILPTt7M/+SOxDY+Y=";

  meta.mainProgram = "translate";
}
