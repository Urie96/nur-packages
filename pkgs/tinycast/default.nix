{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  _7zz,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "tinycast";
  version = "0.11.3";

  # 上游 release 里有两个 dmg：Tinycast-<ver>.dmg 是 arm64-only 的（小一半），
  # Tinycast-Universal-<ver>.dmg 才是给 Intel 的，这里跟 raycast 一样只打 arm64。
  src = fetchurl {
    url = "https://github.com/abue-ammar/tinycast/releases/download/v${finalAttrs.version}/Tinycast-${finalAttrs.version}.dmg";
    hash = "sha256-yfAME5ZIrZme4qW0lT8EDKy5h1wZkWdJDdg/HR1zqXc=";
  };

  nativeBuildInputs = [
    _7zz
    makeWrapper
  ];

  # dmg 是 UDZO（`diskutil image create --format UDZO`），nixpkgs 的 undmg 只认 HFS，
  # 所以用 7zz 解；-snld 保留符号链接（跟 kitty/raycast/kicad 一致）。卷根还有个
  # `Applications -> /Applications` 的链接，这里只复制 app，不管它。
  unpackPhase = ''
    runHook preUnpack
    7zz x -snld $src
    runHook postUnpack
  '';

  # 7zz 直接把卷里的东西解到当前目录（不会套一层卷名目录），app 就在根下。
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications $out/bin
    cp -R Tinycast.app $out/Applications/
    makeWrapper "$out/Applications/Tinycast.app/Contents/MacOS/Tinycast" $out/bin/tinycast

    runHook postInstall
  '';

  # 上游用固定的自签名证书签名（不是 Developer ID，也没有公证），而且带了 hardened
  # runtime；stdenv 的 fixup（strip / install_name_tool 之后再补一个 ad-hoc 签名）会把
  # 上游签名弄坏，所以整个跳过。这个签名同时也是 Accessibility 授权能跨版本保留的原因。
  dontFixup = true;

  meta = {
    description = "Tiny, fully native macOS launcher that runs Raycast extensions (upstream macOS bundle)";
    homepage = "https://github.com/abue-ammar/tinycast";
    license = lib.licenses.agpl3Plus;
    mainProgram = "tinycast";
    # 这个 dmg 是 arm64-only（Intel 要用上游的 Tinycast-Universal-*.dmg），上游要求 macOS 26+。
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
