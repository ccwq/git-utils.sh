---
phase: 03-template-expansion-execution
plan: "01"
type: execute
subsystem: wsha
tags: [template-expansion, command-execution, wsha]
dependency_graph:
  requires:
    - py/wsha/matcher.py (captures, rest_capture input)
    - os.environ (%VAR% expansion source)
  provides:
    - py/wsha/expand.py (expand_template, invoke_cmd, is_complex_shell_command, expand_env_vars)
  affects:
    - py/wsha/__init__.py (added Phase 3 exports)
tech_stack:
  added:
    - Python: expand.py module
  patterns:
    - Template variable substitution ($1, $2, $$)
    - Runtime environment variable expansion (%VAR%)
    - Complex shell command detection
    - Exit code standardization (0, 1, 127)
key_files:
  created:
    - py/wsha/expand.py: Template expansion and command execution
  modified:
    - py/wsha/__init__.py: Added Phase 3 exports
decisions:
  - "D-19: From-backward replacement avoids $10 being mistaken as $1+0"
  - "D-20: -- placeholder controls runtime_args insertion position"
  - "D-21: Environment variables expanded at runtime, not config load time"
  - "D-22: Complex shell commands use bash -c; simple commands use subprocess directly"
  - "D-23: Exit codes standardized: 0=success, 1=error, 127=command not found"
metrics:
  duration: ~
  completed_date: "2026-04-13T08:13:45Z"
---

# Phase 03 Plan 01: Template Expansion Engine

## One-liner

Template expansion engine with $1/$2/$$ substitution, %VAR% environment expansion, -- placeholder support, and proper exit codes.

## What Was Built

Created `py/wsha/expand.py` providing template expansion and command execution for wsha aliases. The module receives pattern matching captures from Phase 2's matcher and produces final executable commands.

### Key Functions

**is_complex_shell_command(text: str) -> bool**
Detects shell metacharacters (`&&`, `||`, `|`, `;`, `>`, `<`, `$()`, `` ` ``) requiring shell evaluation.

**expand_env_vars(text: str) -> str**
Expands `%VAR%` patterns from `os.environ` at runtime per D-21.

**expand_template(template: str, captures: list[str], rest_capture: str, runtime_args: list[str]) -> tuple[str, int]**
Replaces `$1`, `$2` from captures (backward scan per D-19), `$$` with rest_capture, handles `--` placeholder for runtime_args insertion.

**invoke_cmd(cmd_text: str) -> int**
Executes final command: expands env vars, checks complexity, runs via subprocess (simple) or bash -c (complex), returns exit code (0/1/127 per D-23).

## Verification Results

All automated tests passed:
- `is_complex_shell_command` detects all 8 shell patterns
- `expand_env_vars` replaces `%VAR%` from environment
- `expand_template` correctly substitutes `$1`, `$2` from captures
- `expand_template` replaces `$$` with rest_capture
- `--` placeholder inserts runtime_args at correct position

## Commits

| Hash | Message |
|------|---------|
| 2f8b382 | feat(03-01): create expand.py template expansion engine |
| c2f61c0 | feat(03-01): update __init__.py with Phase 3 exports |

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check

- [x] py/wsha/expand.py created with all required functions
- [x] All functions have docstrings matching shell implementation
- [x] Tests pass verifying all requirement behaviors
- [x] Functions properly exported from py.wsha package
