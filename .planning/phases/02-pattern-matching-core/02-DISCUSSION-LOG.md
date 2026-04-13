# Phase 2: Pattern Matching Core - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-13
**Phase:** 02-pattern-matching-core
**Mode:** discuss
**Areas discussed:** Tokenization Strategy, Regex Greedy vs Lazy, Single Wildcard Matching, Double Wildcard Matching

---

## Tokenization Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| `shlex.split()` | Python 标准库，处理引号和转义 | |
| 自定义 whitespace split | 纯按空白分割，简单 | ✓ |
| 保持和 shell 完全一致 | 参考 shell 实现，禁用 glob 后按空白分词 | |

**User's choice:** 自定义 whitespace split
**Notes:** Phase 1 D-04 避免 `shlex.split()` 用于配置解析，runtime tokenization 是独立问题

---

## Regex Greedy vs Lazy

| Option | Description | Selected |
|--------|-------------|----------|
| Python 默认 lazy | 接受 Python 默认行为 | |
| 显式使用 greedy `.*` | 验证与 bash `=~` 等价性 | ✓ |
| 其他方案 | 请说明 | |

**User's choice:** 显式使用 greedy `.*`
**Notes:** STATE.md 已知障碍，shell 转换 `(.*?)` → `(.*)`，需要显式处理

---

## Single Wildcard `*` Matching

| Option | Description | Selected |
|--------|-------------|----------|
| `fnmatch.fnmatch()` | 无法获取 capture | |
| `fnmatch.translate()` + `re.match()` | 最 Pythonic | ✓ |
| 完全手动实现 | 最可控，代码量大 | |

**User's choice:** `fnmatch.translate()` + `re.match()`
**Notes:** 需要手动处理 greedy 量词

---

## Double Wildcard `**` Matching

| Option | Description | Selected |
|--------|-------------|----------|
| 分两步匹配 | 先 regex 再字符串切片 | ✓ |
| 单次 regex 匹配 | 构建完整 regex | |
| 字符串操作 | 最简单，不够通用 | |

**User's choice:** 分两步匹配
**Notes:** 对应 shell 版本 `match_double_star_remainder()` 逻辑

---

## Claude's Discretion

- Bucket 索引数据结构的具体实现
- 评分算法的数据结构选择
- 具体函数命名和组织方式

---

## Deferred Ideas

None — all issues discussed and resolved within Phase 2 scope.
