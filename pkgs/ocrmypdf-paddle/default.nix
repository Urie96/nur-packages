# PaddleOCR（PP-OCRv6 / PaddleOCR-VL）引擎插件，给 OCRmyPDF / paperless 用。
#
#   https://github.com/Urie96/ocrmypdf-paddle-plugin
#
# 上游是 clefru/ocrmypdf-paddleocr 的 fork（MPL-2.0），相对上游加了
#   --paddle-inference-engine {auto,paddle,onnxruntime}   推理后端可选
#   --paddle-no-mkldnn                                    绕开 oneDNN 崩溃
#   --paddle-det-limit-{type,side-len}                    检测输入尺寸（默认 max/960）
#   以及按进程缓存的模型实例（上游每页都重建一次 pipeline）。
{
  lib,
  fetchFromGitHub,
  pythonPackages,
  withOnnxRuntime ? true,
}:

pythonPackages.buildPythonPackage {
  pname = "ocrmypdf-paddleocr";
  version = "0.2.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = "ocrmypdf-paddle-plugin";
    rev = "c4eed141d787d4211435c17c7c912775c5d98501";
    hash = "sha256-fySDGYbM4oDiKw5UH+ceig2qCOsuJ9ZlagcgDEG7I9U=";
  };

  build-system = [ pythonPackages.setuptools ];

  # 这个插件永远是「被嵌进宿主 python 环境」用的（nur.ocrmypdf / nur.paperless
  # 都在自己的 scope 里 callPackage 它），ocrmypdf 由宿主提供 —— 在这里依赖它
  # 会成环，还会多带一份 ocrmypdf（+ 全语言 tesseract）进闭包。
  # 但 wheel 元数据里仍写着 Required-Dist: ocrmypdf，nixpkgs 的
  # checkPythonRuntimeDeps 会报 "ocrmypdf not installed"；pythonRelaxDeps 对
  # 源码构建无效（只处理 wheel），所以直接在 pyproject 里把这条要求删掉。
  postPatch = ''
    sed -i '/"ocrmypdf>=/d' pyproject.toml
  '';

  dependencies =
    with pythonPackages;
    [
      paddleocr
      paddlepaddle
      pillow
    ]
    ++ lib.optionals withOnnxRuntime [ onnxruntime ]
    # paddlex 把 imagesize / pypdfium2 / python-bidi / opencv-contrib-python 声明在
    # "ocr-core" extra 里，而 nixpkgs 不传播 optional-dependencies；缺了它们
    # PaddleOCR() 初始化时用 importlib.metadata 逐个检查，直接抛 DependencyError。
    # opencv-contrib-python 在 nixpkgs 里是 meta 包，纯为满足名字检查。
    ++ [
      imagesize
      pypdfium2
      python-bidi
      opencv-contrib-python
    ];

  doCheck = false;
  pythonImportsCheck = [ "ocrmypdf_paddleocr" ];

  meta = {
    description = "PaddleOCR (PP-OCRv6 / PaddleOCR-VL) engine plugin for OCRmyPDF";
    homepage = "https://github.com/Urie96/ocrmypdf-paddle-plugin";
    license = lib.licenses.mpl20;
    platforms = [ "x86_64-linux" ];
  };
}
