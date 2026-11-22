#!/usr/bin/env bash
# 本地将 OpenListTeam/OpenList 同步进 OpenList-CAS，并保留 CAS 改动
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! git remote get-url upstream >/dev/null 2>&1; then
  git remote add upstream https://github.com/OpenListTeam/OpenList.git
fi

git fetch upstream main
git checkout main
git pull origin main || true

set +e
git merge upstream/main --allow-unrelated-histories --no-edit \
  -m "chore: sync upstream OpenList $(date -u +%Y-%m-%d)"
rc=$?
set -e

if [ "$rc" -ne 0 ]; then
  echo "==> 解决冲突：保留 CAS 关键文件 (ours)"
  PRESERVE=(
    internal/bootstrap/data/user.go
    internal/casmeta
    internal/driver/cas.go
    drivers/local/cas.go
    drivers/local/meta.go
    drivers/189pc
    drivers/onedrive/driver.go
    drivers/onedrive/meta.go
    drivers/onedrive/util.go
    drivers/onedrive_app/driver.go
    drivers/onedrive_app/meta.go
    drivers/onedrive_app/util.go
    README.md
    README_CAS.md
    .github/workflows/beta_release.yml
    .github/workflows/build.yml
    .github/workflows/sync_upstream.yml
  )
  for p in "${PRESERVE[@]}"; do
    git checkout --ours -- "$p" 2>/dev/null || true
    git add -A -- "$p" 2>/dev/null || true
  done
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    git checkout --theirs -- "$f" 2>/dev/null || git checkout --ours -- "$f"
    git add -- "$f"
  done < <(git diff --name-only --diff-filter=U)
  git commit --no-edit -m "chore: sync upstream OpenList (preserve CAS) $(date -u +%Y-%m-%d)"
fi

echo "==> 校验 CAS 标记"
grep -q "random.String(8)" internal/bootstrap/data/user.go
grep -q "SnippetProxy" drivers/onedrive/meta.go
grep -q "GetFileById" drivers/onedrive/util.go
test -f internal/casmeta/casmeta.go
test -f drivers/local/cas.go

echo "==> 推送 GitHub"
git push origin main
echo "完成: $(git log -1 --oneline)"
