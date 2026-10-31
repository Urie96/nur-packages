# 本仓库自身的定时任务，由 home-server 上的 nixbot 执行（不是 NixOS 模块）。
#
# nixbot 在每次默认分支（main）构建成功后，从 flake 的 `herculesCI.onSchedule`
# 里发现定时任务并持久化，之后按 `when`（**UTC**）触发。每次运行都 checkout
# 默认分支的最新 commit，所以这里的改动要先合进 main 才生效；PR 里改它不会
# 给自己加任务。
#
# 两个任务：
#   package-update  每 5 小时跑一次 pkgs/updater，有上游更新的包各开一个 PR
#   daily-merge     每天晚上把 main 合回 daily，再开 daily → main 的 PR 并 arm auto-merge
#
# GitHub 侧前提：
#   · App 权限 Contents: Write（effect 要 push）、Checks: Write（上报 check run）
#   · 仓库设置里允许 Allow auto-merge
#   · main 的 branch protection 把 `nixbot/nix-eval`、`nixbot/nix-build` 设为 required checks。
#     不要加 `nixbot/effects`：本次构建没有任何 effect 条目时它根本不会被上报
#     （effect_checks.enqueue_checks 在 names 为空时直接 return），而没上报过的
#     required check 会让 PR 永远停在 "Waiting for status to be reported"。
{
  pkgs,
  effects,
  updater,
  primaryRepo,
}:
let
  inherit (effects) mkEffect;
  ownerRepo = "${primaryRepo.owner}/${primaryRepo.name}";
in
{
  # ── 任务 1：每 5 小时检查 pkgs/ 的上游版本 ─────────────────────────────
  # 对应原来 .gitea/workflows/update.yml 的工作：`updater` 自己负责发现可更新的
  # 包、跑 nix-update / update.py、在 worktree 里提交并把 update/<pkg> 分支推到
  # origin，再按远端 host 选择 `gh`（github.com）或 Gitea API 开 PR。
  # 分支已存在时它按「PR 还开着」跳过，所以重复触发是安全的。
  onSchedule.package-update = {
    # 5 小时一轮（00/05/10/15/20 点，UTC）；minute 不写，由 nixbot 按任务名
    # 算一个固定的伪随机分钟，避免和别的仓库整点撞车。
    when.hour = [
      0
      5
      10
      15
      20
    ];
    outputs.effects.update = mkEffect {
      name = "package-update";
      # 两次运行同时建 update/<pkg> 分支会互相打架（先是 worktree 冲突，
      # 再是 git push 非快进），用锁把它们串起来。
      lock = "package-update";
      # 可写克隆（/build/checkout，origin 里带 App token）：updater 的 push
      # 不需要额外 secret。
      checkout = true;
      inputs = [
        pkgs.git
        pkgs.gh
        pkgs.nix
        updater
      ];
      # { type = "GitToken"; } = 本次运行的 forge token，gh 用它建 PR。
      secretsMap.token = {
        type = "GitToken";
      };
      effectScript = ''
        set -euo pipefail
        export GH_TOKEN="$(readSecretString token .token)"
        # effect 沙箱里没有系统 nix.conf，flake 相关命令要显式打开（updater
        # 会调用 `nix eval .#packages.<system>` 判断包在哪个 system 可用）。
        export NIX_CONFIG="experimental-features = nix-command flakes"
        cd "$NIXBOT_EFFECT_CHECKOUT"

        # updater 在 git worktree 里提交，而 worktree 共享仓库配置：身份配在
        # checkout 上就够了。
        git config user.name nixbot
        git config user.email nixbot@localhost

        # 默认只更新当前 system（x86_64-linux）能构建的包。想让带 update.py
        # 的 darwin-only 包也从这里更新，加 --all-systems；nix-update 驱动的
        # darwin 包加不加都会被跳过（固定输出无法在 linux 上构建）。
        #
        # --auto-merge：每个 PR 都 arm GitHub 的 auto-merge，required checks
        # 绿了由 GitHub 自己合并。前提是仓库设置里允许 Allow auto-merge，并且
        # main 的 branch protection 配了 required checks（同上文）。
        ${pkgs.lib.getExe updater} --pr --auto-merge
      '';
    };
  };

  # ── 任务 2：每天晚上 daily → main ───────────────────────────────────────
  onSchedule.daily-merge = {
    when.hour = [ 20 ];
    outputs.effects.pr = mkEffect {
      name = "daily-to-main";
      inputs = [
        pkgs.gh
        pkgs.git
      ];
      # 合并 + push 需要可写的克隆：nixbot 把仓库 clone 到 /build/checkout
      # （也就是 cwd，并导出为 $NIXBOT_EFFECT_CHECKOUT），origin 指向带
      # GitHub App token 的 URL，所以 git push 不用额外 secret。
      # 注意它是 detached HEAD、没有本地分支、没有 committer 身份。
      checkout = true;
      # { type = "GitToken"; } = 本次运行的 forge token，在脚本里以
      # {"data":{"token":...}} 的形式出现，用 readSecretString 取。
      secretsMap.token = {
        type = "GitToken";
      };
      effectScript = ''
        set -euo pipefail
        export GH_TOKEN="$(readSecretString token .token)"
        cd "$NIXBOT_EFFECT_CHECKOUT"

        # effect 克隆没有 committer 身份，merge 提交需要自己配
        git config user.name nixbot
        git config user.email nixbot@localhost

        repo=${ownerRepo}
        base=main
        dev=daily
        git fetch --quiet --prune origin

        # nixbot 的中心镜像本身是 blobless partial clone
        # （clone --bare --filter=blob:none），每次 effect 的检出却是从这个
        # 镜像 **本地路径** clone 出来的，而 git 不会把
        # remote.origin.promisor / partialclonefilter 带到新克隆里：结果这个
        # 检出看着普通，对象库里却只有镜像 materialize 过的那部分 blob。
        # 于是在里面 checkout 一个没被检出过的提交（比如 origin/daily 相对
        # 本次运行的 main 改动过的 modules/checks.nix）时，git 只会打两条
        # 「unable to read sha1 file / invalid object」然后**返回 0**，把这
        # 些文件从索引和工作区里删掉；接着 git merge 内部要跑
        # `git stash create`，就会以「Cannot save the current index state」
        # 「fatal: stash failed」失败，看上去像是冲突，其实一个冲突文件都没有。
        # 这里把检出标记成 partial clone，git 缺 blob 时就会去 origin
        # （nixbot 已把它换成带 token 的 forge URL）按需补拉。
        git config remote.origin.promisor true
        git config remote.origin.partialclonefilter blob:none

        # ── 1) 先把 main 合回 daily ──────────────────────────────
        # 只落在 main 上的提交（每周 flake-update 的 flake.lock）如果不
        # 带回 daily，每晚的 daily → main 就会用 daily 的旧 lock 覆盖它
        # 或者直接冲突。
        # 用默认 merge（允许 fast-forward）：daily 只是落后于 main 时直接
        # 快进，不会为「没有内容变化」留一个合并提交。
        git checkout --quiet -B "$dev" "origin/$dev"
        # 上面这条在缺 blob 时只打错误、仍返回 0（见上），工作区因此不干净时
        # 直接停下，别把问题拖成后面那句「合并冲突」。
        if [ -n "$(git status --porcelain)" ]; then
          echo "❌ 检出 $dev 后工作区不干净，本地对象库可能不全：" >&2
          git --no-pager status --short >&2
          exit 1
        fi
        if ! git merge --no-edit \
          -m "chore: merge $base into $dev" "origin/$base"; then
          if [ -n "$(git --no-pager diff --name-only --diff-filter=U)" ]; then
            echo "❌ $base → $dev 合并冲突，需要手动解决：" >&2
            git --no-pager diff --name-only --diff-filter=U >&2
          else
            echo "❌ $base → $dev 合并失败，但没有冲突文件" >&2
            echo "   （本地对象库不全或工作区不干净，不是内容冲突）" >&2
            git --no-pager status --short >&2
          fi
          exit 1
        fi
        if [ "$(git rev-parse HEAD)" != "$(git rev-parse "origin/$dev")" ]; then
          git push --quiet origin "$dev"
          echo "已把 $base 合回 $dev"
        fi

        # ── 2) 和 main 内容一致就不建 PR ─────────────────────────
        # 不能数提交：主线上的合并提交本身就让 daily 比 main「多」一个
        # commit，但两边 tree 完全一样，这种 PR 在 GitHub 上是空 diff。
        if git diff --quiet "origin/$base" "$dev"; then
          echo "$dev 与 $base 内容一致，没有可合并的改动，跳过"
          # 之前跑出来的空 PR 顺手关掉，别让它挂着 auto-merge
          if [ "$(gh pr list --repo "$repo" --base "$base" --head "$dev" \
            --state open --json number --jq length)" -gt 0 ]; then
            echo "关闭没有 diff 的旧 PR"
            gh pr close "$dev" --repo "$repo" \
              --comment "$dev 与 $base 内容已一致，自动关闭。"
          fi
          exit 0
        fi

        # ── 3) 同一时间只留一个 PR ───────────────────────────────
        if [ "$(gh pr list --repo "$repo" --base "$base" --head "$dev" \
          --state open --json number --jq length)" -eq 0 ]; then
          gh pr create --repo "$repo" \
            --base "$base" --head "$dev" \
            --title "chore: $dev → $base ($(date -u +%F))" \
            --body "由 nixbot 定时任务创建，检查通过后自动合并。"
        fi

        # ── 4) 只 arm auto-merge，合并交给 GitHub 等 required checks ──
        # 放在 push 之后：head 变化时 GitHub 可能把 auto-merge 关掉。
        # 用 --merge：main 会以合并提交包含 daily 的那些提交，第二天第 1 步
        # 就退化成纯快进（Already up to date），既不会产生空 PR，也不会有
        # 「squash 后的调和合并」。但这要求仓库设置里 Allow merge commits。
        if [ "$(gh pr view --repo "$repo" "$dev" \
          --json autoMergeRequest --jq '.autoMergeRequest != null')" != "true" ]; then
          gh pr merge --repo "$repo" "$dev" --auto --merge
        fi
      '';
    };
  };
}
