{
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "find-project-root";
  version = "0.1.0";
  src = fetchFromGitHub {
    owner = "Urie96";
    repo = pname;
    rev = version;
    sha256 = "sha256-tzXzPSnM8PRggq1wl7tmCyHHipYqIbn+iPCsQnJOngE=";
  };
  cargoHash = "sha256-jrLrAc9I94nETbhybVXCULvO3OwOKnUa129hyCRx+Fg=";
  passthru.updateScript = ./update.sh;

  meta.mainProgram = "find-project-root";
}
