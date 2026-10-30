{
  description = "My personal NUR repository";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
    # CI/effects 由 home-server 上的 nixbot 执行，和 nixos-config 用同一个 input，
    # URL 保持一致（连同下面的 follows）才能和 nixos-config 共享 flake.lock 里的节点。
    nixbot.url = "git+https://github.com/Mic92/nixbot?shallow=1&ref=main";
    nixbot.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { self, nixpkgs, nixbot }:
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

      # nixbot 只构建 flake 的 `checks`，所以可构建的包集合只在这里暴露，
      # 不再额外提供 `ci.<system>.all`（那样同一批 derivation 会被求值两遍）。
      checks = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          ci = ciFor system;
        in
        nixpkgs.lib.listToAttrs (
          nixpkgs.lib.imap0 (i: p: {
            name = "${p.name or "pkg"}-${toString i}";
            value = p;
          }) ci.buildPkgs
        )
        // {
          # 一个把全部可缓存输出链在一起的 aggregate：本地 / Gitea Actions 想一次
          # 构建整批并拿到 `./result` 时用它（`nix build .#checks.<system>.all`）。
          all = pkgs.linkFarm "nur-checks-${system}" (
            nixpkgs.lib.imap0 (i: p: {
              name = "${toString i}-${p.name or "pkg"}";
              path = p;
            }) ci.cacheOutputs
          );
        }
      );

      # 定时任务：每 5 小时给有更新的包开 PR，每晚把 daily 合进 main。
      # nixbot 在每次默认分支（main）构建成功后从 `herculesCI.onSchedule` 发现并
      # 持久化这些任务，脚本细节见 ./effects.nix。
      herculesCI =
        { primaryRepo, ... }:
        let
          pkgs = pkgsFor "x86_64-linux";
        in
        import ./effects.nix {
          inherit primaryRepo pkgs;
          effects = nixbot.lib.effects { inherit pkgs; };
          updater = self.packages.x86_64-linux.updater;
        };
    };
}
