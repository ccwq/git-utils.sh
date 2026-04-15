---
phase: 05-test-compatibility-validation
plan: 01
plan_name: Python test compatibility wrapper and execution fixes
subsystem: wsha Python compatibility
status: complete
tags:
  - python
  - testing
  - cli
  - config
  - shell-compatibility
dependency_graph:
  requires:
    - __test__/wsha.test.sh
    - sh/wsha.sh
    - py/wsha/config.py
    - py/wsha/expand.py
    - py/wsha/cli.py
  provides:
    - __test__/wsha-py.sh
    - WSHA_CONFIG_FILE single-file compatibility
    - shell-compatible alias hit logging
    - direct stdout/stderr passthrough for invoked commands
  affects:
    - test harness invocation path
    - Python config discovery
    - Python command execution behavior
tech_stack:
  added:
    - Bash wrapper for Python CLI testing
  patterns:
    - env var path normalization for Git Bash on Windows
    - single-file config override via WSHA_CONFIG_FILE
    - stderr alias-hit logging mirroring shell implementation
key_files:
  created:
    - __test__/wsha-py.sh
  modified:
    - py/wsha/config.py
    - py/wsha/expand.py
    - py/wsha/cli.py
decisions:
  - Use a dedicated test wrapper script so the existing test harness can target the Python CLI without changing the suite.
  - Treat WSHA_OVERRIDE_HOME as a test/runtime bridge for Windows path resolution while keeping the cache directory unchanged.
  - Emit alias-hit logs from cli.py, not invoke_cmd(), so execution remains separated from match reporting.
metrics:
  duration: unknown
  completed_date: "2026-04-14"
---

# Phase 05 Plan 01 Summary

本计划完成了 Python 版 wsha 的测试接入与三处关键兼容性修复：补齐测试包装脚本、修正默认配置路径发现、以及让命令执行结果真正透传到终端。

## Completed Work

### Task 1: Create `__test__/wsha-py.sh`
- Added a Bash wrapper that forwards the test harness into `python -m wsha.cli`.
- Set `APP_HOME`、`APP_SH`、`APP_CONFIG` to match the shell implementation's runtime expectations.
- Added `PYTHONPATH` so the test wrapper can import the local `py/wsha` package.
- Converted `WSHA_CONFIG_FILE` and `HOME` into Windows-friendly paths for Python consumption.
- Marked the script executable.

### Task 2: Fix `py/wsha/config.py`
- Added support for `WSHA_CONFIG_FILE` in single-file mode.
- Honored `WSHA_OVERRIDE_HOME` and `HOME` before falling back to `Path.home()`.
- Corrected project-level config discovery from `config/wsh-alias.txt` to `.config/wsh-alias.txt`.
- Kept the cache directory logic unchanged as requested.

### Task 3: Fix `py/wsha/expand.py` and `py/wsha/cli.py`
- Removed subprocess output capture so command output flows directly to stdout/stderr.
- Added `print_alias_hit()` to mirror the shell version's stderr logging format.
- Moved alias-hit logging into `cli.py`, keeping execution and reporting responsibilities separated.

## Verification

### Automated checks
- `python -c "from wsha.config import get_default_config_paths, load_config; from wsha.expand import invoke_cmd, print_alias_hit; print('ok')"` passed.
- `python -m wsha.cli --help` passed.
- `bash __test__/wsha-py.sh --help` passed.
- `bash -n __test__/wsha-py.sh` passed.

### Notes
- A direct `python3` invocation in this environment returned exit code 49, so the wrapper now falls back to `python` when `python3` is unavailable or unhealthy. This preserved testability on the current host without changing the CLI contract for normal environments.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking issue] Python3 launcher was not usable in this environment**
- **Found during:** Task 1 verification
- **Issue:** `python3` returned exit code 49 on this host, preventing the wrapper from launching the Python CLI reliably.
- **Fix:** The wrapper now chooses `python3` when available and healthy, otherwise falls back to `python`.
- **Files modified:** `__test__/wsha-py.sh`
- **Commit:** `2aab0d2`

**2. [Rule 1 - Bug] Command execution was swallowing output**
- **Found during:** Task 3
- **Issue:** `subprocess.run(..., capture_output=True)` prevented invoked commands from printing to the terminal.
- **Fix:** Removed output capture and let the child process inherit stdout/stderr.
- **Files modified:** `py/wsha/expand.py`
- **Commit:** `9c6acaa`

**3. [Rule 2 - Missing critical functionality] Alias-hit logging was absent in Python CLI flow**
- **Found during:** Task 3
- **Issue:** The Python CLI did not emit the shell-compatible `[wsha] alias hit:` message.
- **Fix:** Added `print_alias_hit()` and called it from `cli.py` before command execution.
- **Files modified:** `py/wsha/expand.py`, `py/wsha/cli.py`
- **Commit:** `9c6acaa`

## Known Stubs

None.

## Threat Flags

None.

## Commits

- `2aab0d2` — feat(05-01): add Python test wrapper for wsha
- `b236c65` — fix(05-01): honor test config path overrides
- `9c6acaa` — fix(05-01): stream command output through the Python CLI

## Self-Check: PASSED

- [x] `E:/project/self.project/git-utils.sh/.planning/phases/05-test-compatibility-validation/05-01-SUMMARY.md` exists
- [x] All task commits exist in git history
- [x] Verification commands passed
