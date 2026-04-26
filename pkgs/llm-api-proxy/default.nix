{
  rustPlatform,
  openssl,
  pkg-config,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "llm-api-proxy";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = pname;
    rev = version;
    sha256 = "sha256-+rnJrT/I4XRUawDjsQnMhM31cRI1ruxcqN29ibo5bkg=";
  };

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [ openssl ];
  cargoHash = "sha256-A2eyo/t/EOZpj+VXV/DTAiwIAQ3WcevLJqte8E7nFEo=";

  meta.mainProgram = "llm-api-proxy";
}
