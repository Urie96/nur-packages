{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "bambu-studio";
  # 上游文件名是 Bambu_Studio_mac-v<CFBundleShortVersionString>-<build>.dmg，
  # 两个号都得有才能拼出下载地址（Homebrew 的 cask 里也是 "02.08.02.61,20260820225108"），
  # 所以这里合成一个 version；update.py 会从 GitHub release 的 asset 里取这两个号。
  version = "02.08.02.61-20260820225108";

  src = fetchurl {
    # 用 `/releases/latest/download/` 而不是 `/download/v<tag>/`：上游 tag 有时和 asset
    # 里的版本号对不上（例如 tag v02.05.03.62 对应的 asset 是
    # Bambu_Studio_mac-v02.05.03.61-...），用 latest 就不用管 tag。
    url = "https://github.com/bambulab/BambuStudio/releases/latest/download/Bambu_Studio_mac-v${finalAttrs.version}.dmg";
    hash = "sha256-z2SKlYWPtjDhNTxJhwON9g1sqraT8YQR+5X7gJ8taSY=";
  };

  # dmg 是 UDZO；跟 calibre/wechat 一样用 hdiutil 挂载 + ditto 拷贝
  # （ditto 连 xattr/符号链接一起搬，7zz 会丢 xattr）。
  unpackPhase = ''
    runHook preUnpack

    # 挂载点路径别太长，用 /tmp 下的短目录。
    mnt=$(TMPDIR=/tmp mktemp -d -t nix-bambu-studio-XXXXXXXXXX)
    detach() {
      /usr/bin/hdiutil detach "$mnt" -force >/dev/null 2>&1 || true
      rm -rf "$mnt"
    }
    trap detach EXIT

    /usr/bin/hdiutil attach -nobrowse -readonly -noverify -mountpoint "$mnt" $src
    /usr/bin/ditto "$mnt/BambuStudio.app" ./BambuStudio.app

    detach
    trap - EXIT

    runHook postUnpack
  '';

  # 卷根还有 .DS_Store / Applications 链接之类，只复制 app。
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    cp -R BambuStudio.app $out/Applications/

    runHook postInstall
  '';

  # 上游 bundle 已经带签名，stdenv 的 fixup 会把它弄坏，所以整个跳过。
  dontFixup = true;

  meta = {
    description = "3D model slicing software for 3D printers (upstream macOS bundle)";
    homepage = "https://bambulab.com/en/download/studio";
    # BambuStudio 本体是 AGPL-3.0+（nixpkgs 里因为首次启动会 dlopen 一个不提供源码的
    # 私有网络库，额外标了 unfree；这里只标 AGPL，免得触发 allowUnfree）。
    license = lib.licenses.agpl3Plus;
    # dmg 是 universal 的（x86_64 + arm64）。
    platforms = lib.platforms.darwin;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
