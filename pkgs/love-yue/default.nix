{
  fetchFromGitHub,
  buildNpmPackage,
}:
buildNpmPackage rec {
  pname = "love-yue";
  version = "0.1.0";

  dontNpmInstall = true;
  src = fetchFromGitHub {
    owner = "Urie96";
    repo = "Love";
    rev = version;
    sha256 = "sha256-7l+nKcBS0tlnKbwCPb3p7J7KDWGJuSa1bU8q0SuvRCU=";
  };
  npmDepsHash = "sha256-Sy+SP/Cd5ZFUzFivoSZDu0V/w25MV38yphNjEFLLi0k=";
  installPhase = ''
    mkdir -p $out/share
    mv ./dist $out/share/public
  '';
  passthru.updateScript = ./update.sh;
}
