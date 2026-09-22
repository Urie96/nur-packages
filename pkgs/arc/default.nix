{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "arc";
  # 上游文件名是 Arc-<CFBundleShortVersionString>-<CFBundleVersion>.zip，
  # 两个号都得有才能拼出下载地址（Homebrew 的 cask 也是写成 "1.165.1,87405"），
  # 所以这里合成一个 version；update.py 会从 Sparkle appcast 里取这两个号。
  version = "1.165.1-87405";

  src = fetchurl {
    url = "https://releases.arc.net/release/Arc-${finalAttrs.version}.zip";
    hash = "sha256-HbT+HyQyS/EWNK4bQrhmb9H9za3mk+mEFbAPDJEC3+Q=";
  };

  nativeBuildInputs = [ unzip ];

  # zip 里就是 Arc.app（没有外层目录），unzip 会把 framework 里那 32 个
  # Versions/Current 之类的软链正确还原成软链，所以不需要 7zz/ditto。
  unpackPhase = ''
    runHook preUnpack
    unzip -q $src
    runHook postUnpack
  '';

  # 别让 stdenv 的启发式把 sourceRoot 认成解出来的 Arc.app。
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    cp -R Arc.app $out/Applications/

    runHook postInstall
  '';

  # 上游是 notarized 的 Developer ID 签名 + hardened runtime（spctl 认），stdenv 的
  # fixup（strip / install_name_tool 之后再补 ad-hoc 签名）会把这个签名弄坏，所以跳过。
  # 闭源免费软件（Homebrew 的 cask 也没写 license），不写 license 免得触发 allowUnfree。
  dontFixup = true;
  # 上游还自带 Sparkle 自动更新（SUFeedURL -> releases.arc.net/updates.xml），但 store 是
  # 只读的，app 更新不了自己；版本走 `just update arc`（pkgs/arc/update.py 读同一个 appcast）。

  meta = {
    description = "Chromium based browser (upstream notarized macOS bundle)";
    homepage = "https://arc.net/";
    # zip 是 universal 的（x86_64 + arm64），上游要求 macOS 13+。
    platforms = lib.platforms.darwin;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
