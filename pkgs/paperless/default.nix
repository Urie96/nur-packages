# paperless-ngx，只做一件事：把 paperless_ai 的重依赖换成「只有 dist-info 的空包」。
#
# OCR 不在这里处理了。以前这层还负责「换 python scope + 把 OCR 插件挂到 ocrmypdf
# 的依赖上」，那种改法会让 tesseract / ocrmypdf / paperless-ngx 三个包全部退出
# cache.nixos.org；现在 OCR 引擎走 nixos-config 里的
# services.paperless.extraPythonPackages（只加 PYTHONPATH），package 保持官方派生。
#
# 为什么还要这个包：paperless_ai 的重依赖几乎都是「函数体内惰性 import」。
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
#
# 注意：用了这个包就不再命中官方缓存（paperless-ngx 要本地重建）。
# 只要缓存、不介意多 3.4 GiB 的 torch，就用 nixpkgs 的 paperless-ngx。
{
  lib,
  pkgs,
  # 不叫 python3Packages：NixOS 模块会用 .override 传 tesseract5，而我们又想
  # 让调用点显式决定 scope，所以不用 pkgs.callPackage 的自动填充。
  pythonSet ? pkgs.python3Packages,
  extraPythonPackageOverrides ? null,
}:

let
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
    # safetensors 不能 stub（nixpkgs 里别的包会 import 它），但它的测试要
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
  extraPythonPackageOverrides =
    if extraPythonPackageOverrides != null then
      extraPythonPackageOverrides
    else
      aiStubOverrides pythonSet;
}).overrideAttrs (old: {
  # 注意：3.1.x 的 openai-like 路径固定走 chat_with_tools(tool_required=True)，
  # 会发 tool_choice="required"；而 deepseek-flash 默认开 thinking，thinking
  # 模式拒绝强制 tool_choice（API 返回 "Thinking mode does not support this
  # tool_choice"），所以 AI 建议在这条链上会直接 400。
  # 要解决只有两条路：paperless ≥ 3.3 用 PAPERLESS_AI_LLM_EXTRA_PARAMS 关
  # thinking，或换一个默认不开思考的后端。这里不做源码 patch。
  disabledTestPaths =
    (old.disabledTestPaths or [ ])
    # 时钟相关的上游 flake，与我们的改动无关：该测试 @override_settings
    # TIME_ZONE="America/Chicago"，而 consumer 用
    # timezone.make_aware(fromtimestamp(st_mtime)) 造 created（fromtimestamp
    # 取进程 TZ = 沙箱里的 UTC），再用 timezone.localtime(now) 取"今天"。
    # 于是 UTC 日期与 Chicago 日期不同的那段时间（Chicago 00:00-06:00，
    # 即 UTC 06:00-12:00）断言 created.day == today 必然差一天，
    # 报 AssertionError: 13 != 12。见上游同族问题。
    ++ [ "src/documents/tests/test_consumer.py::TestConsumer::testNormalOperation" ]
    # embedding/ollama 的包是空壳（见 stubbedAiDeps），paperless_ai 的测试
    # 会 import 它们，当然过不了
    ++ [ "src/paperless_ai/tests" ];
})
