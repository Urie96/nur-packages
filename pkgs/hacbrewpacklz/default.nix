{
  lib,
  buildDotnetModule,
  dotnetCorePackages,
  fetchFromGitLab,
  clang,
}:
buildDotnetModule rec {
  pname = "hacbrewpacklz";
  version = "1.5.5";

  src = fetchFromGitLab {
    owner = "ismaellozanoperezserrano";
    repo = "hacbrewpacklz";
    tag = "v${version}";
    hash = "sha256-j2tZ27hAQMEnWAaRogS8Wz0e6v6byduRNyWrjDOglP8=";
  };

  projectFile = "hacbrewpacklz.csproj";
  # 项目没有 PackageReference，不需要 NuGet 锁文件。
  nugetDeps = [ ];

  dotnet-sdk = dotnetCorePackages.sdk_10_0;

  # 上游的 global.json 钉死 SDK 10.0.403（rollForward=latestPatch），换到别的
  # nixpkgs 就会因为找不到这个具体版本直接失败。改成实际打包的 SDK 版本。
  postPatch = ''
    cat > global.json <<'EOF'
    {
      "sdk": {
        "version": "${dotnetCorePackages.sdk_10_0.version}",
        "rollForward": "latestPatch"
      }
    }
    EOF
  '';

  # 上游本来就是 NativeAOT：publish 时 ILC 把 IL 直接编译成机器码，产物约
  # 9 MB，不需要 dotnet-runtime（闭包 180 MiB -> 50 MiB 上下）。
  # selfContainedBuild 必须打开，否则 hook 会追加 -p:PublishTrimmed=false，
  # 而原生编译不允许关掉裁剪。
  selfContainedBuild = true;
  nativeBuildInputs = [ clang ];

  # buildDotnetModule 默认的可执行文件 wrapper 会把 ICU 加进 LD_LIBRARY_PATH
  # （多 40 MiB 闭包），原生二进制只依赖 glibc，直接软链过去。
  dontDotnetFixup = true;
  postInstall = ''
    mkdir -p $out/bin
    ln -s ../lib/hacbrewpacklz/hacbrewpacklz $out/bin/hacbrewpacklz
  '';

  meta = {
    description = "Compress, merge and extract Switch NSP/NSZ/XCI/XCZ game files";
    homepage = "https://gitlab.com/ismaellozanoperezserrano/hacbrewpacklz";
    license = lib.licenses.gpl2Only;
    mainProgram = "hacbrewpacklz";
    # prod.keys 不包含在包里，需要自己从 Switch 上导出。
    platforms = [ "x86-64_linux" ];
  };
}
