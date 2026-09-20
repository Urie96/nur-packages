{
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "apple-music-api";
  version = "0-unstable-2026-09-20";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = pname;
    rev = "582aaea7e23466910834a87e46e6207e79f18107";
    sha256 = "sha256-DOZjM2oDUzYIOZxF4nSYKUJvRfXiuTh5TAB759x2M4M=";
  };

  vendorHash = "sha256-CRs3p+gq92ll1vVfOVpznzmgqlEGbuPq091ZMXteLuQ=";

  ldflags = [
    "-s"
    "-w"
  ];
  meta = {
    mainProgram = "apple-music-api";
  };
}
