{
  lib,
  buildGo127Module,
  fetchFromGitHub,
}:
buildGo127Module (finalAttrs: {
  pname = "herdr-plugin-sesh";
  version = "0.18.0";

  src = fetchFromGitHub {
    owner = "fullerzz";
    repo = "herdr-plugin-sesh";
    tag = "v${finalAttrs.version}";
    hash = "sha256-68wwYtCduCZ5Lctlhh3PeVy3m30fEcNDk5rnCc7i3Vk=";
  };

  vendorHash = "sha256-+Ac65TffM1565e/enlnaoIrOBfWsLdJ98/MFwdm9JaU=";

  # Only cmd/herdr-sesh is a main package; the repo also holds tool directives
  # (`tool golang.org/x/perf/cmd/benchstat`) that must not be installed.
  subPackages = [ "cmd/herdr-sesh" ];

  # Release builds take the version from the tag instead of git describe.
  ldflags = [
    "-s"
    "-w"
    "-X=github.com/fullerzz/herdr-plugin-sesh/internal/app.Version=${finalAttrs.version}"
  ];

  # The tests spawn login shells, PTYs, herdr panes and remote-preview scripts,
  # so they assert on the developer's environment rather than on pure logic.
  doCheck = false;

  # The output is the plugin root herdr expects, so `herdr plugin link $out`
  # finds the manifest next to the `bin/herdr-sesh` its panes, actions and
  # event hooks run.
  postInstall = ''
    install -Dm644 herdr-plugin.toml $out/herdr-plugin.toml
  '';

  meta = {
    description = "Sesh-style workspace picker and session manager for herdr";
    longDescription = ''
      A herdr plugin that merges running workspaces, Sesh-style TOML sessions
      and zoxide history into one searchable overlay. Selecting an entry
      focuses the existing workspace or creates a new one with the configured
      startup command, tabs and pane layout. Also ships the `herdr-sesh` CLI
      (picker, connect, last, preview, clone, root, window, config) and herdr
      app mods for the desktop app.
    '';
    homepage = "https://github.com/fullerzz/herdr-plugin-sesh";
    changelog = "https://github.com/fullerzz/herdr-plugin-sesh/blob/v${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.mit;
    mainProgram = "herdr-sesh";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
  };
})
