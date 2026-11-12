# 开箱可用的 OCRmyPDF 命令行：OCRmyPDF + PaddleOCR（PP-OCRv6）引擎插件 + 外部工具。
#
#   nix shell .#ocrmypdf -c ocrmypdf -l chi_sim in.pdf out.pdf
#
# 不需要 --plugin：插件用 entry point `[ocrmypdf] paddleocr = …` 注册，
# OCRmyPDF 启动时会无条件 load_setuptools_entrypoints('ocrmypdf')，
# 只要它和 ocrmypdf 在同一个 python 环境里就自动生效。
# （插件包本身只有 python 模块，没有 bin —— 它不是应用。）
{
  lib,
  pkgs,
  symlinkJoin,
  makeWrapper,
  makeFontsConf,
  python313Packages,
  ghostscript,
  qpdf,
  pngquant,
  tesseractSlim ? pkgs.callPackage ../tesseract-slim { },
  noto-fonts-cjk-sans,
}:

let
  # tesseractSlim 由 default.nix 统一传入（pkgs/tesseract-slim）
  runtimeDeps = [
    ghostscript
    qpdf
    pngquant
    tesseractSlim
  ];

  # 中文隐形文字层靠 fontconfig 找字体；不指过去会警告
  # "No installed font has glyphs for the detected 'chi_sim' text"
  # 且高亮时一片空白（文字仍可搜索/复制）。
  fontsConf = makeFontsConf {
    fontDirectories = [ noto-fonts-cjk-sans ];
  };

  # 插件的 ocrmypdf 依赖必须和这里的 ocrmypdf 是同一个实例，
  # 否则会多出一份用全语言 tesseract 的 ocrmypdf（白背 1 GiB）。
  py = python313Packages.overrideScope (
    final: prev: {
      ocrmypdf = prev.ocrmypdf.override { tesseract = tesseractSlim; };
      ocrmypdf-paddleocr = final.callPackage ../ocrmypdf-paddle {
        pythonPackages = final;
      };
      # paddleocr 默认带 pdf2docx + pymupdf（PDF→docx），后者把 mupdf 拖进来，
      # 而 pymupdf 内部用 `mupdf.override { enableOcr = true; }`，又拉了一份
      # 「全语言」tesseract tessdata（1.0 GiB）。命令行 OCR 用不到 PDF 解析，裁掉。
      # （paperless 那边同理，见 pkgs/paperless/default.nix）
      paddleocr = prev.paddleocr.override {
        pdf2docx = null;
        pymupdf = null;
      };
    }
  );
in
symlinkJoin {
  name = "ocrmypdf-with-paddleocr";
  # 注意这里不能写 `withPackages (ps: [ ps.xxx ])`：ps 是解释器自带的
  # python313Packages（没经过上面的 overrideScope），`ocrmypdf-paddleocr`
  # 不在里面。显式传 scope 里的 derivation 即可。
  paths = [
    (py.python.withPackages (_: [
      py.ocrmypdf
      py."ocrmypdf-paddleocr"
    ]))
  ]
  ++ runtimeDeps;

  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/ocrmypdf \
      --set FONTCONFIG_FILE ${fontsConf} \
      --prefix PATH : ${lib.makeBinPath runtimeDeps}
  '';

  meta = {
    description = "OCRmyPDF with the PaddleOCR (PP-OCRv6) engine plugin, ready to run";
    homepage = "https://github.com/Urie96/ocrmypdf-paddle-plugin";
    license = lib.licenses.mpl20;
    mainProgram = "ocrmypdf";
    platforms = [ "x86_64-linux" ];
  };
}
