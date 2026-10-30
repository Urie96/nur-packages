# nur-packages

**My personal [NUR](https://github.com/nix-community/NUR) repository**

![Build and populate cache](https://git.lubui.com:8443/urie/nur-packages/actions/workflows/build.yml/badge.svg)

## CI

- `checks.<system>.<pkg>`：`ci.nix` 筛选出的可构建包（nixbot 只构建 `checks`）。
- `checks.<system>.all`：把一个 system 的全部可缓存输出链在一起的 aggregate，
  给 `nix build .#checks.<system>.all` / Gitea Actions 的缓存预热用。
- `effects.nix`：nixbot 定时任务 —— 每 5 小时用 `pkgs/updater` 检查上游更新，
  每个有更新的包开一个 PR 并 arm auto-merge（required checks 绿后自动合并）；
  每晚把 `daily` 合进 `main`。
