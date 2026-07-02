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
  version = "0-unstable-2026-07-02";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = pname;
    rev = "6624b1260b32f41b97c95e5583d2be6a6c8c7ebe";
    sha256 = "sha256-pE6xFTCY1VJb/aT96YfNH8Ob5B45oRoFPfyegOko+PQ=";
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
