# Phase 3: Template Expansion & Execution - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning

<domain>
## Phase Boundary

模板展开和命令执行功能完整，退出码兼容 shell 版本。
具体交付：
- 模板变量替换（$1, $2, $$）
- -- 占位符控制运行时参数插入位置
- %VAR% 环境变量展开
- 带空格的别名正确处理
- 复杂 shell 命令透传
- 退出码与 shell 版本兼容

</domain>

<decisions>
## Implementation Decisions

### Template Variable Replacement
- **D-19:** 简单字符串替换策略 — 使用 `${var//pattern/replacement}` 从后向前 scan 替换 $1, $2, $$
  - 与 shell 版本 L1010-1016 一致
  - 从后向前替换避免 $10 被误认为 $1+0

### Runtime Argument Insertion
- **D-20:** 显式 `--` 占位符 — 模板包含 `--` 时，runtime args 插入到该位置；不包含则追加到末尾

### Environment Variable Expansion
- **D-21:** 运行时展开 — 每次执行时从当前环境读取 %VAR% 并替换，不在配置加载时展开

### Complex Shell Command Passthrough
- **D-22:** 手动解析管道/重定向 — Python 手动 parse 复杂命令，手动构造执行（更跨平台、更安全）
  - 不是 eval 等价物，而是完整的命令解析和执行

### Exit Code Compatibility
- **D-23:** 标准化错误码 — 映射常见错误到 0/1/127 等标准码
  - 0 = 成功
  - 1 = 一般错误
  - 127 = 命令未找到

### Claude's Discretion
- 具体的数据结构实现（captures 数组结构）
- %VAR% 展开的具体正则表达式
- 管道/重定向的 AST 解析方式
- 错误码映射的具体实现

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Shell Version Reference
- `sh/wsha.sh` §invoke_cmd (L904-912) — 命令执行和 exit code 逻辑
- `sh/wsha.sh` §is_complex_shell_command (L69-79) — 复杂命令检测
- `sh/wsha.sh` §template expansion (L1008-1058) — 模板替换完整逻辑

### Requirements
- `.planning/REQUIREMENTS.md` § Template Expansion (TPL-01 ~ TPL-05) — Phase 3 需求清单
- `.planning/REQUIREMENTS.md` § Pattern Matching (MATCH-08) — 复杂 shell 命令透传
- `.planning/REQUIREMENTS.md` § CLI Interface (CLI-05) — 退出码兼容性

### Prior Phase
- `.planning/phases/02-pattern-matching-core/02-CONTEXT.md` — Phase 2 决策（D-15, D-17, D-18）

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `sh/wsha.sh` — 完整的模板展开和执行逻辑参考实现
- Phase 1 的 Python 配置解析器（`py/wsha/parser.py`）
- Phase 2 的 Python 匹配引擎（待实现）

### Established Patterns
- Shell 版本使用并行数组模拟数据结构（Phase 2/3 需类似结构存储 captures）
- Token separator 使用 Unit Separator `\x1f`

### Integration Points
- `py/wsha/` — Python 包入口，Phase 3 在 Phase 2 matching 基础上添加 expand 模块
- Phase 3 执行结果传入 Phase 4 CLI interface

</code_context>

<specifics>
## Specific Ideas

- Shell 版本 L1012: `for ((ci = ${#_BEST_CAPTURES[@]}; ci >= 1; ci--)); do`
  - 从后向前遍历确保 $10 不会被误匹配
- `is_complex_shell_command` 检测 8 种模式：`&&`, `||`, `|`, `;`, `>`, `<`, `$()`, `` ` ``
- exit code 127 = 命令未找到（bash 标准）

</specifics>

<deferred>
## Deferred Ideas

None — all issues discussed and resolved within Phase 3 scope.

</deferred>

---

*Phase: 03-template-expansion-execution*
*Context gathered: 2026-04-13*