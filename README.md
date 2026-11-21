# OpenList-CAS

基于 [OpenList](https://github.com/OpenListTeam/OpenList) 的非官方增强版本，围绕 `.cas` 元数据文件提供生成、恢复、自动恢复与临时播放文件能力。

**当前状态**：基于 OpenList v4.2.10+（2026-11）最新代码，保留并移植了 OpenList-CAS 的核心 `.cas` 工作流增强。

## ✨ TL;DR

- 📦 上传普通文件后可自动生成 `.cas`
- 🗑️ 可在生成 `.cas` 后自动删除源文件
- ⚡ 可通过 `.cas` 快速恢复原文件
- 🗑️ 可在恢复原文件后自动删除 `.cas` 文件
- 🎬 支持通过 `.cas` 恢复临时播放文件并进行视频播放
- ♻️ 删除源文件、`.cas` 文件和临时播放文件时同步清理回收站

## 🔧 核心特性（OpenList-CAS 保留）

- 自动生成 `.cas` 元数据文件
- 支持生成 `.cas` 后自动删除源文件
- 支持从 `.cas` 恢复原文件
- 恢复命名默认按当前 `.cas` 文件名处理
- 支持恢复成功后自动删除 `.cas`
- 支持自动扫描监控目录并恢复已有 `.cas`
- 支持 `.cas` 作为视频播放入口
- 支持删除时同步清理回收站
- 支持家庭传输联动，减少个人空间上传流量限制影响

## ⚙️ 配置说明

### 189CloudPC

| 配置项 | 默认值 | 说明 |
| --- | --- | --- |
| `Generate cas` | `false` | 上传文件后生成 `.cas` 文件 |
| `Delete source` | `false` | 生成 `.cas` 文件成功后自动删除源文件，并同步清理回收站中的源文件 |
| `Restore source from cas` | `false` | 处理 `.cas` 文件时，自动根据其中记录的信息恢复源文件 |
| `Delete CAS after restore` | `false` | 恢复成功后自动删除 `.cas` 文件，并同步清理回收站中的 `.cas` 文件 |
| `Auto restore existing cas` | `false` | 开启后会自动扫描监控目录中的 `.cas` 文件并尝试恢复源文件 |
| `Auto restore existing cas paths` | 空 | 每行一个路径，只监控这些目录及其子目录；留空则不监控 |
| `CAS ext allowlist` | 空 | 扩展名白名单，空表示全部允许 |
| `CAS download restore` | `false` | 下载 .cas 时恢复真实文件 |

### Local

| 配置项 | 默认值 | 说明 |
| --- | --- | --- |
| `Generate cas` | `false` | 上传文件后生成 `.cas` 文件 |
| `Delete source` | `false` | 生成 `.cas` 后删除源文件 |

## 📦 支持驱动

| 驱动 | 生成 `.cas` | 删除源文件 | 从 `.cas` 恢复 | 自动恢复 | 删除 `.cas` 文件 | `.cas` 视频播放 |
| --- | --- | --- | --- | --- | --- | --- |
| `189CloudPC` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `Local` | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |

## 🔗 与上游项目

- 上游项目： [OpenList](https://github.com/OpenListTeam/OpenList) (当前同步至最新 main)
- 本项目为非官方增强分支，保留并移植了 GitYuA/OpenList-CAS 的 `.cas` 工作流增强

## 📜 免责声明

1. 本项目仅用于学习与技术研究。
2. 请遵守相关法律法规及服务条款。
3. 使用本项目产生的风险由使用者自行承担。
4. 本项目为非官方修改版本，不代表上游项目立场。

## 📜 致谢

- 感谢原项目 OpenList 提供的基础能力与持续维护。
- 感谢 GitYuA/OpenList-CAS 提供的 .cas 秒传元数据工作流增强。
