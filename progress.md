# 进度日志

## 会话：2026-07-06

### 阶段 0：设计确认
- **状态：** complete
- 执行动作：
  - 解释 `"$git-up -p"` 会被 shell 当 `${git}-up -p` 展开，导致 Codex 看到 `-up -p`。
  - 解释 `"git-up -p"` 报 `-p""=="__WSHA_NOOP__"` 是 Windows batch wrapper 对含内层引号的 `FINAL_CMD` 不安全。
  - 使用 grilling 流程确认设计方向：默认 argv、显式降级、core 内递归、`wsh` 作为执行适配器、`$@` 替代旧 `--` 插入点。

### 阶段 1：准备修复
- **状态：** in_progress
- 执行动作：
  - 启动 planning-with-files，并通过 GSD quick 初始化：`.planning/quick/260706-pab-wsha-argv-quote`。
  - 读取 `sh/core/wsha_core.py`、`sh/wsha.bat`、`sh/wsha.sh`、默认 alias 配置和相关测试。
  - 重写 PWF 文件以记录本次 quote/argv 任务。
- 创建/修改文件：
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## 测试结果
| 测试 | 输入 | 期望 | 实际 | 状态 |
|------|------|------|------|------|
| `python -m py_compile sh/core/wsha_core.py` | core 语法检查 | 0 exit | 0 exit | PASS |
| 手动加载 `__test__/test_expand_runtime_args.py` 三个 test 函数 | `$@` 插入点与 `--` 字面量 | 3 PASS | 3 PASS | PASS |
| `bash __test__/wsha.test.sh` | wsha shell 回归 | PASS=38, FAIL=0 | PASS=38, FAIL=0 | PASS |
| `powershell .\\sh\\wsha.bat coyo --model gpt-5.4 'git-up -p'` | 不再 batch quote 崩溃；prompt 保留 | 进入 codex，非 batch 语法错误 | `Error: stdin is not a terminal` | PASS |
| `powershell .\\sh\\wsha.bat coyo --model gpt-5.4 '$git-up -p'` | `$git-up -p` 保持字面量 | 进入 codex，非 `-u` 参数错误 | `Error: stdin is not a terminal` | PASS |

## 错误日志
| 时间 | 错误 | 尝试 | 处理 |
|------|------|------|------|
| 2026-07-07 | `-p""=="__WSHA_NOOP__" was unexpected at this time.` | 2 | 已将 `wsha.bat` 的 no-op sentinel 判断改为对 core stdout 文件做 `findstr` 精确匹配，避免在 IF 中展开含引号的 `FINAL_CMD`。 |
| 2026-07-07 | `w coyo --model gpt-5.4 "$git-up -p"` 进入 `wsh.bat` 后被 `bash -lc` 展开成 `-up -p` | 1 | 已让 Windows 下 `wsh` 归一化直接输出 `exec-git-bash.bat -lc "... '$git-up -p'"`，用 shell quoting 保留 `$` 字面量。 |
| 2026-07-07 | `bash __test__/wsha.test.sh` 出现 block runner 被整体 quote 成一个命令 | 1 | 已让 core 对单 token 且含空白的 block 命令直接原样输出，避免 `join_plain_tokens()` 二次 quoting。 |

## 5 问重启检查
| 问题 | 回答 |
|------|------|
| 我在哪里？ | Phase 1：准备修改 `wsha_core.py`、`wsha.bat`、默认配置和测试。 |
| 我要去哪里？ | 完成实现、补充回归测试、运行验证。 |
| 目标是什么？ | `w coyo --model gpt-5.4 "git-up -p"` 不再因 quote 崩溃，参数顺序正确。 |
| 我学到了什么？ | 当前单行字符串 + batch `if "%FINAL_CMD%"` 是 quote 崩溃根因；旧 `--` 插入点语义与 CLI terminator 冲突。 |
| 我做了什么？ | 确认设计并建立 PWF/GSD 工作上下文。 |
