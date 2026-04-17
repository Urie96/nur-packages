{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "ncmdump";
  version = "0.0.1";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-2i4cCyBMoy22OHX0Q0VvRfQXq8R3kln4u6fCzR76bw8=";
  };

  vendorHash = "sha256-7QXnwcLu0d24ACvxVePMzrOKQXtzWDoVsHxL0KYTJS4=";

  ldflags = [
    "-s"
    "-w"
  ];
  meta = with lib; {
    platforms = platforms.unix;
    mainProgram = "ncmdump";
  };
  passthru.updateScript = ./update.sh;

}
