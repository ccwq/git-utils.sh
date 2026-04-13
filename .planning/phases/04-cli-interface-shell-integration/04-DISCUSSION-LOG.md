# Phase 4: CLI Interface & Shell Integration - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-13
**Phase:** 04-cli-interface-shell-integration
**Mode:** default (discuss mode)
**Areas discussed:** none (used recommended defaults)

## Assumptions Presented

**User selected: Skip discussion, use recommended defaults**

The workflow analyzed Phase 4 gray areas but the user chose option 6 ("跳过，使用推荐默认值").

### Gray Areas Identified

1. **List Output Format** — `w --list` 如何展示别名
2. **Fallback Trigger Conditions** — 哪些错误类型触发 fallback
3. **`w --find` Search Pattern** — glob/fnmatch、regex 还是简单包含匹配
4. **Detail View Content** — `w --list-view` 显示哪些列

## Decisions Made (Default Values Applied)

| Decision | Recommended Value |
|----------|-------------------|
| List Output Format | 表格格式，Click echo/format_table，列：名称/模板/来源 |
| Fallback Trigger | ImportError/FileNotFoundError/RuntimeError → fallback，退出码非零不触发 |
| `--find` Search | fnmatch glob 模式（与 shell 行为一致） |
| Detail View | 别名名称、完整模板、来源配置、行号 |

## Auto-Resolved

All gray areas resolved with recommended defaults without interactive discussion.

## Notes

Phase 4 gray areas are relatively straightforward — CLI best practices are well-established and the project has clear prior decisions from Phase 1 (Click CLI) and Phase 2 (fnmatch glob).