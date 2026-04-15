# git-utils.sh

## What This Is

跨平台 Windows Git Bash 实用工具集合，提供别名展开、Git 辅助工具和 Windows Shell 增强功能。核心工具 wsha 通过模式匹配和模板展开实现智能命令行别名。

## Core Value

让命令行别名真正有用 — 通配符匹配、参数捕获、模板展开，而非静态字符串替换。

## Requirements

### Validated

- ✓ **wsha 通配符别名展开** — 支持 `*`, `**`, `?` 模式和令牌评分匹配
- ✓ **wsha 模板变量展开** — 支持 `$1`, `$2`, `$$` 等捕获组替换
- ✓ **wsha 配置缓存** — 多源配置合并，文件时间戳验证
- ✓ **wsha 别名优先级** — 多配置文件按优先级合并
- ✓ **wsh Git Bash 启动器** — Windows 多策略 Git Bash 发现
- ✓ **wsh-fpatch 补丁提取** — Git 提交补丁文件提取
- ✓ **wsh-real-ignore Git 取消跟踪** — 保留本地文件的 git rm
- ✓ **wsh-ping TCP 连接检查** — 预设主机和自定义目标检测

### Active

- **wsha 目录 glob 配置** — 支持 `wsh-alias/*.txt` 目录模式（忽略 `_` 开头）
- **wsha 多源配置合并** — 内置 < 用户级 < 工作目录优先级
- **wsha `&` 序列执行** — 跨文件 `&alias` 等价 `&&`
- **wsha `|` 或执行** — 跨文件 `|alias` 等价 `||`
- **wsha `!` 优先级覆盖** — 强制优先级提升
- **wsha doctor 重复检测** — 列出重复规则名称、文件、行号、内容
- **wsha `_` 描述语法** — **待定**（单独讨论）

### Out of Scope

- 重写 wsh/wsh-fpatch/wsh-real-ignore 等其他工具
- 添加 OAuth/第三方认证
- 跨平台 Python 版本（Python 重写仅针对 wsha 核心逻辑）

## Context

**背景:**
- Git Bash 是 Windows 用户的主要 Shell 环境
- 现有 wsha.sh (1064 行) 通过并行数组模拟 map 结构，配置加载/缓存逻辑调试困难
- macOS 兼容性存在隐患（GNU sed/awk vs BSD 差异）

**已建立的能力:**
- 33KB 测试套件 (`__test__/wsha.test.sh`) 验证 wsha 行为
- 多源配置合并策略（内置 + 用户级）
- 令牌评分匹配算法

**待解决:**
- 配置加载缓存的调试困难
- 代码冗余（并行数组架构）
- 跨平台可靠性和测试自动化缺失

## Constraints

- **兼容性**: Python 版本必须通过现有 `__test__/wsha.test.sh` 测试
- **共存策略**: wsha.sh 和 Python 版本并行存在，共享配置
- **执行路径**: 用户输入 `w <alias>` 时默认 Python，wsha.sh 作为 fallback
- **发布**: 支持 `uvx wsha` 运行和 pip 全局安装

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Python 重写 wsha 核心逻辑 | 解决调试困难和代码冗余 | — Pending |
| 并存策略而非替换 | 保持向后兼容，降低迁移风险 | — Pending |
| 默认 Python，fallback Bash | 渐进迁移，用户可控 | — Pending |
| 共享 wsh-alias.txt 配置 | 统一用户体验，避免配置分裂 | — Pending |

---

## Current Milestone: v1.1 配置解析重构

**Goal:** 重构配置文件解析规则，从单文件改为 glob 目录模式，支持序列/或执行、优先级覆盖和重复检测

**Target features:**
- 目录 glob 模式 `config/wsh-alias/*.txt`（1层，忽略 `_` 开头文件）
- 多源配置按优先级合并：内置 < 用户级 < 工作目录
- `&` 前缀序列执行（跨文件，等价 `&&`）
- `|` 前缀或执行（跨文件，等价 `||`）
- `!` 前缀优先级提升，支持强制覆盖
- `doctor` 命令检测并报告重复规则（名称 + 文件 + 行号 + 内容）
- `_` 描述语法（**待定** — 单独讨论）

**Pending decisions:**
- `_` 下划线描述语法：具体行为待用户进一步澄清

## Milestone History

### v1.0 wsha Python 重写

**Goal:** 用 Python 重写 wsha 核心逻辑，解决调试困难和代码冗余，同时保持完全兼容性

**Target features:**
- Python 实现的 wsha 核心逻辑（通配符匹配、令牌评分、模板展开）
- 支持 `uvx wsha` 和 pip 全局安装
- 与 wsha.sh 共存，共享配置
- 通过现有 `__test__/wsha.test.sh` 验证
- 支持所有现有模式：`w <alias>`, `w --list`, `w --find`, `w --cache-clear`

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---

*Last updated: 2026-04-13 after v1.0 milestone initialized*
