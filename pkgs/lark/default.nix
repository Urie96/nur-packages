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
    pname = "lark";

    # 下载文件名是 Lark-darwin_arm64-<ver>-signed.dmg，路径里还有一段内容 hash，
    # 两个号都得有才能拼出地址（Homebrew 的 cask 也是 "7.74.22,18b7e01d"）。
    # update.py 从官网 API 的 download_link 里取这两个号。
    version = "8.0.3-eee2e5a8";

    src = fetchurl {
      # 注意 host 会变（cask 里还是老的 sf16-sg.larksuitecdn.com，已经下不动了），
      # update.py 只取版本号和 hash，host/路径写在这里。
      url = "https://lf16-larkversion.larksuitecdn.com/obj/lark-version-sg/${lib.last versionParts}/Lark-darwin_arm64-${lib.head versionParts}-signed.dmg";
      hash = "sha256-0sQ2smza+nc/IH2WbUO1gdb/RWZrqFjqxuIVgbLRRHU=";
    };

    # dmg 是 UDZO；LarkSuite.app 里有 700 多个文件用的是存在 xattr 里的 detached
    # 签名（com.apple.cs.*），所以必须用 hdiutil + ditto，不能用 7zz。
    unpackPhase = ''
      runHook preUnpack

      # 挂载点路径别太长，用 /tmp 下的短目录。
      mnt=$(TMPDIR=/tmp mktemp -d -t nix-lark-XXXXXXXXXX)
      detach() {
        /usr/bin/hdiutil detach "$mnt" -force >/dev/null 2>&1 || true
        rm -rf "$mnt"
      }
      trap detach EXIT

      /usr/bin/hdiutil attach -nobrowse -readonly -noverify -mountpoint "$mnt" $src
      /usr/bin/ditto "$mnt/LarkSuite.app" ./LarkSuite.app

      detach
      trap - EXIT

      runHook postUnpack
    '';

    # 卷根还有 .VolumeIcon.icns / Applications 链接之类，只复制 app。
    sourceRoot = ".";

    installPhase = ''
      runHook preInstall

      mkdir -p $out/Applications
      cp -R LarkSuite.app $out/Applications/

      runHook postInstall
    '';

    # 上游 bundle 带签名，stdenv 的 fixup 会把它弄坏，所以整个跳过。
    dontFixup = true;
    # 上游自带自动更新，但 store 是只读的，app 更新不了自己；版本走
    # `just update lark`（pkgs/lark/update.py 读官网 API）。

    meta = {
      description = "Project management software (upstream macOS bundle)";
      homepage = "https://www.larksuite.com/";
      # 闭源免费软件（Homebrew 的 cask 也没写 license），不写 license 免得触发 allowUnfree。
      # 上游按架构分包，这里只打 arm64（flake 也只支持 aarch64-darwin）。
      platforms = [ "aarch64-darwin" ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  }
)
