{
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fira-mono-italic";
  version = "unstable-2015-03-06";

  srcs = [
    (fetchurl {
      name = "FiraMono-BoldItalic.otf";
      url = "https://github.com/zwaldowski/Fira/raw/refs/heads/zwaldowski/mod-new/otf/FiraMono-BoldItalic.otf";
      sha256 = "0p44397wb0q4241cim5gxxm6mx7g88znqz5db0snx7zf98gcl1ac";
    })
    (fetchurl {
      name = "FiraMono-MediumItalic.otf";
      url = "https://github.com/zwaldowski/Fira/raw/refs/heads/zwaldowski/mod-new/otf/FiraMono-MediumItalic.otf";
      sha256 = "09j394hdan5vgk1c1nxqvjngbc4llzpc1vdbd4qh952iscdj85hp";
    })
    (fetchurl {
      name = "FiraMono-RegularItalic.otf";
      url = "https://github.com/zwaldowski/Fira/raw/refs/heads/zwaldowski/mod-new/otf/FiraMono-RegularItalic.otf";
      sha256 = "00y15ign0h49jm0k9mn6hyldjxjiqrlyp4a4xa50f8rlmshvdqs2";
    })
  ];

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/fonts/opentype
    for font in $srcs; do
      cp "$font" "$out/share/fonts/opentype/$(stripHash "$font")"
    done

    runHook postInstall
  '';
})
