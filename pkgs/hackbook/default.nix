{
  buildNpmPackage,
  rustPlatform,
  sqlite,
  fetchFromGitHub,
}:
let
  web = buildNpmPackage rec {
    pname = "hackbook-web";
    version = "0.1.0";
    src = fetchFromGitHub {
      owner = "Urie96";
      repo = "hackbook-web";
      rev = version;
      sha256 = "sha256-AiHmAVLe3H/GQp83sxi/RrOlJrs3O4pei8VsfOqEF8g=";
    };
    npmDepsHash = "sha256-PqIC3wWAgZQXXncPjn20mxCvuANChNnP7CcTDPC7E28=";
    dontNpmInstall = true;
    installPhase = ''
      mv ./dist $out
    '';
  };
in

rustPlatform.buildRustPackage rec {
  pname = "hackbook-server";
  version = "0.1.0";
  src = fetchFromGitHub {
    owner = "Urie96";
    repo = "hackbook-rust";
    rev = version;
    sha256 = "sha256-z12pkg+KphcsGdQ3pyyJexnSzrzNxErYxz5EFbJ9aJM=";
  };
  cargoHash = "sha256-n48Zo+rjgf6GSF1RYC7nrDVAq8rNE+cKkbN09CeyiQI=";

  buildInputs = [ sqlite ];

  inherit web;

  meta.mainProgram = "hackbook-server";

  postInstall = ''
    mkdir -p $out/share
    cp -r $web $out/share/public
  '';

  passthru = {
    inherit web;
    updateScript = ./update.sh;
  };

}
