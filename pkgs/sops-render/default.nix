{
  buildGoModule,
}:
buildGoModule {
  pname = "sops-render";
  version = "0.1.0";
  src = ./src;

  # 直接用 sops 库解密（github.com/getsops/sops/v3/decrypt），不 fork sops 进程。
  # 代价是二进制会静态链接全部 key backend（age/pgp/AWS KMS/GCP KMS/Azure/Vault）。
  vendorHash = "sha256-BXCBitrOZZG43ZAux7Ln9fP0lxdNAyOtXkyOaHRV+K0=";

  ldflags = [
    "-s"
    "-w"
  ];

  meta = {
    description = "用 sops 解密 secrets 并把模板渲染成明文文件";
    mainProgram = "sops-render";
  };
}
