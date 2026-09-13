{
  python3,
}:
python3.pkgs.buildPythonApplication {
  pname = "slim-kitten";
  version = "0.1.0";

  src = ./.;
  pyproject = false;

  dontWrapPythonPrograms = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    install -m 755 slim-kitten $out/bin/slim-kitten

    runHook postInstall
  '';
}
