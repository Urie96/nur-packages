{
  pkgs ? import <nixpkgs> { },
}:

{
  # The `lib`, `overlays`, `nixosModules`, `homeModules`,
  # `darwinModules` and `flakeModules` names are special
  lib = import ./lib { inherit pkgs; }; # functions
  overlays = import ./overlays; # nixpkgs overlays

  ncmdump = pkgs.callPackage ./pkgs/ncmdump { };
  translate = pkgs.callPackage ./pkgs/translate { };
  foxtrot = pkgs.callPackage ./pkgs/foxtrot { };
  flatnvim = pkgs.callPackage ./pkgs/flatnvim { };
  keywrap = pkgs.callPackage ./pkgs/keywrap { };
  lazycmd = pkgs.callPackage ./pkgs/lazycmd { };
  NeteaseCloudMusicApi = pkgs.callPackage ./pkgs/NeteaseCloudMusicApi { };
  tencent-cloud-update-ssl = pkgs.callPackage ./pkgs/tencent-cloud-update-ssl { };
  hackbook = pkgs.callPackage ./pkgs/hackbook { };
  find-project-root = pkgs.callPackage ./pkgs/find-project-root { };
  sso = pkgs.callPackage ./pkgs/sso { };
  love-yue = pkgs.callPackage ./pkgs/love-yue { };
}
