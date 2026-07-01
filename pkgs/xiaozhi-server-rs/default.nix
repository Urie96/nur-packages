{
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  libopus,
  onnxruntime,
  makeWrapper,
  stdenv,
}:
rustPlatform.buildRustPackage rec {
  pname = "xiaozhi-server-rs";
  version = "0-unstable-2026-07-01";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = pname;
    rev = "cd438ebc6097640098f6f7546dbca6938a68f460";
    sha256 = "sha256-S+2Pcsry3qLOtsT68CT7eIjHjmBNESYN6N0vopUmvbY=";
  };
  cargoHash = "sha256-FJGiQjSbNvN42+XE4qyIPrlkzOYWz512DFO1sbpN7xc=";

  nativeBuildInputs = [
    pkg-config
    makeWrapper
  ];

  buildInputs = [
    openssl
    libopus
    onnxruntime
  ];

  postInstall =
    let
      libLibraryPathKey = if stdenv.isDarwin then "DYLD_LIBRARY_PATH" else "LD_LIBRARY_PATH";

    in
    ''
      wrapProgram $out/bin/xiaozhi-server-rs \
        --prefix ${libLibraryPathKey} : ${onnxruntime}/lib \
        --set XIAOZHI_SPEAKER_MODEL_PATH ${src}/models/voxceleb_resnet34.onnx \
        --set XIAOZHI_VAD_MODEL_PATH ${src}/models/silero_vad.onnx
    '';

  meta.mainProgram = "xiaozhi-server-rs";
}
