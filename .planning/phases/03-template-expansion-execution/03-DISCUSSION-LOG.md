# Phase 3: Template Expansion & Execution - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-13
**Phase:** 03-template-expansion-execution
**Areas discussed:** Template variable replacement, Runtime argument insertion, Environment variable expansion, Complex shell command passthrough, Exit code compatibility

---

## Template Variable Replacement

| Option | Description | Selected |
|--------|-------------|----------|
| 方案 A: 严格按 index 替换 | 正则精确匹配 $N 边界，避免 $10 被误匹配 | |
| 方案 B: 简单字符串替换 | 使用 ${var//pattern/replacement} 从后向前 scan，与 shell 版本一致 | ✓ |
| 方案 C: 正则替换 | 保证精确匹配 $N 边界 | |

**User's choice:** 方案 B - 简单字符串替换，从后向前 scan
**Notes:** 与 shell 版本 L1010-1016 一致

---

## Runtime Argument Insertion

| Option | Description | Selected |
|--------|-------------|----------|
| 方案 A: 显式 `--` | 模板包含 `--` 时在那个位置插入，否则追加到末尾 | ✓ |
| 方案 B: 隐式插到末尾 | 所有 runtime args 都追加到末尾 | |
| 方案 C: 最后一个 `--` 位置 | 如果有多个 `--`，插到最后一个位置 | |

**User's choice:** 方案 A - 显式 `--`
**Notes:** 与 shell 版本行为一致

---

## Environment Variable Expansion

| Option | Description | Selected |
|--------|-------------|----------|
| 方案 A: 解析时展开 | 读取配置时展开 %VAR% 为实际值，存入缓存 | |
| 方案 B: 运行时展开 | 每次执行时从当前环境读取并替换 | ✓ |
| 方案 C: 延迟展开 | 存原始值，执行时先替换 %VAR% 再执行 | |

**User's choice:** 方案 B - 运行时展开
**Notes:** 每次执行时从当前环境读取并替换

---

## Complex Shell Command Passthrough

| Option | Description | Selected |
|--------|-------------|----------|
| 方案 A: 完全透传 | 检测到复杂命令时，用 subprocess 直接透传到 shell | |
| 方案 B: 手动解析后执行 | Python 手动 parse 管道/重定向，手动构造执行 | ✓ |
| 方案 C: eval 等价物 | Python 的 exec() 或类似机制模拟 bash eval 行为 | |

**User's choice:** 方案 B - 手动解析管道/重定向
**Notes:** 更跨平台，更安全

---

## Exit Code Compatibility

| Option | Description | Selected |
|--------|-------------|----------|
| 方案 A: 透传 exit code | 直接返回 subprocess 的 exit code，不做处理 | |
| 方案 B: 标准化错误码 | 映射常见错误到 0/1/127 等标准码 | ✓ |
| 方案 C: Shell 兼容映射 | 尝试模拟 shell 的 exit code 语义 | |

**User's choice:** 方案 B - 标准化错误码
**Notes:** 0 = 成功, 1 = 一般错误, 127 = 命令未找到

---

## Claude's Discretion

以下方面由 Claude 在实现时决定：
- 具体的数据结构实现（captures 数组结构）
- %VAR% 展开的具体正则表达式
- 管道/重定向的 AST 解析方式
- 错误码映射的具体实现

## Deferred Ideas

None — all issues discussed and resolved within Phase 3 scope.