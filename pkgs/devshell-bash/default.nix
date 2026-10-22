{
  python3,
}:
python3.pkgs.buildPythonApplication {
  pname = "devshell-bash";
  version = "0.3.0";

  src = ./.;
  pyproject = false;

  dontWrapPythonPrograms = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    install -m 755 devshell-bash.py $out/bin/devshell-bash

    runHook postInstall
  '';

  meta.mainProgram = "devshell-bash";
}
