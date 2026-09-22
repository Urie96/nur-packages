{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "wechat";
  # 上游文件名是 xWeChatMac_universal_<CFBundleShortVersionString>_<CFBundleVersion>.dmg，
  # 两个号都得有才能拼出下载地址（Homebrew 的 cask 里也是 "4.1.15.20,270100"），
  # 所以这里合成一个 version；update.py 会从 Sparkle appcast 里取这两个号。
  version = "4.1.15.20-270100";

  src = fetchurl {
    # 文件名里两个号用下划线连接，version 里用的是 `-`，拼地址时换回来。
    url = "https://dldir1.qq.com/weixin/Universal/Mac/xWeChatMac_universal_${
      lib.replaceStrings [ "-" ] [ "_" ] finalAttrs.version
    }.dmg";
    hash = "sha256-tzMZ6j739fL28UA7C+2HrHW19bcPCVHqYbrS2USYV/g=";
  };

  # dmg 是 APFS：nixpkgs 的 undmg 解不了；7zz 能解，但会把 xattr 全丢掉，而
  # WeChatAppEx.app 里有组件用的是存在 xattr 里的 detached 签名（com.apple.cs.*）。
  # 所以跟 nixpkgs 的 lmstudio/insomnia 一样，用 hdiutil 挂载 + ditto 拷贝
  # （ditto 连 xattr/符号链接一起搬）。
  unpackPhase = ''
    runHook preUnpack

    # 挂载点路径别太长，用 /tmp 下的短目录。
    mnt=$(TMPDIR=/tmp mktemp -d -t nix-wechat-XXXXXXXXXX)
    detach() {
      /usr/bin/hdiutil detach "$mnt" -force >/dev/null 2>&1 || true
      rm -rf "$mnt"
    }
    trap detach EXIT

    /usr/bin/hdiutil attach -nobrowse -readonly -noverify -mountpoint "$mnt" $src
    /usr/bin/ditto "$mnt/WeChat.app" ./WeChat.app

    detach
    trap - EXIT

    runHook postUnpack
  '';

  # 卷根还有 `.DS_Store`、`操作指引.webloc`、`Applications` 链接之类，只复制 app。
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    cp -R WeChat.app $out/Applications/

    runHook postInstall
  '';

  # 上游 bundle 已经带签名（腾讯自己的开发者证书），stdenv 的 fixup 会把签名弄坏，
  # 所以整个跳过。闭源免费软件（Homebrew 的 cask 也没写 license），不写 license
  # 免得触发 allowUnfree。
  dontFixup = true;
  # 上游自带 Sparkle 自动更新（appcast 就是 mac-release.xml），但 store 是只读的，
  # app 更新不了自己；版本走 `just update wechat`（pkgs/wechat/update.py 读同一个
  # appcast）。

  meta = {
    description = "Free messaging and calling application (upstream macOS bundle)";
    homepage = "https://mac.weixin.qq.com/";
    # dmg 是 universal 的（x86_64 + arm64），上游要求 macOS 12+。
    platforms = lib.platforms.darwin;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
