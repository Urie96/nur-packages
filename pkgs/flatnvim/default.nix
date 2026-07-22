{
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "flatnvim";
  version = "0.1.0-unstable-2026-07-22";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = pname;
    rev = "c249a1c03ab3c0a38ba1ecf26e99b3c20ebc1d32";
    sha256 = "sha256-Jq36tgKpT2Kbu4afiirPGUL0B+aze5dMtiqYN+3htWI=";
  };

  vendorHash = "sha256-/Bl4G5STa5lnNntZnMmt+BfES+N7ZYAwC9tzpuqUKcc=";

  ldflags = [
    "-s"
    "-w"
  ];

  meta.mainProgram = "flatnvim";
}
