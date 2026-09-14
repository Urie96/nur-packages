{ home-assistant }:
let
  callPackage = home-assistant.python3Packages.callPackage;
in
{
  sonoff_lan = callPackage ./sonoff_lan.nix { };
  volc_tts = callPackage ./volc_tts.nix { };
}
