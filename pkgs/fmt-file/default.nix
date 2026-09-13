{
  lib,
  python3,
}:
python3.pkgs.buildPythonApplication rec {
  pname = "fmt-file";
  version = "0.1.0";

  src = ./.;
  pyproject = false;

  # 纯标准库、无 python 依赖，关掉 buildPythonApplication 默认的
  # wrapPythonPrograms 包装，避免产物里多一层 bash wrapper。
  dontWrapPythonPrograms = true;

  # 源码是单文件标准库脚本，直接安装即可。
  # shebang 由 fixup 阶段 patch 到 store 里的 python3。
  # 各个格式化器（nixfmt/shfmt/ruff/biome/prettierd/...）不是打包依赖，
  # 运行时从 PATH 查找。
  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    install -m 755 fmt-file $out/bin/fmt-file

    runHook postInstall
  '';

  meta = {
    description = "统一的代码格式化入口（按语言分发到 nixfmt/shfmt/ruff/biome/prettierd 等，并支持 Markdown 内嵌代码块）";
    mainProgram = "fmt-file";
    platforms = lib.platforms.unix;
  };
}
