{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "neteasemusic";
  # 上游文件名是 NeteaseCloudMusic_Music_official_<appVer>.<buildVer>_arm64.dmg，
  # 两个号都得有才能拼出地址（Homebrew 的 cask 里也是 "3.1.9,3364"），
  # 所以这里合成一个 version；update.py 从官网 API 里取这两个号。
  version = "3.1.12.3443";

  src = fetchurl {
    # 上游按架构分包，这里只打 arm64（flake 也只支持 aarch64-darwin）。
    url = "https://d1.music.126.net/dmusic/NeteaseCloudMusic_Music_official_${finalAttrs.version}_arm64.dmg";
    # 上游会按 UA 挡掉非浏览器请求（403），给个正常的浏览器 UA。
    curlOptsList = [
      "-A"
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    ];
    hash = "sha256-L70/LbPe6rRLSLYOzFxGADZuSbyFkyiEM/niAJ9df+A=";
  };

  # dmg 是 UDZO；跟 calibre/wechat 一样用 hdiutil 挂载 + ditto 拷贝
  # （ditto 连 xattr/符号链接一起搬，7zz 会丢 xattr）。
  unpackPhase = ''
    runHook preUnpack

    # 挂载点路径别太长，用 /tmp 下的短目录。
    mnt=$(TMPDIR=/tmp mktemp -d -t nix-neteasemusic-XXXXXXXXXX)
    detach() {
      /usr/bin/hdiutil detach "$mnt" -force >/dev/null 2>&1 || true
      rm -rf "$mnt"
    }
    trap detach EXIT

    /usr/bin/hdiutil attach -nobrowse -readonly -noverify -mountpoint "$mnt" $src
    /usr/bin/ditto "$mnt/NeteaseMusic.app" ./NeteaseMusic.app

    detach
    trap - EXIT

    runHook postUnpack
  '';

  # 卷根还有 .VolumeIcon.icns / Applications 链接之类，只复制 app。
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    cp -R NeteaseMusic.app $out/Applications/

    runHook postInstall
  '';

  # 上游 bundle 带签名，stdenv 的 fixup 会把它弄坏，所以整个跳过。
  dontFixup = true;
  # 上游自带自动更新，但 store 是只读的，app 更新不了自己；版本走
  # `just update neteasemusic`（pkgs/neteasemusic/update.py 读官网 API）。

  meta = {
    description = "Music streaming platform (upstream macOS bundle)";
    homepage = "https://music.163.com/";
    # 闭源免费软件（Homebrew 的 cask 也没写 license），不写 license 免得触发 allowUnfree。
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
