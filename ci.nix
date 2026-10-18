# This file provides all the buildable and cacheable packages and
# package outputs in your package set. These are what gets built by CI,
# so if you correctly mark packages as
#
# - broken (using `meta.broken`),
# - unfree (using `meta.license.free`), and
# - locally built (using `preferLocalBuild`)
#
# then your CI will be able to build and cache only those packages for
# which this is possible.

{
  pkgs ? import <nixpkgs> { },
  nurAttrs ? import ./default.nix { inherit pkgs; },
}:

with builtins;
let
  isReserved = n: n == "lib" || n == "overlays" || n == "nixosModules" || n == "homeModules" || n == "darwinModules" || n == "flakeModules";
  isDerivation = p: isAttrs p && p ? type && p.type == "derivation";
  isBuildable = p: let
    licenseFromMeta = p.meta.license or [];
    licenseList = if builtins.isList licenseFromMeta then licenseFromMeta else [licenseFromMeta];
  in !(p.meta.broken or false) && builtins.all (license: license.free or true) licenseList;
  isPlatformCompatible = p:
    let
      platforms = p.meta.platforms or null;
    in
      if platforms == null then true
      else builtins.elem pkgs.stdenv.hostPlatform.system platforms;
  isCacheable = p: !(p.preferLocalBuild or false);
  # 上游二进制包（dmg / zip / AppImage 之类）：本地「构建」只是下载 + 解包，产出动辄
  # 上 GB（calibre 1.1G、kicad 4.9G……），而下游完全可以从上游直接拿到同样的东西，
  # 缓存收益为零，所以默认不进 CI。
  isUpstreamBinary = p:
    elem pkgs.lib.sourceTypes.binaryNativeCode (p.meta.sourceProvenance or [ ]);
  shouldRecurseForDerivations = p: isAttrs p && p.recurseForDerivations or false;

  nameValuePair = n: v: { name = n; value = v; };

  concatMap = builtins.concatMap or (f: xs: concatLists (map f xs));

  flattenPkgs = s:
    let
      f = p:
        if shouldRecurseForDerivations p then flattenPkgs p
        else if isDerivation p then [ p ]
        else [ ];
    in
    concatMap f (attrValues s);

  outputsOf = p: map (o: p.${o}) p.outputs;

  nurPkgs =
    flattenPkgs
      (listToAttrs
        (map (n: nameValuePair n nurAttrs.${n})
          (filter (n: !isReserved n)
            (attrNames nurAttrs))));

in
rec {
  buildPkgs = filter (p: isBuildable p && isPlatformCompatible p && !isUpstreamBinary p) nurPkgs;
  cachePkgs = filter isCacheable buildPkgs;

  # 被排除的那批单独暴露，需要时仍然可以一把构建（ci.<system>.binary）
  binaryPkgs = filter (p: isBuildable p && isPlatformCompatible p && isUpstreamBinary p) nurPkgs;

  buildOutputs = concatMap outputsOf buildPkgs;
  cacheOutputs = concatMap outputsOf cachePkgs;
  binaryOutputs = concatMap outputsOf (filter isCacheable binaryPkgs);
}
