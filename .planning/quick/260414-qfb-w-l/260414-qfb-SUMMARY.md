---
phase: quick-260414-qfb
plan: 01
status: completed
completed_at: "2026-04-14T00:00:00Z"
files:
  - py/wsha/cli.py
  - sh/wsha.sh
commits:
  - 07219fd
  - 91770e7
---

# Quick 260414-qfb Plan 01 Summary

## 概要

本次 quick task 将 `w -l` 的列表输出从“完整路径单标题 + 单列别名”重排为“来源/目录上下文 + 文件名强调 + 稳定双列对齐”，并让 Python 与 Shell 两个实现保持同一展示结构。

## 完成内容

### Task 1: Python 输出重排为目录标题 + 文件标题 + 真正双列对齐

- 在 `py/wsha/cli.py` 中保留原有配置加载与环境变量输出逻辑，仅调整 `print_list()` 的渲染层。
- 新增 `_split_display_path()`，将展示路径拆分为目录上下文与文件名。
- 对目录型配置优先保留目录上下文，并突出显示具体文件名，增强“按文件浏览配置”的可读性。
- 以当前文件组为单位动态计算 `alias` 与 `command` 两列宽度，去掉原先固定宽度布局。
- 保持命令模板原样输出，不做截断或重排。

### Task 2: Shell 输出同步为同结构文件标题和双列对齐

- 在 `sh/wsha.sh` 中调整 `show_list_table()`，保持按 `ALIAS_CONFIG_PATHS` 分组不变。
- 将标题拆成“目录上下文”和“文件名”两层输出。
- 按组动态计算别名列与命令列宽度，并使用 `printf` 保持对齐。
- 保留原有 ANSI 颜色语义与 `FORCE_COLOR` 行为。

### Task 3: 交叉验证两实现输出结构一致且仅为展示层变更

- 已通过 `python -m py_compile py/wsha/cli.py`。
- 已通过 `bash -n sh/wsha.sh`。
- 已分别执行 Python 与 Shell 的 `-l` 输出检查，确认两边都呈现目录上下文、文件名强调以及双列表格结构。
- 改动范围保持在展示层，没有触碰 alias 加载、匹配或执行逻辑。

## 验证结果

- Python 输出：通过，列表结构已重排。
- Shell 输出：通过，列表结构已重排。
- 双实现一致性：通过。

## Deviations from Plan

None. 本次执行按计划完成，仅调整列表展示层。

## Known Stubs

None.

## Threat Flags

None.

## Self-Check: PASSED

- [x] `py/wsha/cli.py` 已完成所需展示层修改
- [x] `sh/wsha.sh` 已完成所需展示层修改
- [x] Python 与 Shell 的 `-l` 输出结构一致
- [x] 未引入新依赖
- [x] 未修改配置加载或匹配执行逻辑
