{
  lib,
  runCommand,
  python3,
  paperless-gpt,
}:

{
  smoke =
    runCommand "paperless-gpt-smoke-test"
      {
        nativeBuildInputs = [ python3 ];
      }
      ''
        python ${./smoke-test.py} \
          ${lib.getExe paperless-gpt} \
          ${paperless-gpt.version} \
          ${paperless-gpt.src}/tests/pdf/sample.pdf
        touch "$out"
      '';
}
