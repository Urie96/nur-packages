{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  fontconfig,
  vim,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "herdr-nvim";
  version = "1.3.1";

  src = fetchFromGitHub {
    owner = "ChmaraX";
    repo = "herdr-nvim";
    tag = "v${finalAttrs.version}";
    hash = "sha256-/026mNSbhZIAMJeNdSsbi9vhUuQEfdjqI99QzKAHW6w=";
  };

  cargoHash = "sha256-YhOprgqqWHV4b2Md93BRTdKNFyCrYFV3pm6gy/hyoDk=";

  nativeBuildInputs = [
    pkg-config
    # `:help herdr-nvim` needs the plugin's doc/tags.
    vim
  ];

  # merman's Mermaid renderer looks its fonts up with fontconfig.
  buildInputs = lib.optional stdenv.hostPlatform.isLinux fontconfig;

  # The cargo test suite spawns nvim daemons, herdr panes and git repos.
  doCheck = false;

  # `doc/` belongs at the plugin root, where Neovim's runtimepath finds it
  # (`:help herdr-nvim`); stdenv's move-docs hook would put it in share/doc.
  forceShare = [
    "man"
    "info"
  ];

  # Not `cargoInstallHook`: the output is the plugin root itself, which both
  # halves of the TUI mode expect to find the same way:
  #  - `herdr plugin link $out` reads herdr-plugin.toml and runs its actions
  #    as `bin/herdr-nvim …` relative to the root; a linked plugin is never
  #    built, so a read-only store path is fine.
  #  - `daemon::plugin_root()` walks up from the running binary looking for
  #    `lua/herdr-nvim`, so `bin/` beside `lua/` is what finds the Lua.
  # With lua/ and plugin/ at the root it is also a plain Neovim plugin (add
  # it to runtimepath / vimPlugins), and because it carries bin/ putting the
  # same store path on PATH is enough for `:Herdr send` and friends, which
  # exec `herdr-nvim` from PATH.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    # cargoBuildHook builds with an explicit --target, so the binaries land in
    # target/<triple>/release rather than target/release.
    install -m755 target/${stdenv.targetPlatform.rust.cargoShortTarget}/release/herdr-nvim \
      $out/bin/herdr-nvim
    install -m644 herdr-plugin.toml $out/herdr-plugin.toml
    cp -r lua plugin doc $out/

    vim -u NONE -es -c "helptags $out/doc" -c q

    runHook postInstall
  '';

  meta = {
    description = "Neovim sidebar for the herdr workspace, with a file picker and agent annotations";
    longDescription = ''
      A persistent Neovim sidebar inside a herdr workspace: fuzzy file picker
      over the files the agent touched, code comments sent to the agent as a
      review, inline path:line references, a file tree and a markdown/image
      preview. This is the herdr TUI plugin (herdr >= 0.7.5) plus the Neovim
      plugin it drives; the Herdr desktop app's mod is not included.
    '';
    homepage = "https://github.com/ChmaraX/herdr-nvim";
    license = lib.licenses.mit;
    mainProgram = "herdr-nvim";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
  };
})
