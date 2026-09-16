{
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "flatnvim";
  version = "0.1.0-unstable-2026-09-16";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = pname;
    rev = "dc4a69e07ae99162fda028e4b27c5d47ae35c826";
    sha256 = "sha256-C/sX0BcNi/5w9GSYWheOUvgoeoGryD/8UMZKWmn9ERU=";
  };

  vendorHash = "sha256-/Bl4G5STa5lnNntZnMmt+BfES+N7ZYAwC9tzpuqUKcc=";

  ldflags = [
    "-s"
    "-w"
  ];

  meta.mainProgram = "flatnvim";
}
