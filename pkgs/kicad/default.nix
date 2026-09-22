{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  _7zz,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "kicad";
  version = "10.0.6";

  src = fetchurl {
    url = "https://github.com/KiCad/kicad-source-mirror/releases/download/${finalAttrs.version}/kicad-unified-universal-${finalAttrs.version}.dmg";
    hash = "sha256-703NQnjEbT780oyNsnPVlX1o79oCj2v3m0gR/FMC3Gg=";
  };

  nativeBuildInputs = [
    _7zz
    makeWrapper
  ];

  # 同 kitty：dmg 用支持 APFS 的 7zz 解，-snld 保留符号链接，否则 suite 里
  # GerbView.app -> KiCad.app/... 这类链接会被展开成副本。
  unpackPhase = ''
    runHook preUnpack
    7zz x -snld $src
    runHook postUnpack
  '';

  # dmg 解出来是 `KiCad/` 卷目录，卷里的 `KiCad/` 才是那个 suite
  # （KiCad.app 加上指向它内部各 app 的链接），所以 sourceRoot 指到卷目录。
  sourceRoot = "KiCad";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications $out/bin
    cp -R KiCad $out/Applications/

    makeWrapper "$out/Applications/KiCad/KiCad.app/Contents/MacOS/kicad" $out/bin/kicad
    makeWrapper "$out/Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli" $out/bin/kicad-cli
    makeWrapper "$out/Applications/KiCad/KiCad.app/Contents/MacOS/idf2vrml" $out/bin/idf2vrml
    makeWrapper "$out/Applications/KiCad/KiCad.app/Contents/MacOS/idfcyl" $out/bin/idfcyl
    makeWrapper "$out/Applications/KiCad/KiCad.app/Contents/MacOS/idfrect" $out/bin/idfrect
    makeWrapper "$out/Applications/KiCad/KiCad.app/Contents/MacOS/dxf2idf" $out/bin/dxf2idf

    runHook postInstall
  '';

  # 上游 bundle 已经带签名，stdenv 的 fixup（含重签名）会破坏它。
  dontFixup = true;

  meta = {
    description = "Electronics design automation suite (upstream macOS bundle)";
    homepage = "https://kicad.org/";
    license = lib.licenses.gpl3Plus;
    mainProgram = "kicad";
    # dmg 是 universal 的，Apple Silicon 和 Intel 都能用。
    platforms = lib.platforms.darwin;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
