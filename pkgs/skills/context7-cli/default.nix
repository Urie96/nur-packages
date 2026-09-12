{
  lib,
  buildPythonApplication,
  hatchling,
  mkSkill,
}:

let
  app = buildPythonApplication {
    pname = "context7-cli";
    version = "0.1.0";

    src = ./.;

    pyproject = true;

    build-system = [ hatchling ];

    dependencies = [ ];
  };
in
mkSkill ./skill app
