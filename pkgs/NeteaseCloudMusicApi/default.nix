{
  buildNpmPackage,
  fetchzip,
}:

buildNpmPackage rec {
  pname = "NeteaseCloudMusicApi";
  version = "4.32.0";
  src = fetchzip {
    url = "https://registry.npmjs.org/${pname}/-/${pname}-${version}.tgz";
    hash = "sha256-LAXVSh4E7MyLyr4EtN/PMXkTmScYaUrm7KIz404uaUU=";
  };
  npmDepsHash = "sha256-m5mhn3bKJkKkpVrXhs3h8zR+LvNo1SOjlgF37M5vz4U=";

  dontNpmBuild = true;
  postPatch = ''
    cp ${./package-lock.json} ./package-lock.json
  '';
  production = true;

  meta.mainProgram = "NeteaseCloudMusicApi";
}
