{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation (
  finalAttrs:
  let
    # version 是 `<ver>-<hash>`（下载地址里版本号和内容 hash 各占一段），拆开拼 URL。
    versionParts = lib.splitString "-" finalAttrs.version;
  in
  {
    pname = "feishu";

    # 下载文件名是 Feishu-darwin_arm64-<ver>-signed.dmg，路径里还有一段内容 hash，
    # 两个号都得有才能拼出地址（Homebrew 的 cask 也是 "7.75.15,8fff45b2"）。
    # update.py 从官网 API 的 download_link 里取这两个号。
    version = "8.1.17-697cd1b3";

    src = fetchurl {
      url = "https://sf3-cn.feishucdn.com/obj/ee-appcenter/${lib.last versionParts}/Feishu-darwin_arm64-${lib.head versionParts}-signed.dmg";
      hash = "sha256-pOAGonBt/4SpC9hz5vUk4o33AwpR8YQBv6vfoqEAx+8=";
    };

    # dmg 是 UDZO；bundle 里有 900 多个文件用的是存在 xattr 里的 detached 签名
    # （com.apple.cs.*），所以必须用 hdiutil + ditto，不能用 7zz。
    unpackPhase = ''
      runHook preUnpack

      # 挂载点路径别太长，用 /tmp 下的短目录。
      mnt=$(TMPDIR=/tmp mktemp -d -t nix-feishu-XXXXXXXXXX)
      detach() {
        /usr/bin/hdiutil detach "$mnt" -force >/dev/null 2>&1 || true
        rm -rf "$mnt"
      }
      trap detach EXIT

      /usr/bin/hdiutil attach -nobrowse -readonly -noverify -mountpoint "$mnt" $src
      /usr/bin/ditto "$mnt/Lark.app" ./Lark.app

      detach
      trap - EXIT

      runHook postUnpack
    '';

    # 卷根还有 .VolumeIcon.icns / Applications 链接之类，只复制 app。
    sourceRoot = ".";

    installPhase = ''
      runHook preInstall

      mkdir -p $out/Applications
      # 上游 bundle 目录名是 Lark.app，但 CFBundleName 是 Feishu（Homebrew 的 cask 也
      # 是装成 Feishu.app）。这里用 ditto 直接拷成 Feishu.app：ditto 连 xattr 一起搬，
      # 换目录名不影响 bundle 自身的签名。
      /usr/bin/ditto Lark.app "$out/Applications/Feishu.app"

      runHook postInstall
    '';

    # 上游 bundle 带签名，stdenv 的 fixup 会把它弄坏，所以整个跳过。
    dontFixup = true;
    # 上游自带自动更新，但 store 是只读的，app 更新不了自己；版本走
    # `just update feishu`（pkgs/feishu/update.py 读官网 API）。

    meta = {
      description = "Project management software (upstream macOS bundle)";
      homepage = "https://www.feishu.cn/";
      # 闭源免费软件（Homebrew 的 cask 也没写 license），不写 license 免得触发 allowUnfree。
      # 上游按架构分包，这里只打 arm64（flake 也只支持 aarch64-darwin）。
      platforms = [ "aarch64-darwin" ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  }
)
