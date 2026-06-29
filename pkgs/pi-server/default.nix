{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpmConfigHook,
  makeWrapper,
  nodejs,
  pnpm,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "pi-server";
  version = "0.1.0-unstable-2026-06-29";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = "pi-server";
    rev = "456a27769eb850bc38b7e2d7061f4b6fcdd588d8";
    hash = "sha256-7VDbP7yejwPIsrkVJK7cyXxipZWFljMR3pfv6TCF3cc=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    inherit pnpm;
    fetcherVersion = 4;
    hash = "sha256-V7aOE4po1QMU6OO1W94Z9gvGi0ejkB1dihzALTWLFIg=";
  };

  nativeBuildInputs = [
    makeWrapper
    nodejs
    pnpm
    pnpmConfigHook
  ];

  buildPhase = ''
    runHook preBuild

    pnpm run build
    pnpm prune --prod

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/pi-server
    cp -r dist package.json node_modules $out/lib/pi-server/

    makeWrapper ${lib.getExe nodejs} $out/bin/pi-server \
      --add-flags "$out/lib/pi-server/dist/index.js" \
      --set-default NODE_ENV production

    runHook postInstall
  '';

  meta = {
    description = "Long-running HTTP/SSE bridge around pi-coding-agent for xiaozhi-server-rs";
    mainProgram = "pi-server";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
