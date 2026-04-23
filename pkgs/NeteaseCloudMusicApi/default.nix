{
  buildNpmPackage,
  fetchzip,
}:

buildNpmPackage rec {
  pname = "NeteaseCloudMusicApi";
  version = "4.31.0";
  src = fetchzip {
    url = "https://registry.npmjs.org/${pname}/-/${pname}-${version}.tgz";
    hash = "sha256-qAYWmXys3TDugaTZcHtCBq4GbVcV2AxqAEpTRQjVIw4=";
  };
  npmDepsHash = "sha256-Kf7lfwFdq1kV9wYE4XfN+Gck7ecIi4nGa9u9KiVT+p8=";

  dontNpmBuild = true;
  postPatch = ''
    cp ${./package-lock.json} ./package-lock.json
  '';
  production = true;

  meta.mainProgram = "NeteaseCloudMusicApi";
}
