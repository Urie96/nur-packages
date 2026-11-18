{
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "tgdl";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = pname;
    rev = version;
    sha256 = "sha256-0y0qzx7qXRrrVazxrDzBT/Ff8wrWHuqT9u4+XEiizEE=";
  };

  vendorHash = "sha256-E1ftuAFcUxG1ExVsFkC3US46BDi9vpFG5Pms1HtzUX4=";

  ldflags = [
    "-s"
    "-w"
  ];

  meta = {
    description = "Telegram channel video downloader, run as a systemd service";
    homepage = "https://github.com/Urie96/tgdl";
    # 仓库里还没有 LICENSE 文件；补上之后在这里填 licenses.mit（或其它）。
    platforms = [ "x86_64-linux" ];
    mainProgram = "tgdl";
  };
}
