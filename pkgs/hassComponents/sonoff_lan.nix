{
  buildHomeAssistantComponent,
  pycryptodome,
  fetchFromGitHub,
}:
buildHomeAssistantComponent rec {
  owner = "AlexxIT";
  domain = "sonoff";
  version = "3.11.1";

  src = fetchFromGitHub {
    inherit owner;
    repo = "SonoffLAN";
    rev = "v${version}";
    sha256 = "sha256-DgvcGClZDN9QrZeticY9+eFKMDo98t4C3pmn9WPK9pQ=";
  };

  dependencies = [
    pycryptodome
  ];
}
