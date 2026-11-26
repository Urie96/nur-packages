{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "herdr-reviewr";
  version = "0.52.2";

  src = fetchFromGitHub {
    owner = "persiyanov";
    repo = "herdr-reviewr";
    tag = "v${finalAttrs.version}";
    hash = "sha256-DcNNuP529AhERUhnM0qHNYZuqlCghmc+psiKrX4l+gw=";
  };

  cargoHash = "sha256-lPIvi3ImQ606lADDF0CPpjVGs8uU2neL/C4usUG2QW8=";

  nativeBuildInputs = [ pkg-config ];

  # The manifest pins rust-version = 1.99.1, newer than nixpkgs' rustc; the pin
  # is a patch bump with no MSRV-only feature behind it, so relax it. Patched
  # after the vendor check, which only compares Cargo.lock.
  postPatch = ''
    substituteInPlace Cargo.toml \
      --replace-fail 'rust-version = "1.99.1"' 'rust-version = "1.98.1"'
  '';

  # The tests spawn herdr panes, git repos and PTYs; keep the build hermetic.
  doCheck = false;

  # Not `cargoInstallHook`: the output is the plugin root herdr expects, so
  # `herdr plugin link $out` finds the manifest and the `bin/herdr-reviewr`
  # its panes, actions and event hooks run.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    # cargoBuildHook builds with an explicit --target, so the binary lands in
    # target/<triple>/release rather than target/release.
    install -m755 target/${stdenv.targetPlatform.rust.cargoShortTarget}/release/herdr-reviewr \
      $out/bin/herdr-reviewr
    install -m644 herdr-plugin.toml $out/herdr-plugin.toml

    runHook postInstall
  '';

  meta = {
    description = "Code-review pane for herdr: read your agent's diff beside the chat and send comments back";
    longDescription = ''
      A herdr plugin pane that shows the agent's diff syntax-highlighted,
      lets you comment on lines and ranges, and sends those comments into the
      agent's input. Unified and split diff views, four diff scopes, a file
      viewer, search, a read-only PR tab, and 20 themes.
    '';
    homepage = "https://github.com/persiyanov/herdr-reviewr";
    changelog = "https://github.com/persiyanov/herdr-reviewr/blob/v${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.mit;
    mainProgram = "herdr-reviewr";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
  };
})
