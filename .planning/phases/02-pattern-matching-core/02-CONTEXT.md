# Phase 2: Pattern Matching Core - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning

<domain>
## Phase Boundary

完整的别名匹配引擎，支持通配符和令牌评分。
具体交付：
- Runtime tokenization（按空白分割，禁用 glob 展开）
- 单通配符 `*` 匹配（捕获单个 token）
- 双通配符 `**` 匹配（捕获 remainder）
- 令牌评分算法（alias_count*10000 + literal_chars*100 - wildcard_weight）
- 最佳匹配查找（bucket 索引优化）
- 未知别名透传

</domain>

<decisions>
## Implementation Decisions

### Tokenization Strategy
- **D-15:** Runtime tokenization — 自定义 whitespace split，不使用 `shlex.split()`
  - 按空白分割输入，不展开 glob
  - 与 shell 版本 `get_tokens()` 行为一致（L625-640）

### Regex Behavior
- **D-16:** Regex behavior — 显式使用 greedy `.*`，验证与 bash `=~` 等价性
  - STATE.md 已知障碍：Python re 默认 lazy，shell 使用 greedy
  - 方案：显式使用 greedy 量词，测试验证等价性

### Single Wildcard `*` Matching
- **D-17:** 单通配符 `*` 匹配 — 使用 `fnmatch.translate()` + `re.match()`，手动处理 greedy capture
  - `fnmatch.translate()` 将 glob 转为 regex
  - 手动处理 greedy 行为（去掉 lazy `?`）
  - 提取 capture groups

### Double Wildcard `**` Matching
- **D-18:** `**` 双星号匹配 — 分两步匹配
  - Step 1: 用 regex 匹配 head + tail
  - Step 2: 用字符串切片获取 remainder
  - 与 shell 版本 `match_double_star_remainder()` 逻辑对应（L716-775）

### Claude's Discretion
- Bucket 索引数据结构的具体实现（可以用 dict + list，或纯 dict）
- 评分算法的数据结构选择
- 具体函数命名和组织方式

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Shell Version Reference
- `sh/wsha.sh` §get_tokens (L625-640) — Runtime tokenization 实现
- `sh/wsha.sh` §match_token_pattern (L648-708) — 单通配符匹配实现
- `sh/wsha.sh` §match_double_star_remainder (L716-775) — 双星号匹配实现
- `sh/wsha.sh` §find_best_match (L788-879) — 最佳匹配查找和评分算法
- `sh/wsha.sh` §build_alias_metadata (L216-267) — alias 元数据构建（评分相关）

### Requirements
- `.planning/REQUIREMENTS.md` § Pattern Matching (MATCH-01 ~ MATCH-07) — Phase 2 需求清单

### Architecture
- `.planning/ROADMAP.md` § Phase 2 Success Criteria — 7 条成功标准
- `.planning/codebase/ARCHITECTURE.md` § wsha 数据流 — 整体架构上下文

### Prior Phase
- `.planning/phases/01-config-system-core-architecture/01-CONTEXT.md` — Phase 1 决策（D-04: 配置解析用手写 parser）

### State
- `.planning/STATE.md` — 已知障碍：Regex greedy vs lazy，Tokenization 差异

</canonical_refs>

<codebase_context>
## Existing Code Insights

### Reusable Assets
- `sh/wsha.sh` — 完整的参考实现，所有 Phase 2 逻辑都有对应实现
- Phase 1 的 Python 配置解析器（`py/wsha/` 待实现）

### Established Patterns
- Shell 并行数组模拟 map 的数据结构（Phase 2 需要类似结构存储 alias 元数据）
- Bucket 索引优化（`ALIAS_BUCKETS_BY_FIRST`，L270-288）
- Token separator 使用 Unit Separator `\x1f`（L173）

### Integration Points
- `py/wsha/__init__.py` — Phase 1 入口，Phase 2 在此基础上添加 matching 模块
- `pyproject.toml` — 待定义 entry point

</codebase_context>

<specifics>
## Specific Ideas

- Scoring formula: `alias_count*10000 + literal_chars*100 - wildcard_weight`
  - 来自 shell 版本 L870: `score=$(( alias_count * 10000 + ALIAS_LITERAL_CHARS[$ai] * 100 - wildcard_count ))`
- Greedy regex: shell 转换 `(.*?)` → `(.*)`，Python 需要类似处理
- Bucket index: literal 首 token 按 key 分桶，wildcard 首 token 走公共桶

</specifics>

<deferred>
## Deferred Ideas

None — all issues discussed and resolved within Phase 2 scope.

</deferred>

---

*Phase: 02-pattern-matching-core*
*Context gathered: 2026-04-13*
