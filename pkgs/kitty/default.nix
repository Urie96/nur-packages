{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
}:

lib.optionalAttrs stdenv.hostPlatform.isDarwin {
  # nixpkgs 里的 kitty 停在 0.48.2，而 0.49.0 的构建需要上游才有的 slangc
  # 来编译自定义 shader，用 overlay 从源码升级成本太高。
  # 这里直接换成上游 release 里已经打包好的 kitty.app：dmg 里的 bundle 自带
  # Python 运行时、shell-integration、terminfo 和 slangc，除了解 dmg 不需要构建。
  #
  # 只覆盖 darwin（当前两台 mac 都是 aarch64；dmg 里是 universal 二进制，
  # 真要用 x86_64 也能跑），Linux 机器继续用 nixpkgs 的源码构建版本，不受影响。
  kitty = stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "kitty";
    version = "0.49.0";

    src = fetchurl {
      url = "https://github.com/kovidgoyal/kitty/releases/download/v${finalAttrs.version}/kitty-${finalAttrs.version}.dmg";
      hash = "sha256-jMIPsw6VpRQa1UNFFvyjMXcjOn9JI21DG6+c6QWD6Yw=";
    };

    # dmg 是 APFS，nixpkgs 的 undmg（只支持 HFS）解不开，用支持 APFS 的 7zz；
    # -snld 让 7zz 保留符号链接，否则 bundle 里的链接会被展开成副本。
    nativeBuildInputs = [ prev._7zz ];
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
  });
}
