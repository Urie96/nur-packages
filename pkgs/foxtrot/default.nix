{
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "foxtrot";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "Formlabs";
    repo = pname;
    rev = "69fb37688892246e670fc08eb60b7d3a92d70d3f";
    sha256 = "sha256-fL3/Zwz+N2nmY1geHSvYTB8KYO1wt2BGqHFZgR6c6WE=";
  };

  prePatch = ''
    cp ${./Cargo.lock} ./Cargo.lock
  '';

  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  # cargoBuildFeatures = [ "bundle-shaders" ];
  cargoBuildFlags = "--features=bundle-shaders";

  nativeBuildInputs = [ ];

  buildInputs = [ ];

  postInstall = ''
    # 如果生成的是 gui，重命名为 foxtrot
    if [ -f $out/bin/gui ]; then
      mv $out/bin/gui $out/bin/foxtrot
    fi
  '';
}
