# 发现与决策

## 需求
- 修复 `w coyo --model gpt-5.4 "git-up -p"` 在 Windows wrapper 报 `-p""=="__WSHA_NOOP__" was unexpected at this time.` 的问题。
- 同时补充类似 `w coyo --model gpt-5.4 "$git-up -p"` / `git-up -p` 的回归测试，保证可用和参数正确。

## 调查发现
- `sh/config/wsh-alias/default.txt` 当前链路已迁移为：`coyo -> wsha codex-yo -> wsha codex-l --yolo $@ -> wsh npx -y @openai/codex@latest ...`。
- `sh/wsha.bat` 当前先调用 `wsha_core.py` 输出单行 `FINAL_CMD`，再执行最终命令。
- 当 `FINAL_CMD` 中包含双引号参数（例如 `"git-up -p"`）时，`if /i "%FINAL_CMD%"=="__WSHA_NOOP__"` 会破坏 CMD 引号结构。
- `sh/core/wsha_core.py` 已将 standalone `--` 释放给目标 CLI；`$@` 是运行时参数插入点。
- `sh/wsha.sh` 也通过 core 输出单行命令并 `eval` 执行；Unix 侧仍可依赖 shell quote，但语义应与 core 保持一致。
- `py/wsha/expand.py` 已同步 `$@` 插入点语义，并把 standalone `--` 当作目标 CLI 字面参数。

## 技术决策
| 决策 | 理由 |
|------|------|
| 默认 argv，复杂命令才降级字符串 | prompt、路径、自然语言指令中出现空格/引号/`-p` 是常态，不应由 shell/cmd 重解析。 |
| Python core 内递归展开 alias 链 | 减少 Windows batch/cmd 边界次数，降低 quote 风险。 |
| `$@` 表示用户剩余 argv 插入点 | 与 shell 习惯接近，同时释放 `--` 给目标 CLI。 |
| 立即破坏旧 `--` 插入点 | 用户确认接受 breaking change，避免长期双轨语义。 |
| Windows wrapper 仍需安全处理含引号 `FINAL_CMD` | 即使 core 内递归减少层数，最终命令仍可能包含带空格参数。 |

## 待验证假设
- 将 `codex-yo` 改为 `wsha codex-l --yolo $@` 后，`w coyo --model gpt-5.4 "git-up -p"` 展开为 `exec-git-bash.bat -lc "npx -y @openai/codex@latest --yolo --model gpt-5.4 'git-up -p'"`，不再触发 batch IF 引号错误。
- `w coyo --model gpt-5.4 "$git-up -p"` 展开为 `exec-git-bash.bat -lc "... '$git-up -p'"`，`$git-up` 通过单引号作为 prompt 字面量传给目标 CLI，不再被 Git Bash 展开成空字符串。

## 视觉/浏览器发现
- 不适用。本次 wrapper/CLI 设计修复没有使用浏览器或图片信息。

## 2026-07-17：`-e/--env` 新需求调查
- `sh/core/wsha_core.py::parse_cli_args()` 当前将 `-e/--entry` 作为内部入口参数；`sh/wsha.sh`、`sh/wsha.bat` 和测试 helper 都通过 `-e` 传递 `WSHA_ENTRY`。
- `-e/--entry` 没有作为用户能力写入帮助文档，适合迁移为仅保留 `--entry` 的内部参数。
- 当前 core 只有 `WSHA_CMDLINE_OUTPUT=sh|cmd` 两种输出协议；`sh/wsha.bat` 始终用 CMD 执行，尚无 PowerShell 原生入口。
- 安装器会复制完整 `sh/` 运行时，并另外生成 Unix launcher 与 `INSTALL_ROOT/bin/*.bat`；PowerShell 原生入口需要同步安装布局和可发现性验证。
- 当前 `%VAR%` 展开会直接读取 `os.environ`，且只对 `APP_HOME/APP_SH/APP_CONFIG` 做 Git Bash 路径转换；新实现需覆盖本次 `-e` 环境、更多引用语法、URL 排除和双向本地路径适配。
- 已确认决策：连续 `KEY=VALUE`；最终 runner 优先；实际值展开；PowerShell 原生入口；绝对路径和有证据的相对路径；支持 `~`；排除所有 URI；未定义变量报错。
- `pyproject.toml` 还暴露 `w`/`wsha` Python console scripts，但仓库安装脚本的主运行时是 `sh/core/wsha_core.py` + wrapper；本次公共参数需要避免两套入口明显漂移。
- block alias 的 runner 信息只在 `resolve_alias_tokens()` 内部可见，当前返回值仅为 token 列表；若要“最终 runner 优先”，需要让 alias 解析结果携带 runner/target shell 元数据，而不是只看 core 的 `WSHA_CMDLINE_OUTPUT`。
- 当前安装器生成的 Windows `.bat` launcher 反而转入 Git Bash `wsha.sh`，与仓库内 `sh/wsha.bat` 的 CMD 原生执行不同；PowerShell 原生入口必须同时处理源码直跑和安装产物。
- 现有 `__test__/test_wsha_core_arg_parsing.py` 只有两个解析用例，其中第一个明确使用 `-e w` 传内部 entry；按用户批准迁移为 `--entry w`，并新增 env request 结构断言。
- `resolve_alias_tokens()` 只有 `main()` 一个调用者，可以安全改为返回带 `target_shell`/block 信息的结构，而无需维护广泛兼容层。
- pip console script `py/wsha/cli.py` 是另一套直接执行实现；它不经过 shell wrapper。为了避免本轮范围失控，核心跨 Shell 渲染先落在仓库主运行时，Python console script至少需要识别并以临时 `env` 执行语义保持公共 `-e/--env` 可用，或明确委托 core。
- PowerShell 当前无原生命令发现链：在本机 `Get-Command wsha` 优先发现仓库 `sh/wsha.bat`，其次是已安装 `wsha.exe`；仅新增同目录 `.ps1` 不保证无扩展名 `wsha` 自动优先，因此原生入口需提供显式 `.ps1` 文件并由安装/文档声明，源码目录的无扩展名命令仍可能命中 `.bat`。

## 2026-07-17：TDD 实施结果
- 已确认 public seam：Git Bash `sh/wsha.sh`、CMD `sh/wsha.bat`、PowerShell `sh/wsha.ps1` 与安装后的 PowerShell launcher。
- `__test__/test_wsha_env_cli.py` 通过真实子命令覆盖：三入口临时注入、`--env`、空格值、未定义变量、当前/前序赋值引用、Git Bash/CMD/PowerShell 路径、`~` 与 URI/歧义文本排除。
- PowerShell 脚本必须显式声明 `-e/--env` switch；否则 PowerShell 会把 `-e` 误判为 `-ErrorAction` / `-ErrorVariable` 的歧义前缀。
- 安装后 PowerShell launcher 首次运行暴露 core 对 `py/wsha/list_table.py` 的开发依赖；已为只复制 `sh/` 的安装运行时提供 fallback，保留列表基本可用性。
- 安装版 `w.bat`/`wsha.bat` 改为直接委托运行时同名批处理入口，避免安装后 CMD 回落到 Git Bash 语法；`wsh` 分支继续使用 Git Bash launcher。
