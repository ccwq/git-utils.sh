# Phase 4: CLI Interface & Shell Integration - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Python 实现的 Click CLI 入口、uvx/pip 安装、entry point 路由就绪。
具体交付：
- `w --list` / `w -l` 表格格式显示所有别名
- `w --list-view` / `w -lv` 详细视图显示别名元数据
- `w --find <pattern>` 按模式搜索别名
- `w --cache-clear` 缓存清除（Phase 1 已实现）
- `uvx wsha` 可运行 Python 实现
- `pip install wsha` 后 `w` 命令全局可用
- Python 执行失败自动 fallback 到 wsha.sh
- `w <alias> [args...]` 默认路由到 Python 实现

</domain>

<decisions>
## Implementation Decisions

### List Output Format
- **D-24:** 表格格式输出，使用 Click echo / format_table
  - 列：别名名称、模板（截断过长内容）、来源（builtin/user/project）
  - 最小化格式化（不使用颜色，除非终端支持）

### Fallback Trigger Conditions
- **D-25:** Python 执行失败触发 fallback — ImportError, FileNotFoundError, RuntimeError 等
- **D-26:** 退出码非零不触发 fallback — 可能是命令本身执行失败（如 `w nonexistent` 返回 127），不是 Python 错误
- **D-27:** fallback 执行 wsha.sh（通过 `w.bat` 或直接调用 shell 脚本）

### `--find` Search Pattern
- **D-28:** fnmatch glob 模式搜索（与 shell 版本的 glob 行为一致）
  - `*` 匹配任意字符
  - `?` 匹配单个字符
  - 不使用 regex，保持简单熟悉

### Detail View Content
- **D-29:** `--list-view` 显示完整别名信息
  - 列：别名名称、完整模板、来源配置文件、行号
  - 所有元数据可见，便于调试

### Shell Integration (from Phase 1)
- **D-30:** `w` 命令默认路由到 Python 实现
- **D-31:** Python 失败时 fallback 到 wsha.sh（D-25/26 定义触发条件）
- **D-32:** 与 shell 版本共享 `wsh-alias.txt` 配置（D-14）

### Entry Point
- **D-33:** `uvx wsha` 运行 Python 实现（SHELL-01）
- **D-34:** `pip install wsha` 安装后 `w` 命令可用（SHELL-02）
- **D-35:** `pyproject.toml` 定义 entry point（已有配置，确认生效）

### CLI Behavior
- **D-36:** `w --help` 或 `w` 无参数时显示帮助信息
- **D-37:** `w <alias> [args...]` 路由到 Python 实现执行

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### CLI Requirements
- `.planning/REQUIREMENTS.md` § CLI Interface (CLI-01 ~ CLI-04) — Phase 4 需求清单
- `.planning/REQUIREMENTS.md` § Shell Integration (SHELL-01 ~ SHELL-05) — Phase 4 需求清单

### Prior Phase
- `.planning/phases/01-config-system-core-architecture/01-CONTEXT.md` — Phase 1 决策（D-02, D-13, D-14, D-45）
- `.planning/phases/02-pattern-matching-core/02-CONTEXT.md` — Phase 2 决策（匹配算法参考）
- `.planning/phases/03-template-expansion-execution/03-CONTEXT.md` — Phase 3 决策（模板展开参考）

### Shell Version Reference
- `sh/wsha.sh` — shell 版本完整实现，CLI 和 fallback 逻辑参考
- `sh/w.bat` — Windows 入口点，调用 exec-git-bash.bat
- `sh/wsha.bat` — wsha 专用入口点

### Implementation
- `py/wsha/cli.py` — 当前 CLI 实现（Phase 3 完成部分）
- `py/wsha/matcher.py` — 别名匹配器
- `pyproject.toml` — entry point 定义（确认 `w = "wsha.cli:main"`）

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `py/wsha/cli.py` — 已有的 Click CLI 入口，需要增强 --list / --find 功能
- `py/wsha/matcher.py` — AliasMatcher 类，支持 find_best_match
- `pyproject.toml` — entry point 已定义

### Established Patterns
- Click 用于 CLI（Phase 1 确定）
- fnmatch 用于 glob 模式匹配（Phase 2 确定）
- fallback 策略：ImportError/RuntimeError 等 → wsha.sh

### Integration Points
- `w.bat` → `wsha.bat` → `wsha.sh` — 现有 Windows 入口链
- `py/wsha/cli.py:main()` — CLI 入口函数
- Phase 1 的 cache.py — `w --cache-clear` 实现基础

</code_context>

<specifics>
## Specific Ideas

- CLI 输出简洁优先（不追求花哨颜色）
- Fallback 是安全网，不影响正常流程
- `--find` 使用 fnmatch 与 shell 行为一致（D-28）

</specifics>

<deferred>
## Deferred Ideas

None — all issues discussed and resolved within Phase 4 scope.

</deferred>

---

*Phase: 04-cli-interface-shell-integration*
*Context gathered: 2026-04-13*