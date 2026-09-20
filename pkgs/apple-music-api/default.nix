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
    rev = "0dc831048c5192f8a96c279ab24552b9745e3ebc";
    sha256 = "sha256-eeLj2txspSdeYXHCuCpZ4TI9hW7qzXc/4mWHRvZRiFQ=";
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
