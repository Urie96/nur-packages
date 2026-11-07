{
  lib,
  python3,
  fetchFromGitHub,
  fetchPypi,
  makeWrapper,
}:

let
  python = import ./python-deps.nix { inherit lib python3 fetchPypi; };
in
python.pkgs.buildPythonApplication rec {
  pname = "ownfoil";
  version = "2.5.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "a1ex4";
    repo = "ownfoil";
    tag = version;
    hash = "sha256-PaL7X4wpOPBHS4+OuYi72Z7UKBTcw6ypeSIUgD8/J/k=";
  };

  build-system = [ python.pkgs.hatchling ];

  dependencies = with python.pkgs; [
    flask
    flask-login
    flask-migrate
    flask-sock
    flask-sqlalchemy
    gunicorn
    nstools
    nsz
    pillow
    pycryptodome
    pyyaml
    requests
    setproctitle
    strawberry-graphql
    watchdog
    werkzeug
    zstandard
  ];

  nativeBuildInputs = [ makeWrapper ];

  # Upstream pins every dependency to an exact version (e.g. gunicorn==26.2.0,
  # werkzeug==3.1.9); nixpkgs ships other, compatible patch levels.
  pythonRelaxDeps = true;

  # Upstream tests need a Switch keys file and captured client traffic.
  doCheck = false;

  pythonImportsCheck = [ "ownfoil" ];

  postInstall = ''
    # Kept from upstream: `ownfoil [base_dir]` serves the app and keeps config/ and
    # data/ next to the directory it is started in. `ownfoil-server` is the same
    # production entrypoint (Gunicorn + task worker pool) but reads/writes its state
    # in XDG directories unless OWNFOIL_CONFIG_DIR / OWNFOIL_DATA_DIR are set, which
    # is what a NixOS/systemd unit needs since the app dir in the store is read-only.
    makeWrapper "${lib.getExe python}" "$out/bin/ownfoil-server" \
      --add-flags "$out/${python.sitePackages}/ownfoil/_app/run.py" \
      --prefix PYTHONPATH : "${python.pkgs.makePythonPath dependencies}:$out/${python.sitePackages}" \
      --run 'export OWNFOIL_CONFIG_DIR="''${OWNFOIL_CONFIG_DIR:-''${XDG_CONFIG_HOME:-$HOME/.config}/ownfoil}"' \
      --run 'export OWNFOIL_DATA_DIR="''${OWNFOIL_DATA_DIR:-''${XDG_DATA_HOME:-$HOME/.local/share}/ownfoil}"'
  '';

  meta = {
    description = "Self-hosted Nintendo Switch library manager and shop server";
    homepage = "https://github.com/a1ex4/ownfoil";
    changelog = "https://github.com/a1ex4/ownfoil/releases/tag/${version}";
    license = lib.licenses.agpl3Plus;
    mainProgram = "ownfoil-server";
    platforms = lib.platforms.unix;
  };
}
