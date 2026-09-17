{
  python3,
}:
python3.pkgs.buildPythonApplication {
  pname = "xopen";
  version = "0.1.0";

  src = ./.;
  pyproject = false;

  dontWrapPythonPrograms = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    install -m 755 xopen.py $out/bin/xopen

    runHook postInstall
  '';
}
