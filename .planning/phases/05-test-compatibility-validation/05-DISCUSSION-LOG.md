# Phase 5: Test Compatibility & Validation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-13
**Phase:** 05-test-compatibility-validation
**Areas discussed:** 测试执行策略, 行为等价验证, 缓存兼容性, 测试覆盖映射

---

## 测试执行策略

| Option | Description | Selected |
|--------|-------------|----------|
| A: Wrapped 执行 | 创建 `__test__/wsha-py.sh` 包装脚本，复用现有断言 | ✓ |
| B: 重写为 pytest | 用 Python 重写所有测试用例 | |
| C: 对比测试模式 | 新建 `__test__/compare.sh` 同时运行两版本对比 | |

**User's choice:** A
**Notes:** 复用现有测试逻辑，不改原有文件，通过环境变量切换实现

---

## 行为等价验证

| Option | Description | Selected |
|--------|-------------|----------|
| A: 顺序对比 | 先跑 shell 记录期望，再跑 Python 对比 | ✓ |
| B: 并行对比 | 同时跑两版本实时对比 | |
| C: 基于属性测试 | 验证代数性质而非具体输出 | |

**User's choice:** A
**Notes:** 顺序验证更清晰，先记录期望再验证实现

---

## 缓存兼容性

| Option | Description | Selected |
|--------|-------------|----------|
| A: 忽略兼容性 | 先确保 Python 缓存自身正确 | |
| B: 跨语言格式设计 | 设计兼容格式，即使 shell 还没实现 | ✓ |
| C: 其他理解 | 用户提供其他解释 | |

**User's choice:** B
**Notes:** JSON 格式带版本号，预留扩展字段

---

## 测试覆盖映射

| Option | Description | Selected |
|--------|-------------|----------|
| A: 手动映射 | 逐个需求匹配到测试用例 | |
| B: 自动扫描 | 脚本扫描生成覆盖矩阵 | |
| C: 接受现状 | 33KB 测试套件已够用 | ✓ |

**User's choice:** C
**Notes:** Phase 5 聚焦等价性验证，不做精确映射

---

## Claude's Discretion

[以下领域用户让 Claude 自行决定:]
- 具体 `wsha-py.sh` 包装脚本的实现细节
- 对比测试的具体通过标准
- 缓存格式的具体字段设计

## Deferred Ideas

None — all issues discussed and resolved within Phase 5 scope.
