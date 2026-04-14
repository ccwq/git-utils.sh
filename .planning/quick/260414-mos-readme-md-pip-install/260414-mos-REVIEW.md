---
phase: 260414-mos-readme-md-pip-install
reviewed: 2026-04-14T10:30:00Z
depth: quick
files_reviewed: 2
files_reviewed_list:
  - py/wsha/cli.py
  - py/wsha/config.py
findings:
  critical: 1
  warning: 1
  info: 0
  total: 2
status: issues_found
---

# Phase 260414-mos-readme-md-pip-install: Code Review Report

**Reviewed:** 2026-04-14T10:30:00Z
**Depth:** quick
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Reviewed 2 Python source files using quick depth pattern-matching. Found 1 critical security issue related to shell command execution and 1 warning for overly broad exception handling. Documentation files (README.md), build configuration (pyproject.toml), and data files were excluded from review.

## Critical Issues

### CR-01: Shell Injection Risk via shell=True with User Input

**File:** `py/wsha/cli.py:155-160`
**Issue:** The code uses `subprocess.run()` with `shell=True` and user-provided input (`input_text`). While `input_text` is constructed from alias configurations and command-line arguments, executing arbitrary shell commands without proper escaping poses a security risk, especially if alias definitions contain malicious templates or if this is used in a multi-user environment.

```python
result = sp.run(input_text, shell=True)
raise SystemExit(result.returncode)
```

This pattern appears at lines 155-156 and 159-161 (fallback when no alias matches).

**Fix:**
If the command must be executed through a shell, consider:
1. Validating/sanitizing input before execution
2. Using `shlex.quote()` for user-provided arguments
3. Documenting the security model for alias configuration files (trusted source only)

```python
# Alternative: parse and execute without shell when possible
import shlex
tokens = shlex.split(input_text)
if tokens:
    result = sp.run(tokens)
    raise SystemExit(result.returncode)
```

Note: Given this is an alias launcher (like a shell alias system), `shell=True` may be intentional. In this case, ensure documentation clearly states that alias configuration files should only be writable by trusted users.

## Warnings

### WR-01: Overly Broad Exception Handling

**File:** `py/wsha/config.py:69`
**Issue:** The code catches `Exception` without re-raising or logging, which could silently hide important errors like permission issues or disk failures during the user config copy operation.

```python
try:
    default_content = files('wsha.data').joinpath('default.txt').read_text(encoding='utf-8')
    user_file.write_text(default_content, encoding='utf-8')
except Exception:
    # 如果复制失败，尝试从 APP_HOME 复制（开发时）
```

**Fix:**
Catch specific exceptions or log the error for debugging:

```python
except (FileNotFoundError, PermissionError, OSError) as e:
    # 如果复制失败，尝试从 APP_HOME 复制（开发时）
    # Consider logging: logger.debug(f"Failed to copy default config: {e}")
    pass
```

---

_Reviewed: 2026-04-14T10:30:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: quick_