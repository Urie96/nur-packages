{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "balenaetcher";
  version = "2.1.7";

  # 只有 GitHub release，文件名带架构（balenaEtcher-<ver>-<arch>.dmg）。
  # 上游按架构分包，这里只打 arm64（flake 也只支持 aarch64-darwin）。
  src = fetchurl {
    url = "https://github.com/balena-io/etcher/releases/download/v${finalAttrs.version}/balenaEtcher-${finalAttrs.version}-arm64.dmg";
    hash = "sha256-dAi1xdM4LjN/J6ga7IzBIrh1tHgJrKm2ClpRMQApI0Q=";
  };

  # dmg 是 UDZO；balenaEtcher.app 里有近 200 个文件用的是存在 xattr 里的 detached
  # 签名（com.apple.cs.*），所以必须用 hdiutil + ditto，不能用 7zz。
  unpackPhase = ''
    runHook preUnpack

    # 挂载点路径别太长，用 /tmp 下的短目录。
    mnt=$(TMPDIR=/tmp mktemp -d -t nix-balenaetcher-XXXXXXXXXX)
    detach() {
      /usr/bin/hdiutil detach "$mnt" -force >/dev/null 2>&1 || true
      rm -rf "$mnt"
    }
    trap detach EXIT

    /usr/bin/hdiutil attach -nobrowse -readonly -noverify -mountpoint "$mnt" $src
    /usr/bin/ditto "$mnt/balenaEtcher.app" ./balenaEtcher.app

    detach
    trap - EXIT

    runHook postUnpack
  '';

  # 卷根还有 .VolumeIcon.icns / Applications 链接之类，只复制 app。
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    cp -R balenaEtcher.app $out/Applications/

    runHook postInstall
  '';

  # 上游 bundle 带签名，stdenv 的 fixup 会把它弄坏，所以整个跳过。
  dontFixup = true;

  meta = {
    description = "Tool to flash OS images to SD cards & USB drives (upstream macOS bundle)";
    homepage = "https://balena.io/etcher";
    license = lib.licenses.asl20;
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
