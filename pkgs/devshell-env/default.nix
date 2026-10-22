{
  lib,
  bash,
  runCommandLocal,
  python3,
  devshell-bash,
  mkShellNoCC,
  name ? "devshell-env",
  buildInputs ? [ ],
  shellEnv ? { },
}:

let
  # Same derivation nix would build for `nix print-dev-env`, except that it is
  # reachable from the flake. Empty $out would be a valid JSON document, so the
  # output is a file rather than a directory.
  envJson = (mkShellNoCC ({ inherit buildInputs; } // shellEnv)).overrideAttrs (_: {
    name = "${name}-json";
    # No phases are run (get-env.sh is the whole builder), so there is nothing
    # to fix up either.
    builder = lib.getExe bash;
    args = [ ./get-env.sh ];
  });
in
runCommandLocal name
  {
    # Referenced by absolute path below; deliberately not buildInputs, since
    # their bin/ directories would show up in the rendered PATH.
    inherit envJson;
    dontFixup = true;
    meta.description = "Activation scripts for the ${name} devShell";
  }
  ''
    mkdir -p $out/share/devshell-env

    # direnv loads the environment with bash, so bash is all we render.
    ${python3.interpreter} ${lib.getExe devshell-bash} $envJson \
      > $out/share/devshell-env/activate.bash
  ''
