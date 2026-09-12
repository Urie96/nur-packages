{
  pkgs ? import <nixpkgs> { },
}:

{
  updater = pkgs.callPackage ./pkgs/updater { };

  skills = import ./pkgs/skills { inherit pkgs; };

  ncmdump = pkgs.callPackage ./pkgs/ncmdump { };
  translate = pkgs.callPackage ./pkgs/translate { };
  foxtrot = pkgs.callPackage ./pkgs/foxtrot { };
  flatnvim = pkgs.callPackage ./pkgs/flatnvim { };
  keywrap = pkgs.callPackage ./pkgs/keywrap { };
  lazydeck = pkgs.callPackage ./pkgs/lazydeck { };
  NeteaseCloudMusicApi = pkgs.callPackage ./pkgs/NeteaseCloudMusicApi { };
  tencent-cloud-update-ssl = pkgs.callPackage ./pkgs/tencent-cloud-update-ssl { };
  hackbook = pkgs.callPackage ./pkgs/hackbook { };
  find-project-root = pkgs.callPackage ./pkgs/find-project-root { };
  sso = pkgs.callPackage ./pkgs/sso { };
  love-yue = pkgs.callPackage ./pkgs/love-yue { };
  apprise-server = pkgs.callPackage ./pkgs/apprise-server { };
  mac-ocr = pkgs.callPackage ./pkgs/mac-ocr { };
  cliclick = pkgs.callPackage ./pkgs/cliclick { };
  app-switch-watcher = pkgs.callPackage ./pkgs/app-switch-watcher { };
  confetti = pkgs.callPackage ./pkgs/confetti { };
  sing-box = pkgs.callPackage ./pkgs/sing-box { };
  llm-api-proxy = pkgs.callPackage ./pkgs/llm-api-proxy { };
  kosync = pkgs.callPackage ./pkgs/kosync { };
  fira-code-italic = pkgs.callPackage ./pkgs/fira-code-italic { };
  fira-mono-italic = pkgs.callPackage ./pkgs/fira-mono-italic { };

  pi-server = pkgs.callPackage ./pkgs/pi-server { };
  xiaozhi-server-rs = pkgs.callPackage ./pkgs/xiaozhi-server-rs { };
  rime-cli = pkgs.callPackage ./pkgs/rime-cli { };
  skhd-zig = pkgs.callPackage ./pkgs/skhd-zig { };
}
