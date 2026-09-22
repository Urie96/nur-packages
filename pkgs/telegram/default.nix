{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "telegram";
  # 上游文件名是 Telegram-<CFBundleShortVersionString>.<CFBundleVersion>.app.zip，
  # 两个号都得有才能拼出下载地址（Homebrew 的 cask 里也是 "12.10,282985"），
  # 所以这里合成一个 version；update.py 会从 Sparkle appcast 里取这两个号。
  version = "12.10.282985";

  # Telegram for macOS（不是 Qt 版的 telegram-desktop）从自己的更新服务器发版，
  # appcast 见 https://osx.telegram.org/updates/versions.xml。
  src = fetchurl {
    url = "https://osx.telegram.org/updates/Telegram-${finalAttrs.version}.app.zip";
    hash = "sha256-YJz1u+0xBvkZ7WFF9RIvEl3tiAhu5uOurHBdA9cFJI0=";
  };

  nativeBuildInputs = [ unzip ];

  # zip 里就是 Telegram.app（没有外层目录）；unzip 会把 Sparkle.framework 里的
  # Versions/Current、Resources 这类软链还原成软链，所以不需要 7zz/ditto。
  unpackPhase = ''
    runHook preUnpack
    unzip -q $src
    runHook postUnpack
  '';

  # 别让 stdenv 的启发式把 sourceRoot 认成解出来的 Telegram.app。
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    cp -R Telegram.app $out/Applications/

    runHook postInstall
  '';

  # 上游是 notarized 的 Developer ID 签名 + hardened runtime（spctl 认），stdenv 的
  # fixup（strip / install_name_tool 之后再补 ad-hoc 签名）会把这个签名弄坏，所以跳过。
  dontFixup = true;
  # 上游自带 Sparkle 自动更新（appcast 就是 versions.xml），但 store 是只读的，
  # app 更新不了自己；版本走 `just update telegram`（pkgs/telegram/update.py 读同一个
  # appcast）。

  meta = {
    description = "Messaging app with a focus on speed and security (upstream macOS bundle)";
    homepage = "https://macos.telegram.org/";
    license = lib.licenses.gpl2Only;
    # zip 是 universal 的（x86_64 + arm64），上游要求 macOS 10.13+。
    platforms = lib.platforms.darwin;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
