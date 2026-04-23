{
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "flatnvim";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = pname;
    rev = version;
    sha256 = "sha256-zpkBjJRQfFsfPbXYcNm0uFPxLbeieKRJaRwi/mf9p3c=";
  };

  vendorHash = "sha256-/Bl4G5STa5lnNntZnMmt+BfES+N7ZYAwC9tzpuqUKcc=";

  ldflags = [
    "-s"
    "-w"
  ];

  meta.mainProgram = "flatnvim";
}
