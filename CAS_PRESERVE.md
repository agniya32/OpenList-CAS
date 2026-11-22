# CAS 合并上游时必须保留的改动

合并 `OpenListTeam/OpenList` 后请核对以下内容，冲突时优先保留本仓库（CAS）版本。

## 1. 管理员

- `internal/bootstrap/data/user.go`：首次启动自动创建 admin，`random.String(8)` 打印密码

## 2. .cas 框架

- `internal/casmeta/`
- `internal/driver/cas.go`
- `drivers/local/cas.go`
- `drivers/local/meta.go` 中的 GenerateCAS 等相关字段

## 3. 189 / 天翼

- `drivers/189pc/cas_*.go`
- `drivers/189pc/meta.go` 中 generate_cas / restore / delete_source 等配置
- `drivers/189pc/driver.go` 中与 CAS 挂钩的逻辑

## 4. OneDrive

- `drivers/onedrive`、`drivers/onedrive_app`：`SnippetProxy`、`GetFileById`、`Link()` 包装逻辑

## 5. CI

- `.github/workflows/beta_release.yml`：产物只上传 GitHub Releases
- `.github/workflows/sync_upstream.yml`：本同步工作流

## 本地一键同步

```bash
bash scripts/sync-upstream.sh
```

## Actions

仓库 → Actions → **Sync upstream OpenList** → Run workflow
