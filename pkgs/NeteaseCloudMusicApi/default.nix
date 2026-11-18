{
  buildNpmPackage,
  fetchzip,
}:

buildNpmPackage rec {
  pname = "NeteaseCloudMusicApi";
  version = "4.33.0";
  src = fetchzip {
    url = "https://registry.npmjs.org/${pname}/-/${pname}-${version}.tgz";
    hash = "sha256-EDiEC8+2kHPO/A0rv/U3PE7ZsV/2SbbqHKK45KzRg70=";
  };
  npmDepsHash = "sha256-cFtxA8n1G9mZBD8vBEFOAjPyy559BBSOIkGBhwxpiFU=";

  dontNpmBuild = true;
  postPatch = ''
    cp ${./package-lock.json} ./package-lock.json
  '';
  production = true;

  meta.mainProgram = "NeteaseCloudMusicApi";
}
