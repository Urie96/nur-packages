{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "calibre";
  version = "9.15.0";

  # 别把地址换成 GitHub release：上游发新版后会把旧 tag 的产物删掉，地址会失效，
  # Homebrew 的 cask 里也有同样的注释。这里跟 cask 一样从官网下载（livecheck 看的
  # 也是 https://calibre-ebook.com/dist/osx 这个重定向）。
  src = fetchurl {
    url = "https://download.calibre-ebook.com/${finalAttrs.version}/calibre-${finalAttrs.version}.dmg";
    hash = "sha256-Gzp0URdbc64rqij+G8HFPuNNZbSJiB5+wCwg+eD/YBk=";
  };

  nativeBuildInputs = [ makeWrapper ];

  # dmg 是 APFS：nixpkgs 的 undmg 解不了；7zz 能解，但会把 xattr 全丢掉。calibre 的
  # bundle 里 python-lib.bypy.frozen 这类文件用的是「存在 xattr 里的 detached 签名」
  # （com.apple.cs.CodeSignature），丢了之后 codesign 会报 "code object is not signed
  # at all"。所以跟 nixpkgs 的 lmstudio/insomnia 一样，用 hdiutil 挂载 + ditto 拷贝
  # （ditto 连 xattr 一起搬，7zz/cp 不行）。
  unpackPhase = ''
    runHook preUnpack

    # 挂载点路径别太长，用 /tmp 下的短目录。
    mnt=$(TMPDIR=/tmp mktemp -d -t nix-calibre-XXXXXXXXXX)
    detach() {
      /usr/bin/hdiutil detach "$mnt" -force >/dev/null 2>&1 || true
      rm -rf "$mnt"
    }
    trap detach EXIT

    /usr/bin/hdiutil attach -nobrowse -readonly -noverify -mountpoint "$mnt" $src
    /usr/bin/ditto "$mnt/calibre.app" ./calibre.app

    detach
    trap - EXIT

    runHook postUnpack
  '';

  # app 就在当前目录下（卷根的 Applications 链接没复制）。
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications $out/bin
    cp -R calibre.app $out/Applications/

    # cask 里 app 之外还装了一堆 CLI（calibre-server / ebook-convert / ...），
    # 这里同样用 wrapper 暴露到 bin 下。
    for bin in \
      calibre calibre-complete calibre-customize calibre-debug calibre-parallel \
      calibre-server calibre-smtp calibredb ebook-convert ebook-device ebook-edit \
      ebook-meta ebook-polish ebook-viewer fetch-ebook-metadata lrf2lrs lrfviewer \
      lrs2lrf markdown-calibre web2disk
    do
      makeWrapper "$out/Applications/calibre.app/Contents/MacOS/$bin" "$out/bin/$bin"
    done

    runHook postInstall
  '';

  # 上游 bundle 已经带签名，stdenv 的 fixup（strip / install_name_tool 之后再补一个
  # ad-hoc 签名）会把它弄坏，所以整个跳过。
  dontFixup = true;

  meta = {
    description = "E-books management software (upstream macOS bundle)";
    homepage = "https://calibre-ebook.com/";
    license = lib.licenses.gpl3Plus;
    mainProgram = "calibre";
    # dmg 是 universal 的（x86_64 + arm64）。
    platforms = lib.platforms.darwin;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
