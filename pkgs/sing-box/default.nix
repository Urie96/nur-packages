{
  lib,
  buildGoModule,
  fetchFromGitHub,
  installShellFiles,
  coreutils,
  stdenv,
}:

buildGoModule (finalAttrs: {
  pname = "sing-box";
  version = "1.14.0-alpha.17";

  src = fetchFromGitHub {
    owner = "SagerNet";
    repo = "sing-box";
    tag = "v${finalAttrs.version}";
    hash = "sha256-7NJNhS6lZDX1O4YjtAIgcwSPBPqMjl9tG3lMYZ74VIw=";
  };

  vendorHash = "sha256-iuvWF7u1dOeFwQJMJaL5trGOH0ztTsr/GvTJ7zheSUk=";

  tags = [
    "with_gvisor"
    "with_quic"
    "with_dhcp"
    "with_wireguard"
    "with_utls"
    "with_acme"
    "with_clash_api"
    "with_tailscale"
    "with_ccm"
    "with_ocm"
    "badlinkname"
    "tfogo_checklinkname0"
  ];

  subPackages = [
    "cmd/sing-box"
  ];

  # darwin 上 local DNS transport 的 Exchange 实现在 local_darwin_cgo.go 里
  # （1.14.0-alpha 起从 local_darwin.go 拆出去的），必须开启 cgo 才能编译，
  # 上游 darwin CI 也是 CGO_ENABLED=1。
  env.CGO_ENABLED = if stdenv.hostPlatform.isDarwin then 1 else 0;

  nativeBuildInputs = [ installShellFiles ];

  ldflags = [
    "-X=github.com/sagernet/sing-box/constant.Version=${finalAttrs.version}"
    "-X=internal/godebug.defaultGODEBUG=multipathtcp=0"
    "-checklinkname=0"
  ];

  postInstall = ''
    installShellCompletion release/completions/sing-box.{bash,fish,zsh}

    substituteInPlace release/config/sing-box{,@}.service \
      --replace-fail "/usr/bin/sing-box" "$out/bin/sing-box" \
      --replace-fail "/bin/kill" "${coreutils}/bin/kill"
    install -Dm444 -t "$out/lib/systemd/system/" release/config/sing-box{,@}.service

    install -Dm444 release/config/sing-box.rules $out/share/polkit-1/rules.d/sing-box.rules
    install -Dm444 release/config/sing-box-split-dns.xml $out/share/dbus-1/system.d/sing-box-split-dns.conf
  '';

  meta = {
    homepage = "https://sing-box.sagernet.org";
    description = "Universal proxy platform";
    license = lib.licenses.gpl3Plus;
    maintainers = with lib.maintainers; [
      nickcao
      prince213
    ];
    mainProgram = "sing-box";
  };
})
