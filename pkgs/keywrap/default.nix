{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "keywrap";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = pname;
    rev = version;
    sha256 = "sha256-39S+tQPGnNWiHAtdddYZ0s4QAhpiVVTiLprJQaVsA/A=";
  };

  vendorHash = "sha256-i+df0h6mWBWD+9HY+xlM9PSB5MSjUH8ooVbmDViBpDA=";

  ldflags = [
    "-s"
    "-w"
  ];
  meta = with lib; {
    platforms = platforms.unix;
    mainProgram = "keywrap";
  };
  passthru.updateScript = ./update.sh;
}
