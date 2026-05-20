{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  fira-code,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fira-code-italic";
  version = fira-code.version;

  src = fetchFromGitHub {
    owner = "Avi-D-coder";
    repo = "FiraCode-italic";
    rev = "f789933261ca1b6cf9b204131688f33a72b03961";
    hash = "sha256-6FP3so0YDgItiw42xoxydv1MJSIlDoIICWK8FlKOoLo=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/fonts/{opentype,truetype}

    # Keep the original nixpkgs Fira Code package intact, then add the two
    # italic OpenType faces from Avi-D-coder/FiraCode-italic.
    cp -r ${fira-code}/share/fonts/. $out/share/fonts/
    install -Dm644 FiraCode-RegularItalic.otf FiraCode-BoldItalic.otf \
      -t $out/share/fonts/opentype

    runHook postInstall
  '';

  meta = fira-code.meta // {
    description = "Fira Code with Regular Italic and Bold Italic fonts";
    homepage = "https://github.com/Avi-D-coder/FiraCode-italic";
    longDescription = ''
      Fira Code from nixpkgs, augmented with Regular Italic and Bold Italic
      OpenType fonts from Avi-D-coder/FiraCode-italic.
    '';
    license = lib.licenses.ofl;
  };
})
