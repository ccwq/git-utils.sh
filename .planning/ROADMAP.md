# Roadmap: git-utils.sh - v1.1 配置解析重构

## Overview

重构 wsha 配置解析规则，从单文件改为 glob 目录模式，支持跨文件序列/或执行、优先级覆盖和 doctor 重复检测。

## Phases

- [ ] **Phase 1: Config Glob & Directory Loading** - glob 目录加载、忽略 `_` 开头文件、多源合并
- [ ] **Phase 2: Prefix Execution (&, |, !)** - 序列执行、或执行、优先级覆盖
- [ ] **Phase 3: Doctor Duplicate Detection** - 重复规则检测、报告格式化、退出码
- [ ] **Phase 4: Backward Compatibility** - 单文件兼容、缓存目录适配、现有测试通过
- [ ] **Phase 5: Integration & E2E Validation** - 端到端测试、现有测试套件验证

## Phase Details

### Phase 1: Config Glob & Directory Loading
**Goal**: 配置目录 glob 模式加载，支持忽略 `_` 开头文件和优先级合并
**Depends on**: Nothing (first phase)
**Requirements**: CFG-GLOB-01, CFG-GLOB-02, CFG-GLOB-03, CFG-GLOB-04
**Success Criteria** (what must be TRUE):
  1. `config/wsh-alias/*.txt` 正确加载（1层深度，忽略 `_` 开头）
  2. `$HOME/.config/wsh-alias/*.txt` 正确加载，优先级高于内置
  3. `$PWD/.config/wsh-alias/*.txt` 正确加载，优先级最高
  4. 同名规则默认只执行第一个
  5. `!` 前缀规则优先级提升，可强制覆盖
**Plans**: TBD

### Phase 2: Prefix Execution (&, |, !)
**Goal**: 实现跨文件序列执行、或执行和优先级覆盖逻辑
**Depends on**: Phase 1
**Requirements**: CFG-EXEC-01, CFG-EXEC-02, CFG-EXEC-03
**Success Criteria** (what must be TRUE):
  1. `&foo` 跨文件序列执行，所有同名 `&foo` 按优先级依次执行
  2. `|foo` 跨文件或执行，遇成功即停
  3. 序列执行遇错即停，符合 shell `&&` 语义
  4. 或执行遇成功即停，符合 shell `||` 语义
**Plans**: TBD

### Phase 3: Doctor Duplicate Detection
**Goal**: 重复规则检测和报告
**Depends on**: Phase 2
**Requirements**: CFG-DOCTOR-01, CFG-DOCTOR-02, CFG-DOCTOR-03
**Success Criteria** (what must be TRUE):
  1. `w --doctor` 可以检测所有配置源
  2. 报告包含规则名、文件路径、行号、内容
  3. 无重复时报告 "All clear"，有重复时返回非零退出码
**Plans**: TBD

### Phase 4: Backward Compatibility
**Goal**: 现有功能不受影响，缓存机制适配新结构
**Depends on**: Phase 3
**Requirements**: CFG-BACKWARD-01, CFG-BACKWARD-02, CFG-BACKWARD-03
**Success Criteria** (what must be TRUE):
  1. 现有 `wsh-alias.txt` 单文件仍可读取
  2. 缓存机制适配 glob 目录（目录内任一文件变化使缓存失效）
  3. 现有 `__test__/wsha.test.sh` 测试全部通过
**Plans**: TBD

### Phase 5: Integration & E2E Validation
**Goal**: 端到端验证和测试套件通过
**Depends on**: Phase 4
**Requirements**: All above
**Success Criteria** (what must be TRUE):
  1. 完整配置加载流程测试通过
  2. `&` 和 `|` 执行逻辑测试通过
  3. `doctor` 命令测试通过
  4. 向后兼容测试通过
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Config Glob & Directory Loading | 0/- | Not started | - |
| 2. Prefix Execution (&, \|, !) | 0/- | Not started | - |
| 3. Doctor Duplicate Detection | 0/- | Not started | - |
| 4. Backward Compatibility | 0/- | Not started | - |
| 5. Integration & E2E Validation | 0/- | Not started | - |

---

*Roadmap created: 2026-04-14*
*v1.1 milestone: 配置解析重构*
