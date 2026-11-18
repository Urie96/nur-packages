{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "tgdl";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = pname;
    rev = version;
    sha256 = "sha256-nHuzniOscxeVYz5ckWM2/9dI4XXeqom/1erJyzW3g8g=";
  };

  vendorHash = "sha256-E1ftuAFcUxG1ExVsFkC3US46BDi9vpFG5Pms1HtzUX4=";

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with lib; {
    description = "Telegram channel video downloader, run as a systemd service";
    homepage = "https://github.com/Urie96/tgdl";
    # 仓库里还没有 LICENSE 文件；补上之后在这里填 licenses.mit（或其它）。
    platforms = platforms.unix;
    mainProgram = "tgdl";
  };
}
