{
  buildNpmPackage,
  fetchzip,
}:

buildNpmPackage rec {
  pname = "NeteaseCloudMusicApi";
  version = "4.34.1";
  src = fetchzip {
    url = "https://registry.npmjs.org/${pname}/-/${pname}-${version}.tgz";
    hash = "sha256-1ktmlev+oH97L7uwHz/x5vrwcgdvV7QdaTk+oloSNxk=";
  };
  npmDepsHash = "sha256-TYNJrMupOWx1OQ0oXUyqpriB5lEYuoswIt8jgFoTdEQ=";

  dontNpmBuild = true;
  postPatch = ''
    cp ${./package-lock.json} ./package-lock.json
  '';
  production = true;

  meta.mainProgram = "NeteaseCloudMusicApi";
}
