{
  lib,
  python3,
}:
python3.pkgs.buildPythonApplication rec {
  pname = "apprise-server";
  version = "0.0.1";
  src = ./src;
  pyproject = false;

  dependencies = with python3.pkgs; [
    flask
    apprise
    gunicorn
  ];

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/${python3.sitePackages}/apprise-server
    cp * $out/${python3.sitePackages}/apprise-server

    makeWrapper ${lib.getExe python3.pkgs.gunicorn} $out/bin/apprise-server \
      --prefix PYTHONPATH : "$out/${python3.sitePackages}:${python3.pkgs.makePythonPath dependencies}" \
      --set-default CONFIG_PATH ~/.config/apprise/config.yaml \
      --set-default LISTEN_PORT 8000 \
      --set-default LISTEN_HOST '127.0.0.1' \
      --add-flags "apprise-server.app:app -b \"\$LISTEN_HOST:\$LISTEN_PORT\" -w 4"
  '';

  meta.mainProgram = "apprise-server";
}
