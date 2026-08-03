{
  lib,
  stdenv,
  fetchFromGitHub,
  zig,
  versionCheckHook,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "skhd-zig";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "jackielii";
    repo = "skhd.zig";
    rev = "v${finalAttrs.version}";
    hash = "sha256-Qi5srrpdhf3VcXaqZbijJD23Um0G7WgRzK0hR+mb7nU=";
  };

  nativeBuildInputs = [ zig ];

  # zig 0.16 自带 setup hook(zigConfigurePhase / zigBuildPhase / zigInstallPhase):
  #   - configure 阶段自动设置 ZIG_GLOBAL_CACHE_DIR=$(mktemp -d),沙箱内可写
  #   - 构建全程离线:build.zig.zon 里声明的 zbench 只在 `zig build bench` 时才会
  #     被惰性解析,默认 build/install 不触发网络 fetch(已在空缓存下实测)
  #
  # nixpkgs hook 默认是 --release=safe;这里按上游 README 推荐用 ReleaseFast,
  # 并保留 nixpkgs 的 -Dcpu=baseline 可复现性默认
  dontSetZigDefaultFlags = true;
  zigBuildFlags = [
    "-Dcpu=baseline"
    "-Doptimize=ReleaseFast"
  ];

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "Simple hotkey daemon for macOS (Zig implementation of skhd)";
    homepage = "https://github.com/jackielii/skhd.zig";
    license = lib.licenses.mit;
    mainProgram = "skhd";
    platforms = lib.platforms.darwin;
  };
})
