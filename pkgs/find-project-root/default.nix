{
  lib,
  python3,
}:
python3.pkgs.buildPythonApplication rec {
  pname = "find-project-root";
  version = "0.1.0";

  src = ./.;
  pyproject = false;

  # 纯标准库、无 python 依赖，关掉 buildPythonApplication 默认的
  # wrapPythonPrograms 包装，避免产物里多一层 bash wrapper。
  dontWrapPythonPrograms = true;

  # 源码是单文件标准库脚本，直接安装即可。
  # shebang 由 fixup 阶段 patch 到 store 里的 python3。
  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    install -m 755 find-project-root $out/bin/find-project-root

    runHook postInstall
  '';

  meta = {
    description = "向上查找项目根目录（.git/Cargo.toml/go.mod/package.json 等标记）";
    mainProgram = "find-project-root";
    platforms = lib.platforms.unix;
  };
}
