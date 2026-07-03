# 进度日志

## 会话：2026-07-03

### 阶段 1：定位 `w ll` 延迟
- **状态：** complete
- **开始时间：** 2026-07-03 15:43:30 +08:00
- 执行动作：
  - 对比 `w ll`、`wsh.bat ls -lah`、直接 Git Bash `ls -lah`、`exec-git-bash.bat` 的耗时。
  - 经用户允许，在 `sh/exec-git-bash.bat` 临时加入时间戳诊断。
  - 确认 `setx GIT_BASH` 是约 30 秒延迟的瓶颈。
- 创建/修改文件：
  - `sh/exec-git-bash.bat`（临时诊断后改为最终条件缓存修复）

### 阶段 2：保留首次缓存行为与 `w tping` 快路径
- **状态：** complete
- 执行动作：
  - 移除 `exec-git-bash.bat` 中无条件执行的 `setx`。
  - 增加 `SHOULD_CACHE_GIT_BASH`，让 `setx` 只在继承环境和 HKCU 缓存都未命中后运行。
  - 验证 `w tping -qq` 仍然展开到直接 Git Bash，不依赖 `exec-git-bash.bat`。
- 创建/修改文件：
  - `sh/exec-git-bash.bat`

### 阶段 3：验证
- **状态：** complete
- 执行动作：
  - 验证 `exec-git-bash.bat --print-path` 很快。
  - 验证 `exec-git-bash.bat -lc "true"` 很快。
  - 验证 `w ll` 很快并能打印仓库目录列表。
  - 搜索临时调试标记（`debug_ts`、`DEBUG_EXEC_GIT_BASH`），确认没有残留。
- 创建/修改文件：
  - `task_plan.md`（创建）
  - `findings.md`（创建）
  - `progress.md`（创建）

## 测试结果
| 测试 | 输入 | 期望 | 实际 | 状态 |
|------|------|------|------|------|
| Git Bash 路径查询 | `Measure-Command { .\sh\exec-git-bash.bat --print-path > $null }` | 不再等待 30 秒 | `60.59ms` | PASS |
| 最小 Git Bash 命令 | `Measure-Command { .\sh\exec-git-bash.bat -lc "true" > $null }` | 亚秒级执行 | `358.06ms` | PASS |
| `w ll` 延迟 | `Measure-Command { w ll > $null }` | 不再等待 31-32 秒 | `523.31ms` | PASS |
| `w ll` 输出 | `w ll` | 快速出现仓库目录列表 | 已立即打印列表 | PASS |
| `w tping` 展开 | `python .\sh\wsha-core.py tping -qq`，并设置 `WSHA_ENTRY=w` | 直接 Git Bash 快路径 | `"C:\Program Files\Git\bin\bash.exe" ...tping.sh qq.com 443` | PASS |
| 调试清理 | `rg "setx|CACHED_GIT_BASH|DEBUG_EXEC_GIT_BASH|debug_ts" sh\exec-git-bash.bat` | 只保留预期的条件 `setx` | 仅剩 `SHOULD_CACHE_GIT_BASH` 与条件 `setx` | PASS |

## 错误日志
| 时间 | 错误 | 尝试 | 处理 |
|------|------|------|------|
| 2026-07-03 | `w ll` 输出前等待约 31-32 秒 | 1 | 加入临时时间戳，确认 `setx` 消耗约 30 秒。 |
| 2026-07-03 | 完全移除 `setx` 忽略了首次缓存写入语义 | 2 | 改为 `SHOULD_CACHE_GIT_BASH` 控制的条件 `setx`。 |
| 2026-07-03 | 长时间探测验证留下 `tping.sh` 后台进程 | 1 | 查询并停止匹配 `tping.sh` 和目标端口的 `cmd.exe` / `bash.exe` / `curl.exe`。 |

## 5 问重启检查
| 问题 | 回答 |
|------|------|
| 我在哪里？ | 文档化阶段已完成。 |
| 我要去哪里？ | 后续 wrapper 改动应先复用这些发现。 |
| 目标是什么？ | 保留 `w ll` 性能修复，并避免回退 `w tping`。 |
| 我学到了什么？ | `setx` 在当前环境很慢，不能放在热路径；直接 Git Bash 路径很快。 |
| 我做了什么？ | 修复 `exec-git-bash.bat`、验证耗时，并创建中文 PWF 文件。 |
