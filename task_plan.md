# 任务计划：git-utils Windows wrapper 延迟经验固化

## 目标
固化 `w ll` 延迟排查、`exec-git-bash.bat` 缓存修复、以及 `w tping` 快路径保护的经验，避免后续 wrapper 改动重复踩坑。

## 当前阶段
阶段 4：已文档化并验证完成

## 阶段

### Phase 1：定位命令延迟
- [x] 对比 `w ll`、`wsh.bat ls -lah`、直接 Git Bash `ls -lah`、`exec-git-bash.bat` 的耗时。
- [x] 仅为诊断临时加入时间戳输出。
- **Status:** complete

### Phase 2：修复且不回退 `w tping`
- [x] 从热路径移除重复 `setx`，同时保留首次发现 Git Bash 后写缓存的行为。
- [x] 确认 `w tping -qq` 仍然展开到直接调用 Git Bash 的快路径。
- **Status:** complete

### Phase 3：验证行为
- [x] 验证 `w ll` 不再等待约 30 秒。
- [x] 验证临时时间戳调试标记已经删除。
- **Status:** complete

### Phase 4：持久化经验
- [x] 将发现、决策、测试、错误记录写入 PWF 文件。
- **Status:** complete

## 关键问题
1. 为什么 `w ll` 慢，而 `w tping` 快？
   - `w ll` 走 `wsh.bat -> exec-git-bash.bat`，而 `exec-git-bash.bat` 原来每次都会运行 `setx`。`w tping` 已经改成直接展开到 Git Bash。
2. `setx GIT_BASH` 是否应该存在？
   - 应该存在，但只在继承环境和 HKCU 缓存都没有可用 `GIT_BASH`、脚本必须自行发现 Git Bash 后执行一次。

## 已做决策
| 决策 | 理由 |
|------|------|
| `setx GIT_BASH` 只用于首次发现后的缓存写入 | 保留持久化缓存的原始意图，同时避免每次调用都付出约 30 秒成本。 |
| 不把 `w tping` 重新路由回 `exec-git-bash.bat` | 直接 Git Bash 快路径是 `w tping` 响应快的原因，应该保持隔离。 |
| 诊断完成后删除临时时间戳输出 | 时间戳对定位根因有用，但不应留在用户可见 wrapper 输出里。 |

## 遇到的错误
| 错误 | 尝试 | 处理 |
|------|------|------|
| `w ll` 输出前等待约 31-32 秒 | 1 | 加入临时时间戳，确认 `setx GIT_BASH` 消耗约 30 秒。 |
| 完全删除 `setx` 会丢失首次缓存写入语义 | 2 | 改为只有继承环境和 HKCU 缓存都未命中时才条件执行 `setx`。 |
| 长时间 `tping` 验证留下后台进程 | 1 | 查询并停止匹配 `tping.sh` / `qq.com:443` 的进程。 |

## 备注
- 后续排查 Windows wrapper 性能时，优先按 `w.bat -> wsha.bat -> wsh.bat -> exec-git-bash.bat -> bash.exe` 分段测时。
- 不要把慢速持久化环境变量写入放在每次命令调用的热路径上。
