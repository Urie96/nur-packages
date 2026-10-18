{
  description = "My personal NUR repository";
  inputs.nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        # "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);

      pkgsFor = system: nixpkgs.legacyPackages.${system};

      ciFor =
        system:
        import ./ci.nix {
          pkgs = pkgsFor system;
          nurAttrs = self.legacyPackages.${system};
        };
    in
    {
      legacyPackages = forAllSystems (system: import ./default.nix { pkgs = pkgsFor system; });
      # 只暴露当前 system 可用的 derivation，否则 nix flake check 会因为
      # 求值 meta.platforms 不匹配的包（如 darwin-only 的 mac-ocr）而报错
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        nixpkgs.lib.filterAttrs (
          _: v: pkgs.lib.isDerivation v && pkgs.lib.meta.availableOn pkgs.stdenv.hostPlatform v
        ) self.legacyPackages.${system}
      );

      ci = forAllSystems (
        system:
        let
          ci = ciFor system;
        in
        ci
        // {
          all = (pkgsFor system).linkFarm "nur-ci-${system}" (
            nixpkgs.lib.imap0 (i: p: {
              name = "${toString i}-${p.name or "pkg"}";
              path = p;
            }) ci.cacheOutputs
          );
          # 上游二进制包（dmg/zip）：不进 ci.all，但需要时可以单独一把拉下来
          binary = (pkgsFor system).linkFarm "nur-ci-binaries-${system}" (
            nixpkgs.lib.imap0 (i: p: {
              name = "${toString i}-${p.name or "pkg"}";
              path = p;
            }) ci.binaryOutputs
          );
        }
      );

      checks = forAllSystems (
        system:
        let
          ci = ciFor system;
        in
        nixpkgs.lib.listToAttrs (
          nixpkgs.lib.imap0 (i: p: {
            name = "${p.name or "pkg"}-${toString i}";
            value = p;
          }) ci.buildPkgs
        )
      );
    };

}
