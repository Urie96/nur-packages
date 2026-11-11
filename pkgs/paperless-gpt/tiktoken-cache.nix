{
  lib,
  fetchurl,
  linkFarm,
}:

# tiktoken-go keys cached encodings by the SHA-1 of their download URL.
# Ship all four encodings it supports so token counting also works offline.
linkFarm "paperless-gpt-tiktoken-cache" (
  lib.mapAttrsToList
    (
      encoding: hash:
      let
        url = "https://openaipublic.blob.core.windows.net/encodings/${encoding}.tiktoken";
      in
      {
        name = builtins.hashString "sha1" url;
        path = fetchurl { inherit url hash; };
      }
    )
    {
      cl100k_base = "sha256-Ijkht27pm96ZW3/3OFE+7xAPtR0YyTWXoRO8/+hlsqc=";
      o200k_base = "sha256-RGqVOMtsNI41FhINfAiwn1fDZJXirP/+WaW/iwz7Gi0=";
      p50k_base = "sha256-lLXKff9NAHZ7wlb90bJ+Wxc2HXuKX5aFR/nyPrcNIGk=";
      r50k_base = "sha256-MGzSfwPBpxTspxCOA9ZrfcBCq+jCWLRMGZp+2YON2TA=";
    }
)
