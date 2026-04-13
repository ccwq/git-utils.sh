# Roadmap: git-utils.sh - v1.0 wsha Python Rewrite

## Overview

用 Python 重写 wsha 核心逻辑，解决调试困难和代码冗余，同时保持与 wsha.sh 的完全兼容性。实现"默认 Python，fallback shell"策略，通过现有 33KB 测试套件验证行为等价性。

## Phases

- [ ] **Phase 1: Config System & Core Architecture** - Python 包结构、配置解析、多源合并、缓存机制
- [ ] **Phase 2: Pattern Matching Core** - 别名匹配、通配符展开、令牌评分算法
- [ ] **Phase 3: Template Expansion & Execution** - 模板变量替换、命令执行、退出码兼容
- [ ] **Phase 4: CLI Interface & Shell Integration** - Click CLI、uvx/pip 安装、entry point 路由
- [ ] **Phase 5: Test Compatibility & Validation** - 通过现有测试套件验证行为等价性

## Phase Details

### Phase 1: Config System & Core Architecture
**Goal**: Python 包结构和配置加载系统就绪，支持多源配置合并和缓存
**Depends on**: Nothing (first phase)
**Requirements**: CFG-01, CFG-02, CFG-03, CFG-04, CFG-05, SHELL-03, SHELL-06, SHELL-07
**Success Criteria** (what must be TRUE):
  1. Python 可以解析 wsh-alias.txt 格式（无引号、带引号、注释行）
  2. 多源配置按优先级合并（内置 < 用户 < 项目级）
  3. 配置缓存保存在 ~/.cache/wsha/，基于文件时间戳验证
  4. `w --cache-clear` 可以清除缓存
  5. 缓存文件损坏时给出明确错误信息
  6. Python 版本与 shell 版本共享同一配置文件
  7. 单个配置文件中重复别名可以被检测
  8. 配置文件格式错误时给出描述性错误信息
**Plans**: TBD

### Phase 2: Pattern Matching Core
**Goal**: 完整的别名匹配引擎，支持通配符和令牌评分
**Depends on**: Phase 1
**Requirements**: MATCH-01, MATCH-02, MATCH-03, MATCH-04, MATCH-05, MATCH-06, MATCH-07
**Success Criteria** (what must be TRUE):
  1. `w ab` 可以展开为 `pnpx agent-browser`
  2. `w foo --ping` 参数可以透传 → `foobar open --ping`
  3. `px*` 匹配 `pxhttp-server`，`*` 捕获单个令牌
  4. `s**` 使用 `**` 捕获剩余所有内容作为 `$$`
  5. `f* *` 模式可以捕获多个令牌到 `$1` 和 `$2`
  6. 多个匹配时使用评分算法选择最佳匹配：alias_count*10000 + literal_chars*100 - wildcard_weight
  7. 未知别名直接透传：`w echo hello` → `echo hello`
**Plans**: TBD

### Phase 3: Template Expansion & Execution
**Goal**: 模板展开和命令执行功能完整，退出码兼容 shell 版本
**Depends on**: Phase 2
**Requirements**: MATCH-08, TPL-01, TPL-02, TPL-03, TPL-04, TPL-05, CLI-05
**Success Criteria** (what must be TRUE):
  1. 模板中 `$1`, `$2` 可以替换为捕获的令牌
  2. `$$` 可以替换为 `**` 捕获的剩余内容
  3. `--` 占位符控制运行时参数插入位置
  4. `%VAR%` 模板中可以展开环境变量
  5. 带空格的别名如 `"pcodex l"` 正确定义为 `echo codex-last`
  6. 复杂 shell 命令（管道、重定向、链式）正确透传
  7. 退出码与 shell 版本兼容：0=成功，127=命令未找到
**Plans**: TBD

### Phase 4: CLI Interface & Shell Integration
**Goal**: Python 实现可通过 uvx 和 pip 安装，entry point 路由正常
**Depends on**: Phase 3
**Requirements**: CLI-01, CLI-02, CLI-03, CLI-04, SHELL-01, SHELL-02, SHELL-04, SHELL-05
**Success Criteria** (what must be TRUE):
  1. `w --list` 或 `w -l` 以表格格式显示所有别名
  2. `w --list-view` 或 `w -lv` 显示详细视图
  3. `w --find <pattern>` 可以按模式搜索别名
  4. `uvx wsha` 可以运行 Python 实现
  5. `pip install wsha` 后 `w` 命令全局可用
  6. Python 执行失败时 fallback 到 wsha.sh
  7. `w <alias> [args...]` 默认路由到 Python 实现
**Plans**: 2 plans
Plans:
- [ ] 04-01-PLAN.md — CLI 选项实现（--list / --list-view / --find / --cache-clear）
- [ ] 04-02-PLAN.md — Fallback 逻辑与 pyproject.toml 包路径修正
**UI hint**: yes

### Phase 5: Test Compatibility & Validation
**Goal**: 所有现有测试通过，行为与 shell 版本等价
**Depends on**: Phase 4
**Requirements**: (验证所有 phase 1-4 实现)
**Success Criteria** (what must be TRUE):
  1. 运行 `__test__/wsha.test.sh` 所有测试通过
  2. Python 版本与 shell 版本行为等价（无差异）
  3. 缓存写入/读取往返保持一致
  4. 跨 Python 和 shell 版本切换不破坏缓存
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Config System & Core Architecture | 0/- | Not started | - |
| 2. Pattern Matching Core | 0/- | Not started | - |
| 3. Template Expansion & Execution | 1/2 | In Progress|  |
| 4. CLI Interface & Shell Integration | 0/2 | Not started | - |
| 5. Test Compatibility & Validation | 0/- | Not started | - |

---

*Roadmap created: 2026-04-13*
*v1.0 milestone: wsha Python rewrite*
