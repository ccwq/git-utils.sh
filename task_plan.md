# 任务计划：实现 wsha -e/--env 跨 Shell 环境注入

## 目标
为 `wsha` 增加内置 `-e/--env` 参数，连续读取 `KEY=VALUE` 后执行剩余命令；根据最终执行 Shell 生成 Bash/Git Bash、CMD 或 PowerShell 环境注入语法，并统一处理当前环境变量引用、本地路径、`~`、URL 排除及未定义变量错误。

## 当前阶段
阶段 4：测试与接口设计

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

### Phase 4：测试与接口设计
- [x] 将旧 `-e == --entry` 测试迁移为 `--entry`，新增 `-e/--env` 解析用例。
- [x] 新增跨 Shell 环境注入、变量展开、路径转换、URL 排除、`~` 和错误处理测试。
- [x] 明确 PowerShell 原生入口与安装后命令发现方式。
- **Status:** complete

### Phase 5：核心实现
- [x] 在 `sh/core/wsha_core.py` 中实现 env 解析、目标 Shell 推断、引用展开与路径适配。
- [x] 保留内部 `--entry`，移除其 `-e` 短参数。
- [x] 保证 alias 展开后再按最终 runner 选择环境注入格式。
- **Status:** complete

### Phase 6：包装器与安装入口
- [x] 将现有 Bash/CMD 包装器内部调用迁移到 `--entry`。
- [x] 新增 PowerShell 原生入口并同步安装器、卸载器与运行时布局。
- **Status:** complete

### Phase 7：定向验证与文档
- [x] 通过 Python、Shell、CMD、PowerShell 定向测试和真实命令验证。
- [x] 测试通过后更新 `README.md`、`docs/W-WSHA.md`、`docs/INSTALL.md`。
- **Status:** complete

### Phase 8：全量验证
- [x] 运行 `npm test`，区分本次回归与既有环境噪声。
- [x] 检查 `git diff --check`、工作树范围与 PWF 完整性。
- **Status:** complete

## 已做决策
| 决策 | 理由 |
|------|------|
| 默认 argv，复杂命令才降级字符串 | 避免 prompt/路径中的空格、引号、`-p` 被 shell/cmd 误解析。 |
| alias 链在 Python core 内递归展开 | 避免 `coyo -> codex-yo -> codex-l` 每层都经过 `wsha.bat/cmd` quote。 |
| `wsh` 是最终执行适配器 | `wsh` 不再作为 alias 递归中间层参与语义展开。 |
| `$@` 是用户 argv 插入点 | 让 `--` 回归目标 CLI 的真实 option terminator，避免语义混淆。 |
| 旧 `--` 插入语义立即破坏 | 用户明确接受 breaking change，换取长期语义清晰。 |
| `-e` 覆盖旧 `--entry` 短参数 | 用户明确选择；内部调用迁移为长参数 `--entry`。 |
| 连续 `KEY=VALUE` 后首个非赋值 token 为命令 | 与示例一致，避免额外结束标记。 |
| 以最终执行 Shell 决定输出格式 | 显式 runner 比调用端 Shell 更接近真实执行语义。 |
| 环境引用先解析实际值再转换本地路径 | 统一兼容 `%VAR%`、`$VAR`、`${VAR}`、PowerShell env 写法。 |
| URL/URI 永不做路径转换 | 避免破坏 `socks5://`、HTTP URL 等值。 |
| 未定义变量立即报错 | 防止静默变成错误路径或危险命令。 |

## 遇到的错误
| 错误 | 尝试 | 处理 |
|------|------|------|
| `-p""=="__WSHA_NOOP__" was unexpected at this time.` | 1 | 初步定位为 `wsha.bat` 在 `if /i "%FINAL_CMD%"==...` 中直接展开含双引号的 `%FINAL_CMD%`，导致 CMD parser 崩溃。 |
| `cmd /c`/`wsh.bat` 嵌套 `bash -lc` 时 `$git-up` 被当 shell 变量展开 | 2 | Windows `wsh` 适配改为 core 直接生成 `exec-git-bash.bat -lc "..."`，并用 shell quoting 把 `$git-up -p` 包在单引号中。 |
| block alias 在 Git Bash 下把整条 block 命令二次 quote 成单参数 | 2 | core 对单 token 且含空白的 block 命令直接原样输出，避免再经 `join_plain_tokens()` 二次引用。 |
| 默认 Python 3.14 缺少 pytest：`No module named pytest` | 1 | 不安装全局依赖；先尝试 `uv --offline` 使用本机缓存，失败则用现有项目测试入口或轻量直接调用验证。 |

## 备注
- 新增/修改测试用例前保持中文 GWT 注释。
- 需要同步 `sh/core/wsha_core.py` 与旧 Python 包 `py/wsha/expand.py` 中的 `$@` 插入语义，避免测试和文档漂移。
