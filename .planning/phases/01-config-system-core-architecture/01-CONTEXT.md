# Phase 1: Config System & Core Architecture - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Python 包结构和配置加载系统就绪，支持多源配置合并和缓存。
具体交付：
- `py/` 目录下 Python 包（wsha 核心模块 + CLI）
- `pyproject.toml` 构建配置
- wsh-alias.txt 解析器（支持引号别名、注释、空白）
- 多源配置合并（内置 < 用户 < 项目级）
- `~/.cache/wsha/` 缓存机制（mtime 验证）
- `w --cache-clear` 缓存清除
- 缓存损坏自动恢复
- 配置文件错误显示行号
- Python 失败 fallback 到 wsha.sh

</domain>

<decisions>
## Implementation Decisions

### Package Structure
- **D-01:** Python 包放在 `py/` 目录（`py/wsha/__init__.py` 等）
- **D-02:** 使用 Click CLI 入口点，`pip install` 后 `w` 命令路由到 Python
- **D-03:** 使用 `pyproject.toml` only（不使用 setup.py/setup.cfg）

### Config Parsing
- **D-04:** 手写 parser（按行读取），不使用 `shlex.split()`
- **D-05:** 支持双引号别名（如 `"pcodex l"` → alias_name 含空格，模板为 `echo codex-last`）
- **D-06:** 配置错误显示行号（格式：`config/wsh-alias.txt:12: 无效语法`）

### Cache Strategy (Python Only)
- **D-07:** Phase 1 只实现 Python 缓存，shell 版本暂无缓存（兼容性在 Phase 5 考虑）
- **D-08:** 缓存格式为 JSON
- **D-09:** 缓存位置：`~/.cache/wsha/`
- **D-10:** 缓存验证：基于文件 mtime（配置 mtime < 缓存 mtime = 有效）
- **D-11:** `w --cache-clear` 清除缓存
- **D-12:** 缓存损坏时自动清除 + 友好警告，程序继续运行

### Shell Integration
- **D-13:** Python 执行失败（ImportError、RuntimeError 等）自动 fallback 到 wsha.sh
- **D-14:** Python 版本与 shell 版本共享同一 `wsh-alias.txt` 配置文件

### Claude's Discretion
- CLI 输出格式（颜色、TABLE 布局）— 细节 planner 决定
- 缓存 JSON 具体字段结构 — planner 决定

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Configuration
- `config/wsh-alias.txt` — 现有别名配置格式（需支持解析的格式）
- `.planning/REQUIREMENTS.md` § Config System (CFG-01 ~ CFG-05) — Phase 1 需求清单

### Architecture
- `.planning/ROADMAP.md` § Phase 1 Success Criteria — 8 条成功标准必须全部满足
- `.planning/codebase/STRUCTURE.md` — `py/` 目录位置确认（目前为空）

### Shell Version Reference
- `sh/wsha.sh` — 现有 shell 实现（参考配置加载逻辑，但 Phase 1 Python 版本无缓存）
- `.planning/STATE.md` — "Cache format must be compatible with shell version" 是 Phase 5 关注点，Phase 1 暂不处理

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `config/wsh-alias.txt` — 配置格式已定义（无引号别名、带引号别名、注释行、空行、环境变量注入）
- `sh/wsha.sh` — 配置合并优先级（内置 < 用户 < 项目级），可参考逻辑

### Established Patterns
- Shell 版本无缓存实现（STATE.md 已记录）
- Click 是项目偏好（PROJECT.md 未提及但 CLI 项目常用）

### Integration Points
- `py/wsha/__init__.py` — Python 包入口
- `pyproject.toml` — 新建，定义 entry point
- `w.bat` / `w.sh` — 现有 Windows/Unix 入口，需修改路由到 Python
- `~/.cache/wsha/` — 新建缓存目录

</code_context>

<specifics>
## Specific Ideas

- 配置格式示例（来自 `config/wsh-alias.txt`）：
  ```
  # 注释行
  fox firefox
  "pcodex l" echo codex-last
  pp ping t.cn
  ```
- 现有 shell 版本配置加载在 `sh/wsha.sh` 第 1-1064 行，配置合并逻辑可参考

</specifics>

<deferred>
## Deferred Ideas

### Shell Version Cache (Phase 5)
- STATE.md 提到"Cache format must be compatible with shell version"，但 shell 版本当前无缓存实现。此兼容性工作放在 Phase 5 验证阶段处理。

### 其他
- None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-config-system-core-architecture*
*Context gathered: 2026-04-13*
