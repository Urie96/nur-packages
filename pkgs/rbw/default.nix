{
  lib,
  stdenv,
  rustPlatform,
  fetchzip,
  openssl,
  pkg-config,
  installShellFiles,
  bash,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "rbw";
  version = "1.15.0";

  src = fetchzip {
    url = "https://git.tozt.net/rbw/snapshot/rbw-${finalAttrs.version}.tar.gz";
    hash = "sha256-N/s1flB+s2HwEeLsf7YlJG+5TJgP8Wu7PHNPWmVfpIo=";
  };

  # 上游尚未合并的修复：Vaultwarden 1.37.4+ 要求 cipher create/update 带上
  # encryptedFor 字段，否则 `rbw add` / `rbw edit` 会返回 HTTP 422。
  # https://github.com/doy/rbw/pull/386
  patches = [ ./0001-send-encryptedFor-on-cipher-create-and-update.patch ];

  cargoHash = "sha256-N4IxnAXDvD+vp3LUB9CKYM+1C5i1Flihk+Pfb2c5IWY=";

  nativeBuildInputs = [
    installShellFiles
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ pkg-config ];

  buildInputs = [ bash ]; # for git-credential-rbw

  preConfigure = lib.optionalString stdenv.hostPlatform.isLinux ''
    export OPENSSL_INCLUDE_DIR="${openssl.dev}/include"
    export OPENSSL_LIB_DIR="${lib.getLib openssl}/lib"
  '';

  postInstall = ''
    install -Dm755 -t $out/bin bin/git-credential-rbw
  ''
  + lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    installShellCompletion --cmd rbw \
      --bash <($out/bin/rbw gen-completions bash) \
      --fish <($out/bin/rbw gen-completions fish) \
      --nushell <($out/bin/rbw gen-completions nushell) \
      --zsh <($out/bin/rbw gen-completions zsh)
  '';

  meta = {
    description = "Unofficial command line client for Bitwarden (with encryptedFor fix)";
    homepage = "https://github.com/doy/rbw";
    changelog = "https://git.tozt.net/rbw/plain/CHANGELOG.md?id=${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "rbw";
    platforms = lib.platforms.unix;
  };
})
