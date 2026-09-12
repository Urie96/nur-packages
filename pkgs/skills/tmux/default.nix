{
  writeShellApplication,
  tmux,
  symlinkJoin,
  coreutils,
  gnugrep,
  mkSkill,
}:

let
  scripts = symlinkJoin {
    name = "tmux-scripts";
    paths = [
      (writeShellApplication {
        name = "find-sessions";
        runtimeInputs = [
          tmux
          coreutils
          gnugrep
        ];
        text = builtins.readFile ./scripts/find-sessions.sh;
      })
      (writeShellApplication {
        name = "wait-for-text";
        runtimeInputs = [
          tmux
          coreutils
          gnugrep
        ];
        text = builtins.readFile ./scripts/wait-for-text.sh;
      })
    ];
  };
in
mkSkill ./skill scripts
