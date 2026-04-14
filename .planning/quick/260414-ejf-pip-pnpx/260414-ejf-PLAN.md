# Quick Task 260414-ejf: 修复 pip 安装后 pnpx 命令不可用的问题

**Date:** 2026-04-14
**Mode:** quick

## Task

修复 Python 版本的 wsha 在执行 `pnpx` 等命令时提示 `command not found` 的问题。

## Root Cause

Python 版本的 `invoke_cmd()` 使用 `subprocess.run([cmd_tokens])` 直接传递命令列表给 Windows `CreateProcess` API，不经过 shell 因此无法查找 PATH。Shell 版本通过 bash 执行自然有 PATH 查找。

## Plan

### Task 1: 修复 expand.py 中的命令执行

**File:** `py/wsha/expand.py`

**Action:**
将 `invoke_cmd()` 函数中非复杂命令的执行方式从 `subprocess.run(cmd_tokens)` 改为 `subprocess.run(cmd_text, shell=True)`。

具体修改：
1. 在 else 分支（复杂命令）保持 `subprocess.run(["bash", "-c", cmd_text])` 不变
2. 在 if 分支（非复杂命令）改为 `subprocess.run(cmd_text, shell=True)` 让 Windows 通过 cmd.exe 执行命令

**Verify:**
- `w codex-l` 能正常执行 `pnpx @openai/codex@latest`
- `w bu hello` 能正常执行 `uvx browser-use hello`
- `w ls` 能正常执行 `wsh.bat ls -ah`
- 不影响复杂命令执行（如 `git.sync` 中的 `git pull && git push`）

**Done:** 修改后的代码通过了现有测试用例
