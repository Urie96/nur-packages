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
  version = "0-unstable-2026-07-11";

  src = fetchFromGitHub {
    owner = "Urie96";
    repo = pname;
    rev = "9d3a60b311bf9f1f979f5e7c3d708a4ec30ca6c1";
    sha256 = "sha256-lvQxpW7B20lLpvn3AzqKFF39UbaKcM7AmnLhYWs6ELo=";
  };
  cargoHash = "sha256-8XIOv1Q3ZsbvoZjRU4YXlygXppfFIKEkN7DjgecGcDY=";

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
      libLibraryPathKey = if stdenv.hostPlatform.isDarwin then "DYLD_LIBRARY_PATH" else "LD_LIBRARY_PATH";
    in
    ''
      wrapProgram $out/bin/xiaozhi-server-rs \
        --prefix ${libLibraryPathKey} : ${onnxruntime}/lib \
        --set XIAOZHI_SPEAKER_MODEL_PATH ${src}/models/voxceleb_resnet34.onnx \
        --set XIAOZHI_VAD_MODEL_PATH ${src}/models/silero_vad.onnx
    '';

  meta.mainProgram = "xiaozhi-server-rs";
}
