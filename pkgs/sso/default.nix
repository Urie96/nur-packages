{
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "sso";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = pname;
    rev = version;
    sha256 = "sha256-s0xvV8QBdluf55i5hLM1G+ReGg05n01XvFLoqMsRG6s=";
  };

  vendorHash = null;
  ldflags = [
    "-s"
    "-w"
  ];

  meta.mainProgram = "sso";
}
