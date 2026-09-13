{
  lib,
  python3,
}:
python3.pkgs.buildPythonApplication rec {
  pname = "translate";
  version = "0.1.0";

  src = ./.;
  pyproject = false;

  # 纯标准库、无 python 依赖，关掉 buildPythonApplication 默认的
  # wrapPythonPrograms 包装，避免产物里多一层 bash wrapper。
  dontWrapPythonPrograms = true;

  # 源码是单文件标准库脚本，直接安装即可。
  # shebang 由 fixup 阶段 patch 到 store 里的 python3；
  # rbw 不是打包依赖，运行时从 PATH 查找。
  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    install -m 755 translate $out/bin/translate

    runHook postInstall
  '';

  meta = {
    description = "英译中/中译英命令行翻译工具（带 --ai 强制 AI 翻译）";
    mainProgram = "translate";
    platforms = lib.platforms.unix;
  };
}
