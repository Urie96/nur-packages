{
  buildHomeAssistantComponent,
  fetchFromGitHub,
  websockets,
  propcache,
}:
buildHomeAssistantComponent rec {
  owner = "urie96";
  version = "0.0.1";
  domain = "volc_tts";

  src = fetchFromGitHub {
    inherit owner;
    repo = "hass-volcengine-tts";
    rev = "a58a5ef1bb304baf6660a85a0ca99851b3d7aa10";
    sha256 = "sha256-CAnkQt8ZVbiAyoOUfYTTQK+zlfef0e5Gqvs5t6a8OfU=";
  };

  dependencies = [
    websockets
    propcache
  ];
}
