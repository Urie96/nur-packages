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
  version = "0-unstable-2026-07-02";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = "pi-server";
    rev = "719064f6a17879a099a94cf46b0ab959eac21a51";
    hash = "sha256-NNqM8xFQxVBRDJvuYvBLZTPGCI7igB9//QkFSxSonPI=";
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
