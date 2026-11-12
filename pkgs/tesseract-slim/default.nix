# 只编需要的语言包的 tesseract。
#
# OCR 走 PaddleOCR 之后 tesseract 只剩一个用途：ocrmypdf 内置 tesseract 插件的
# check_options 会无条件执行 `tesseract --version`（pluggy 会把所有 check_options
# 都跑一遍，跟选哪个 engine 无关）。
#
# 但默认的 tesseract 带「全语言」tessdata：
#   闭包 1.1 GiB，其中 tessdata "all" 占 1014.8 MiB
# 收窄到 eng + chi_sim（+ equ/osd，tesseract 自带要求）后：
#   闭包 168.6 MiB
#
# 如果要加语言就改下面这一行；`PAPERLESS_OCR_LANGUAGE` 那种运行时语言参数
# 对 PaddleOCR 引擎没影响（插件自己决定模型），所以不需要跟它对齐。
{ tesseract }:
tesseract.override {
  enableLanguages = [
    "eng"
    "chi_sim"
    "equ"
    "osd"
  ];
}
