{
  pkgs ? import <nixpkgs> { },
}:

{
  updater = pkgs.callPackage ./pkgs/updater { };

  skills = import ./pkgs/skills { inherit pkgs; };
  piExtensions = import ./pkgs/piExtensions { inherit pkgs; };
  hassComponents = pkgs.callPackage ./pkgs/hassComponents { };

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
  fmt-file = pkgs.callPackage ./pkgs/fmt-file { };
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
  split-audio = pkgs.callPackage ./pkgs/split-audio { };
  slim-kitten = pkgs.callPackage ./pkgs/slim-kitten { };
  pick-window = pkgs.callPackage ./pkgs/pick-window { };
  copy = pkgs.callPackage ./pkgs/copy { };
  coding-agent-status = pkgs.callPackage ./pkgs/coding-agent-status { };
  sops-render = pkgs.callPackage ./pkgs/sops-render { };
  xopen = pkgs.callPackage ./pkgs/xopen { };
  apple-music-api = pkgs.callPackage ./pkgs/apple-music-api { };

  # binary
  kitty = pkgs.callPackage ./pkgs/kitty { };
  raycast = pkgs.callPackage ./pkgs/raycast { };
  tinycast = pkgs.callPackage ./pkgs/tinycast { };
  arc = pkgs.callPackage ./pkgs/arc { };
  kicad = pkgs.callPackage ./pkgs/kicad { };
  calibre = pkgs.callPackage ./pkgs/calibre { };
  telegram = pkgs.callPackage ./pkgs/telegram { };
  wechat = pkgs.callPackage ./pkgs/wechat { };
  bambu-studio = pkgs.callPackage ./pkgs/bambu-studio { };
  feishu = pkgs.callPackage ./pkgs/feishu { };
  balenaetcher = pkgs.callPackage ./pkgs/balenaetcher { };
  neteasemusic = pkgs.callPackage ./pkgs/neteasemusic { };
}
