{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  _7zz,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "raycast";
  version = "2.4.1.0";

  src = fetchurl {
    # 下载地址带 query，fetchurl 默认会拿 URL 末段当 store 名（里面含 `?`/`&`），
    # 后面未加引号的 $src 会被 shell 当 glob 处理，所以显式给个干净的名字。
    name = "raycast-${finalAttrs.version}";
    url = "https://x.raycast-releases.com/download?platform=macos&architecture=arm64&version=${finalAttrs.version}";
    hash = "sha256-W7Ca2vz4BwYFJkuyn89Jbk1hXaOmoM6I6rcGU9GGp5U=";
  };

  nativeBuildInputs = [
    _7zz
    makeWrapper
  ];

  # 同 kitty：dmg 用支持 APFS 的 7zz 解，-snld 保留符号链接（Electron 的
  # framework 里有一堆，展开会撑爆体积）。
  unpackPhase = ''
    runHook preUnpack
    7zz x -snld $src
    runHook postUnpack
  '';

  # dmg 解出来是一个 `Raycast/` 卷目录（旁边还有 .HFS+ Private Directory Data
  # 之类的元数据目录），app 在卷根下。
  sourceRoot = "Raycast";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications $out/bin
    cp -R Raycast.app $out/Applications/
    makeWrapper "$out/Applications/Raycast.app/Contents/MacOS/Raycast" $out/bin/raycast

    runHook postInstall
  '';

  # 上游 bundle 已经带签名，stdenv 的 fixup（含重签名）会破坏它。
  # 也是闭源免费软件，所以不写 license，免得触发 allowUnfree。
  dontFixup = true;

  meta = {
    description = "Control your tools with a few keystrokes";
    homepage = "https://raycast.com/";
    mainProgram = "raycast";
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
