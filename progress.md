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

## 会话：2026-07-17

### 阶段 4：测试与接口设计
- **状态：** in_progress
- 执行动作：
  - 通过 `grilling` 逐项确认 `-e/--env`、Shell 推断、变量引用、路径转换、PowerShell 原生入口和错误策略。
  - 只读核对 `wsha_core.py`、Bash/CMD wrapper、安装器、现有测试及文档入口。
  - 用户已批准更新旧 `-e == --entry` 测试，并开始实施。
  - 确认 block runner 元数据当前会在 `resolve_alias_tokens()` 返回前丢失，核心返回结构需要扩展。
  - 确认安装版 Windows launcher 与源码 `sh/wsha.bat` 走不同执行链，PowerShell 入口需覆盖两种布局。
  - 验证本机 PowerShell 的 `Get-Command wsha` 当前命中 `sh/wsha.bat`，单纯放置 `.ps1` 不足以改变已有 `.bat` 优先级。
  - 已迁移旧 `-e w` 解析测试为 `--entry w`，并新增 env 解析与跨 Shell/path 测试契约。

## 测试结果（2026-07-17）
| 测试 | 结果 | 状态 |
|------|------|------|
| `python -m pytest __test__/test_wsha_core_arg_parsing.py __test__/test_wsha_env.py -q` | Python 3.14 无 pytest：`No module named pytest` | ENV BLOCKED |
| `uv run --with pytest pytest ...` | 14 个预期红灯：旧 tuple API 与 env/path helper 均未实现 | RED PASS |

### 红灯证据
- `parse_cli_args()` 仍返回 tuple，5 个解析测试按新 `CliRequest` 契约失败。
- `render_env_command`、`resolve_env_assignments`、`expand_command_tokens`、`adapt_local_path`、`EnvResolutionError` 尚不存在，9 个 env/path 测试按预期失败。
- `pytest 9.1.1` 通过 `uv --with` 临时解析，不污染全局 Python。

### TDD 垂直切片结果
- Git Bash：先以真实 `sh/wsha.sh -e name=ccwq printenv name` 红灯，迁移 wrapper 内部 `-e` 到 `--entry` 后转绿。
- CMD：`sh/wsha.bat -e name=ccwq cmd /c set name` 通过。
- PowerShell：新增 `sh/wsha.ps1`；先后修复 `-e` 参数歧义与 WindowsApps Python shim 选择，真实命令和 `~` 路径均通过。
- 路径与引用：当前环境、前序 assignment、`~`、Git Bash/CMD/PowerShell 格式、URI 和 `feature/foo` 排除均由公开 CLI 测试覆盖。
- 安装：先写失败测试，再新增 `.ps1` launcher；最终验证安装后 PowerShell `-e` 真实执行通过。安装运行时缺 `py/wsha` 时由 core fallback 解决。
- 文档：定向测试通过后同步 `README.md`、`docs/W-WSHA.md`、`docs/INSTALL.md`。

### 最终验证
| 验证 | 结果 |
|------|------|
| `uv run --with pytest pytest __test__/test_wsha_env_cli.py __test__/test_wsha_core_arg_parsing.py __test__/test_windows_wrappers.py -q` | `17 passed` |
| `sh\core\exec-git-bash.bat .\__test__\wsha.test.sh` | `PASS=49 FAIL=0` |
| `sh\core\exec-git-bash.bat .\__test__\install.test.sh` | `PASS=5 FAIL=0` |
| `npm test` | exit `0`；`wsha-py.sh` 仍输出既有环境缺失 `ModuleNotFoundError: No module named 'click'`，未导致套件失败 |

- 已恢复本次全量测试改写的 `__test__/report/*.md` 生成报告，避免纳入功能改动。
- 计划修改范围：
  - `sh/core/wsha_core.py`
  - `sh/wsha.sh`、`sh/wsha.bat`、新增 PowerShell 入口
  - `scripts/install.sh`、必要的卸载/布局逻辑
  - 受影响测试与 `README.md`、`docs/W-WSHA.md`、`docs/INSTALL.md`
