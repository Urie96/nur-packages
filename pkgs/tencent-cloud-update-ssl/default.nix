{
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "tencent-cloud-update-ssl";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = pname;
    rev = version;
    sha256 = "sha256-7Lvv6NDmIBvYyf+3bdVc1838YvY4fJV0wDhHN7mgTeg=";
  };

  vendorHash = "sha256-s9wTrHD5g2sqGyt4x9iT7BwKCea8nhvdTjkoL8VlLh0=";

  ldflags = [
    "-s"
    "-w"
  ];
}
