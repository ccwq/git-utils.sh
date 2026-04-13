# Phase 5: Test Compatibility & Validation - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning

<domain>
## Phase Boundary

所有现有测试通过，Python 版本与 shell 版本行为等价。
具体交付：
- 测试执行框架支持 Python 版本
- 行为等价验证通过对比测试
- 跨语言缓存格式兼容设计
- 测试覆盖确认（33KB 测试套件已够用）

</domain>

<decisions>
## Implementation Decisions

### 测试执行策略
- **D-24:** Wrapped 执行模式 — 创建 `__test__/wsha-py.sh` 包装脚本调用 Python 版本
  - 复用现有 `wsha.test.sh` 的所有断言和测试逻辑
  - 通过 `SCRIPT_TO_TEST` 环境变量切换实现/ shell
  - 不改原有测试文件，只加包装脚本

### 行为等价验证
- **D-25:** 顺序对比验证 — 先跑 shell 版本记录期望输出，再跑 Python 版本对比
  - 使用 `strip_time_logs()` 去除时间戳日志
  - 对比维度: stdout 内容、exit code、stderr（如果有）
  - 差异实时记录供修复

### 缓存兼容性
- **D-26:** 跨语言缓存格式设计 — Python 缓存格式需支持未来 shell 版本读写
  - Phase 1 实现 Python 缓存时预留扩展字段
  - JSON 格式带版本号 `{"version": 1, ...}`
  - shell 实现时直接读同格式即可

### 测试覆盖
- **D-27:** 接受现有测试套件 — 33KB 测试套件覆盖主要场景，Phase 5 聚焦等价性验证
  - 不做精确的需求→测试映射
  - 确保 Python 通过现有所有测试即可

### Claude's Discretion
- 具体 `wsha-py.sh` 包装脚本的实现细节
- 对比测试的具体通过标准（100% match 还是允许微小差异？）
- 缓存格式的具体字段设计

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 测试套件
- `__test__/wsha.test.sh` — 现有 33KB 测试套件，所有测试基于 shell 版本
- `__test__/test_utils.sh` — 测试工具函数（setup, cleanup, run_wsha 等）

### Shell 版本参考
- `sh/wsha.sh` — 完整参考实现，Python 版本需等价

### 早期阶段决策
- `.planning/phases/01-config-system-core-architecture/01-CONTEXT.md` — D-07: shell 版本暂无缓存
- `.planning/phases/03-template-expansion-execution/03-CONTEXT.md` — D-23: 退出码标准

### 需求文档
- `.planning/REQUIREMENTS.md` — 30 个需求，Phase 5 验证全部满足

</canonical_refs>

<codebase_context>
## Existing Code Insights

### Reusable Assets
- `__test__/wsha.test.sh` — 完整测试套件，断言复用
- `__test__/test_utils.sh` — 测试框架函数
- `sh/wsha.sh` — 行为参考标准

### Established Patterns
- 测试使用 `WSHA_CONFIG_FILE` 环境变量控制配置
- `SCRIPT_TO_TEST` 变量指向被测脚本
- 输出用 `strip_time_logs()` 去除时间戳和颜色

### Integration Points
- `py/wsha/cli.py` — Phase 4 创建的 CLI 入口，Phase 5 测试它
- `py/wsha/cache.py` — Phase 1 缓存实现，格式需兼容

</codebase_context>

<specifics>
## Specific Ideas

- 包装脚本 `wsha-py.sh` 大致逻辑:
  ```bash
  #!/bin/bash
  # 调用 Python 版本，模拟 wsha.sh 接口
  python -m wsha.cli "$@"
  ```
- 对比测试时记录差异到 `.planning/phases/05-test-compatibility-validation/diffs/`

</specifics>

<deferred>
## Deferred Ideas

None — all issues discussed and resolved within Phase 5 scope.

</deferred>

---

*Phase: 05-test-compatibility-validation*
*Context gathered: 2026-04-13*
