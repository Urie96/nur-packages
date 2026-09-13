{
  python3,
}:
python3.pkgs.buildPythonApplication {
  pname = "coding-agent-status";
  version = "0.1.0";

  src = ./.;
  pyproject = false;

  dontWrapPythonPrograms = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    install -m 755 coding-agent-status $out/bin/coding-agent-status

    runHook postInstall
  '';
}
