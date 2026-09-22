{
  lib,
  stdenvNoCC,
  fetchurl,
  _7zz,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "kitty";
  version = "0.49.0";

  src = fetchurl {
    url = "https://github.com/kovidgoyal/kitty/releases/download/v${finalAttrs.version}/kitty-${finalAttrs.version}.dmg";
    hash = "sha256-jMIPsw6VpRQa1UNFFvyjMXcjOn9JI21DG6+c6QWD6Yw=";
  };

  # dmg 是 APFS，nixpkgs 的 undmg（只支持 HFS）解不开，用支持 APFS 的 7zz；
  # -snld 让 7zz 保留符号链接，否则 bundle 里的链接会被展开成副本。
  nativeBuildInputs = [ _7zz ];
  unpackPhase = ''
    runHook preUnpack
    7zz x -snld $src
    runHook postUnpack
  '';
  sourceRoot = ".";

  # nixpkgs 的 kitty 把 terminfo 单独做成 output，home-manager 里
  # 会用 pkgs.kitty.terminfo 装 xterm-kitty，这里保持同样的 output 结构。
  outputs = [
    "out"
    "terminfo"
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    cp -r kitty.app $out/Applications/kitty.app

    # 和 nixpkgs 的 darwin 版本一样，在 bin 下放 kitty/kitten 的软链，
    # wrapper 会沿着 bin/kitty 找到 bundle 里的可执行文件。
    mkdir -p $out/bin
    ln -s ../Applications/kitty.app/Contents/MacOS/kitty $out/bin/kitty
    ln -s ../Applications/kitty.app/Contents/MacOS/kitten $out/bin/kitten

    mkdir -p $terminfo/share
    cp -r $out/Applications/kitty.app/Contents/Resources/terminfo $terminfo/share/terminfo

    runHook postInstall
  '';

  # 上游的 bundle 已经带签名，stdenv 的 fixup（含重签名）会破坏
  # Contents/_CodeSignature 里记录的哈希，让 macOS 认为 app 损坏。
  dontFixup = true;

  meta = {
    description = "Fast, feature full, GPU based terminal emulator (upstream macOS bundle)";
    homepage = "https://sw.kovidgoyal.net/kitty/";
    license = lib.licenses.gpl3Only;
    mainProgram = "kitty";
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
