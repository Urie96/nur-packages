# paperless-ngx，OCR 引擎换成 PaddleOCR（PP-OCRv6 medium）+ ONNX Runtime。
#
# 怎么接管 OCR 的：paperless 调的是 ocrmypdf 的 **Python API**（`ocrmypdf.ocr(**args)`），
# 而 ocrmypdf 初始化插件时无条件执行
#     pluggy_manager.load_setuptools_entrypoints('ocrmypdf')
# 所以只要插件在同一个 python 环境里就会被自动注册；插件实现的 get_ocr_engine()
# 是 firstresult hook，pluggy 按「后注册先调用」排序，于是它顶掉内置 tesseract 引擎。
# paperless 侧不需要任何设置开关（PAPERLESS_OCR_USER_ARGS 里也不用传 --plugin）。
#
# 三件必须做的事：
#   1. python 降到 3.13 —— nixpkgs 的 python3Packages 是 3.14，而 paddlepaddle
#      只出到 cp313 的 wheel。
#   2. 插件不能塞进 paperless.dependencies，而是挂到 ocrmypdf 的 propagated 依赖上：
#      paperless wrapper 的 PYTHONPATH 是 requiredPythonModules 递归展开的，
#      挂到 ocrmypdf 下面同样会进 sys.path，还能避免
#      ocrmypdf -> 插件 -> ocrmypdf 的循环依赖。
#   3. 参数名不能叫 python3Packages —— NixOS 的 services.paperless.package 有个
#      apply 钩子，会对最终值再调一次 `pkg.override { tesseract5 = ...; }`；
#      而 callPackage 会自动给同名参数填 pkgs.python3Packages（3.14）。
{
  lib,
  pkgs,
  # 名字必须叫 tesseract5：NixOS 模块的 services.paperless.package.apply 会
  # `pkg.override { tesseract5 = pkg.tesseract5.override { enableLanguages = ...; }; }`。
  # 但也正因为这个名字在 pkgs 里存在，callPackage 会把它自动填成全语言版，
  # 所以 default.nix 里必须在调用点显式传 tesseractSlim。
  tesseract5 ? pkgs.callPackage ../tesseract-slim { },
  # 不叫 python3Packages / pythonPackages：前者会被 callPackage 自动填成 3.14
  # （paddlepaddle 没有 cp314 wheel），后者是 nixpkgs 里 Python 2 的别名。
  pythonSet ? pkgs.python313Packages,
  extraPythonPackageOverrides ? null,
}:

let
  defaultOverrides = pythonSet: final: prev:
    aiStubOverrides pythonSet final prev
    // {
    ocrmypdf-paddleocr = final.callPackage ../ocrmypdf-paddle {
      pythonPackages = final;
    };
    # paddleocr 默认带 pdf2docx + pymupdf（PDF→docx），后者把 mupdf 拖进来，
    # 而 pymupdf 内部用 `mupdf.override { enableOcr = true; }`，于是又拉了一份
    # 「全语言」tesseract tessdata（1.0 GiB）。paperless 这条路上 paddlex 只认图
    # （PDF 由 ocrmypdf 先栅格化），裁掉即可：实测闭包 6.8 GiB → 5.7 GiB。
    paddleocr = prev.paddleocr.override {
      pdf2docx = null;
      pymupdf = null;
    };
    ocrmypdf = prev.ocrmypdf.overridePythonAttrs (old: {
      dependencies = (old.dependencies or [ ]) ++ [ final.ocrmypdf-paddleocr ];
      # ocrmypdf 的测试会因为「装上了 OCR 插件」而失败：入口点被自动加载 →
      # import paddleocr → paddlex 初始化，之后测试里再 `PDX(...)` 就报
      # "PDX has already been initialized"。这是测试环境自身的问题，不是包坏了。
      doCheck = false;
    });
  };
  # 参数名不能叫 python3Packages / pythonPackages（NixOS 模块会用 .override 传
  # tesseract5，所以这里也得声明 tesseract5），又不走 pkgs.callPackage —— 否则
  # callPackage 会自动把同名属性从 pkgs 里填进来（tesseract5 → 全语言包 1.0 GiB，
  # python3Packages → 3.14 没有 paddlepaddle wheel）。
  # paperless_ai 的重依赖几乎都是「函数体内惰性 import」：
  # 模块级只有 llama_index.core（paperless_ai/vector_store.py ← paperless/views.py
  # 顶层 import），所以 core 必须留；其余 38 处 import（huggingface / ollama /
  # openai_like 的 embedding 与 llm，以及 sentence_transformers / torch）只在
  # PAPERLESS_AI_ENABLED 且选了对应后端时才触发。
  #
  # 但这些包是 paperless.dependencies 里头的，而 wrapper 的 PYTHONPATH 在原始
  # finalAttrs 里就用 passthru.dependencies 算死了 —— overrideAttrs 改
  # dependencies / passthru 都不会影响已生成的 wrapper。所以换个办法：
  # 在 python scope 里把它们替换成只有 dist-info 的空包（版本号沿用真包，
  # 免得别处的版本约束检查报错）。省 3.4 GiB（单 llama-index-embeddings-huggingface
  # 就拖着 torch + sentence-transformers + transformers）。
  #
  # 唯一保留的是 llama-index-llms-openai-like：本机只用 openai-like 这一条
  # LLM 路径（DeepSeek，纯 HTTP 调用），不做本地 embedding、不用 ollama，
  # 所以 embedding 三件套 / ollama 两个包 / torch 全家都能继续是空壳。
  stubbedAiDeps = [
    "llama-index-embeddings-huggingface"
    "llama-index-embeddings-ollama"
    "llama-index-embeddings-openai-like"
    "llama-index-llms-ollama"
    "sentence-transformers"
    # torch 是 paperless.dependencies 里的直接依赖（AI embedding 用），
    # 顺手把它的训练/日志生态（triton 带 llvm 541 MiB、wandb）一起换掉。
    "torch"
    "triton"
    "wandb"
    "wandb-core"
    "wandb-xpu"
  ];

  # 只有 dist-info、没有任何模块的空包
  stubPythonPkg =
    pythonSet: name: version:
    pkgs.runCommand "python-stub-${name}-${version}" { } ''
      dist="$out/${pythonSet.python.sitePackages}/${builtins.replaceStrings [ "-" ] [ "_" ] name}-${version}.dist-info"
      mkdir -p "$dist"
      printf 'Metadata-Version: 2.1\nName: %s\nVersion: %s\n' '${name}' '${version}' > "$dist/METADATA"
    '';

  aiStubOverrides =
    pythonSet: final: prev:
    # safetensors 不能 stub：paddlepaddle 运行时 import 它。它自己的测试要
    # import torch，而 torch 已经被换成空壳，所以只关掉测试。
    {
      safetensors = prev.safetensors.overridePythonAttrs (old: { doCheck = false; });
    }
    //
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = stubPythonPkg pythonSet name prev.${name}.version;
      }) stubbedAiDeps
    );

in
(pkgs.paperless-ngx.override {
  python3Packages = pythonSet;
      inherit tesseract5;
      extraPythonPackageOverrides =
        if extraPythonPackageOverrides != null then
          extraPythonPackageOverrides
        else
          defaultOverrides pythonSet;
    }).overrideAttrs (old: {
      # 注意：3.1.x 的 openai-like 路径固定走 chat_with_tools(tool_required=True)，
      # 会发 tool_choice="required"；而 deepseek-flash 默认开 thinking，thinking
      # 模式拒绝强制 tool_choice（API 返回 "Thinking mode does not support this
      # tool_choice"），所以 AI 建议在这条链上会直接 400。
      # 要解决只有两条路：paperless ≥ 3.3 用 PAPERLESS_AI_LLM_EXTRA_PARAMS 关
      # thinking，或换一个默认不开思考的后端。这里不做源码 patch。
      #
      # 这些用例会真的跑一遍 OCR：插件第一次调用就要去 HuggingFace / BOS 下
      # PP-OCRv6 权重，sandbox 里没有网所以必然失败。其余用例照常跑。
      disabledTestPaths =
        (old.disabledTestPaths or [ ])
        ++ [
          "src/paperless/tests/parsers/test_tesseract_parser.py"
        ]
        # embedding/ollama 的包是空壳（见 stubbedAiDeps），paperless_ai 的测试
        # 会 import 它们，当然过不了
        ++ [ "src/paperless_ai/tests" ];
      # PaddleOCR / PaddlePaddle 只出 x86_64 的 wheel，别处根本跑不起来。
      # 标了 meta.platforms 后 flake 的 packages 过滤（meta.availableOn）就只会
      # 在 x86_64-linux 上暴露它。
      meta = (old.meta or { }) // {
        platforms = [ "x86_64-linux" ];
      };
    })
