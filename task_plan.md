# 任务计划：修复 wsha argv quote 设计

## 目标
修复 `w coyo --model gpt-5.4 "git-up -p"` 等带空格 prompt 在 Windows wrapper 中崩溃的问题，并落实已确认的新设计：默认 argv、alias 链在 Python core 内递归展开、`$@` 作为用户 argv 插入点、`--` 回归目标 CLI terminator。

## 当前阶段
阶段 3：验证

## 阶段

### Phase 1：实现核心语义修复
- [x] 将模板运行时参数插入点从 `--` 改为 `$@`。
- [x] 在 Python core 内递归展开 `wsha`/`w` alias 链，避免每层回到 `wsha.bat`。
- [x] 修复 Windows batch wrapper 对含内层引号命令的安全比较/执行。
- **Status:** complete

### Phase 2：迁移配置与测试
- [x] 将默认配置中的旧 `--` 插入点迁移为 `$@`。
- [x] 更新旧测试对 `--` placeholder 的预期。
- [x] 新增 `w coyo --model gpt-5.4 "git-up -p"` 类回归测试，覆盖可用性与参数顺序。
- **Status:** complete

### Phase 3：验证
- [x] 运行 Python 单测。
- [x] 运行 wsha shell 测试。
- [x] 如可行，运行 Windows wrapper 相关测试或直接命令验证。
- **Status:** complete

## 已做决策
| 决策 | 理由 |
|------|------|
| 默认 argv，复杂命令才降级字符串 | 避免 prompt/路径中的空格、引号、`-p` 被 shell/cmd 误解析。 |
| alias 链在 Python core 内递归展开 | 避免 `coyo -> codex-yo -> codex-l` 每层都经过 `wsha.bat/cmd` quote。 |
| `wsh` 是最终执行适配器 | `wsh` 不再作为 alias 递归中间层参与语义展开。 |
| `$@` 是用户 argv 插入点 | 让 `--` 回归目标 CLI 的真实 option terminator，避免语义混淆。 |
| 旧 `--` 插入语义立即破坏 | 用户明确接受 breaking change，换取长期语义清晰。 |

## 遇到的错误
| 错误 | 尝试 | 处理 |
|------|------|------|
| `-p""=="__WSHA_NOOP__" was unexpected at this time.` | 1 | 初步定位为 `wsha.bat` 在 `if /i "%FINAL_CMD%"==...` 中直接展开含双引号的 `%FINAL_CMD%`，导致 CMD parser 崩溃。 |
| `cmd /c`/`wsh.bat` 嵌套 `bash -lc` 时 `$git-up` 被当 shell 变量展开 | 2 | Windows `wsh` 适配改为 core 直接生成 `exec-git-bash.bat -lc "..."`，并用 shell quoting 把 `$git-up -p` 包在单引号中。 |
| block alias 在 Git Bash 下把整条 block 命令二次 quote 成单参数 | 2 | core 对单 token 且含空白的 block 命令直接原样输出，避免再经 `join_plain_tokens()` 二次引用。 |

## 备注
- 新增/修改测试用例前保持中文 GWT 注释。
- 需要同步 `sh/core/wsha_core.py` 与旧 Python 包 `py/wsha/expand.py` 中的 `$@` 插入语义，避免测试和文档漂移。
