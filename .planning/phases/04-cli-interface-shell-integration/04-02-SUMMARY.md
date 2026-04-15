---
gsd_state_version: 1.0
phase: 04-cli-interface-shell-integration
plan: "04-02"
subsystem: cli
tags: [fallback, entry-point, pyproject, hatchling]

# Dependency graph
requires:
  - 04-01-PLAN.md
provides:
  - fallback_to_shell() + run_with_fallback() for entry point
  - Fixed pyproject.toml packages path for pip/uvx distribution
affects:
  - Phase 05 (test compatibility validation)

# Tech tracking
tech-stack:
  added: [subprocess.run, sys, os.path]
  patterns: [Python fallback pattern, entry point routing]

key-files:
  created: []
  modified:
    - py/wsha/cli.py
    - pyproject.toml

key-decisions:
  - "D-25: Only ImportError/FileNotFoundError/RuntimeError trigger fallback"
  - "D-26: SystemExit (non-zero exit from command) does NOT trigger fallback"
  - "D-27: Fallback invokes sh/wsha.sh directly via subprocess, not through w entry point (avoids loop)"
  - "D-33: uvx wsha works via run_with_fallback entry point"
  - "D-34: pip install w works via run_with_fallback entry point"

patterns-established:
  - "Pattern: Python module-level errors trigger fallback; command errors do not"

requirements-completed: [SHELL-01, SHELL-02, SHELL-04, SHELL-05]

# Metrics
duration: 5min
completed: 2026-04-13
---

# Phase 04 Plan 02: Shell Fallback & Entry Point Summary

**Fallback mechanism for Python wsha CLI — automatic shell fallback when Python fails, correct pip/uvx entry points.**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-04-13T10:04:00Z
- **Completed:** 2026-04-13T10:09:00Z
- **Tasks:** 2
- **Files modified:** 2

## Task Commits

| Task | Commit | Message |
|------|--------|---------|
| Task 1 | `de7a78d` | feat(04-02): add fallback_to_shell and run_with_fallback |
| Task 2 | `812233b` | fix(04-02): update pyproject.toml entry points and packages path |

## What Was Built

### Task 1: fallback_to_shell() + run_with_fallback()

**py/wsha/cli.py** — added two new functions:

- `fallback_to_shell() -> int`: resolves `sh/wsha.sh` via `__file__` 3-level dirname traversal, invokes `subprocess.run(['bash', wsha_sh] + sys.argv[1:])` with `capture_output=False`. Returns 1 if wsha.sh not found.
- `run_with_fallback() -> None`: wraps `main()` in try/except catching `ImportError`, `FileNotFoundError`, `RuntimeError`. Calls `fallback_to_shell()` on those errors. `SystemExit` is NOT caught — non-zero exits from command execution pass through without triggering fallback.
- `if __name__ == '__main__':` now calls `run_with_fallback()` instead of `main()`.

**Security (T-04-04):** Uses `subprocess.run(['bash', wsha_sh] + sys.argv[1:])` — list form, no `shell=True`. Arguments pass through without shell expansion.

**Loop prevention (T-04-05):** `fallback_to_shell()` calls `bash sh/wsha.sh` directly, bypassing the `w`/`wsha` entry points. No recursive loop.

### Task 2: pyproject.toml Fix

- `w = "wsha.cli:run_with_fallback"` (was `wsha.cli:main`)
- `wsha = "wsha.cli:run_with_fallback"` (was `wsha.cli:main`)
- `packages = ["py/wsha"]` (was `["wsha"]` — incorrect path that didn't exist)

Hatchling can now correctly find and package the wsha package from `py/wsha/`.

## Decisions Made

| Decision | Description |
|----------|-------------|
| D-25 | Only `ImportError`, `FileNotFoundError`, `RuntimeError` trigger fallback — Python module-level errors |
| D-26 | `SystemExit` is NOT caught — non-zero exit from a command (e.g., `w nonexistent` returns 127) is command failure, not a Python error |
| D-27 | Fallback invokes `sh/wsha.sh` directly via `subprocess`, not through `w`/`wsha` entry points — avoids infinite loop |
| D-33 | `uvx wsha` works via `run_with_fallback` entry point |
| D-34 | `pip install wsha` → `w` command works via `run_with_fallback` entry point |

## Verification Results

- All functions importable from `wsha.cli`
- `run_with_fallback` present in `pyproject.toml` entry points
- `py/wsha` packages path in pyproject.toml
- No `except SystemExit` in `cli.py`
- No `shell=True` in fallback subprocess call
- 16/16 CLI helper tests pass
- Non-zero exit from nonexistent alias does NOT trigger fallback (SystemExit passthrough confirmed)

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## Threat Mitigations Verified

| Threat | Mitigation | Status |
|--------|------------|--------|
| T-04-04: Shell injection | `subprocess.run(['bash', wsha_sh] + sys.argv[1:])` — list form, no shell=True | Verified |
| T-04-05: Fallback loop | Calls `bash sh/wsha.sh` directly, bypasses entry points | Verified |
| T-04-06: Path resolution failure | Returns 1 with stderr message if wsha.sh not found | Verified |

## Requirements Met

- SHELL-01: `uvx wsha` runs Python implementation via `run_with_fallback`
- SHELL-02: `pip install wsha` installs `w` command routing to `run_with_fallback`
- SHELL-04: `run_with_fallback` contains fallback logic
- SHELL-05: `w <alias>` routes to Python implementation

---
*Phase: 04-cli-interface-shell-integration*
*Plan: 04-02*
*Completed: 2026-04-13*
