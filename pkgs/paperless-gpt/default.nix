{
  lib,
  buildGo127Module,
  callPackage,
  fetchFromGitHub,
  makeWrapper,
}:

buildGo127Module (finalAttrs: {
  pname = "paperless-gpt";
  version = "0.31.0";

  src = fetchFromGitHub {
    owner = "icereed";
    repo = "paperless-gpt";
    tag = "v${finalAttrs.version}";
    hash = "sha256-h4zpHWSpSBzPj6M9ORtx1w68F/ajORSyIUddnAXaQl0=";
  };

  vendorHash = "sha256-feA4BVMfkZnU3ZoFZsIofs9AzH7G8r2j2tHgPnYC+uM=";
  # Upstream's environment-registry test recursively audits its source tree.
  # Keep dependencies outside that tree, in the module cache rather than vendor/.
  proxyVendor = true;

  patches = [
    ./default-prompts-dir.patch
    # OPENAI_EXTRA_BODY：给 OpenAI 兼容端点透传请求体字段（用来关掉 DeepSeek 默认的思考模式）。
    ./openai-extra-body.patch
  ];

  nativeBuildInputs = [ makeWrapper ];

  # SQLite uses CGO; PDFium is embedded WebAssembly and needs no system library.
  env.CGO_ENABLED = 1;

  subPackages = [ "." ];

  ldflags = [
    "-s"
    "-w"
    "-X=main.version=${finalAttrs.version}"
    "-X=main.commit=v${finalAttrs.version}"
    "-X=main.buildDate=unknown"
  ];

  # The Go binary embeds web-app/dist. Do this after vendoring, so fetching Go
  # dependencies does not depend on building the frontend.
  postConfigure = ''
    cp -r ${finalAttrs.passthru.frontend} web-app/dist
  '';

  checkPhase = ''
    runHook preCheck

    export HOME="$TMPDIR"
    export TIKTOKEN_CACHE_DIR=${finalAttrs.passthru.tiktokenCache}
    export GOFLAGS=''${GOFLAGS//-trimpath/}
    go test -p "$NIX_BUILD_CORES" ./...

    runHook postCheck
  '';

  postInstall = ''
    mkdir -p "$out/share/paperless-gpt"
    cp -r default_prompts "$out/share/paperless-gpt/"

    wrapProgram "$out/bin/paperless-gpt" \
      --set-default GIN_MODE release \
      --set-default PAPERLESS_GPT_DEFAULT_PROMPTS_DIR "$out/share/paperless-gpt/default_prompts" \
      --set-default TIKTOKEN_CACHE_DIR ${finalAttrs.passthru.tiktokenCache}
  '';

  passthru = {
    frontend = callPackage ./frontend.nix { inherit (finalAttrs) src version; };
    tiktokenCache = callPackage ./tiktoken-cache.nix { };
    tests = callPackage ./tests.nix { paperless-gpt = finalAttrs.finalPackage; };
  };

  meta = {
    description = "LLM-powered OCR and document metadata generation for Paperless-ngx";
    homepage = "https://github.com/icereed/paperless-gpt";
    changelog = "https://github.com/icereed/paperless-gpt/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "paperless-gpt";
    platforms = [
      "x86_64-linux"
    ];
  };
})
