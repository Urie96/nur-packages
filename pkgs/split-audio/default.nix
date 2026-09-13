{
  lib,
  stdenvNoCC,
  makeWrapper,
  bash,
  bc,
  coreutils,
  ffmpeg-headless,
  fzf,
  gnugrep,
  gnused,
  mpv,
}:

stdenvNoCC.mkDerivation {
  pname = "split-audio";
  version = "0-unstable-2026-05-29";

  # 源码直接放在本仓库里（原来在 ~/dotfile/home/bin/split-audio）
  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    # 脚本之间按 SCRIPT_DIR(=BASH_SOURCE 所在目录) 互相调用，
    # mpv_mark.lua 也从同一目录加载，所以整套文件放在一起。
    install -dm755 $out/libexec/split-audio $out/bin
    install -m755 split_audio.sh delete_mark.sh export_segment.sh generate_segments.sh \
      $out/libexec/split-audio/
    install -m644 mpv_mark.lua $out/libexec/split-audio/

    makeWrapper $out/libexec/split-audio/split_audio.sh $out/bin/split-audio \
      --prefix PATH : ${
        lib.makeBinPath [
          bash
          bc
          coreutils
          ffmpeg-headless
          fzf
          gnugrep
          gnused
          mpv
        ]
      }

    runHook postInstall
  '';

  meta = {
    description = "Interactive mpv-based audio marking and splitting tool";
    homepage = "https://github.com/urie96/dotfile";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "split-audio";
  };
}
