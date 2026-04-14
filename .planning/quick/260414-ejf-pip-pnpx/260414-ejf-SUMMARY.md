# Quick Task 260414-ejf: 修复 pip 安装后 pnpx 命令不可用

**Date:** 2026-04-14
**Commit:** (pending)

## Summary

修复了 Python 版本的 wsha 在执行 `pnpx` 等命令时提示 `command not found` 的问题。

## Root Cause

Python 版本的 `invoke_cmd()` 使用 `subprocess.run([cmd_tokens])` 直接传递命令列表给 Windows `CreateProcess` API，不经过 shell 因此无法查找 PATH。

Shell 版本通过 bash 执行，bash 会自动搜索 PATH。

## Fix

修改 `py/wsha/expand.py` 中 `invoke_cmd()` 函数：
- 非复杂命令使用 `subprocess.run(cmd_text, shell=True)` 让 Windows 通过 cmd.exe 执行
- 复杂命令（包含 `&&`, `|`, `>` 等）保持使用 `bash -c` 不变

## Testing

- `pnpx --version` 现在可以通过 PATH 找到（之前报 `command not found`）
- `echo hello wsha` 正常执行，exit code 0
- 所有 11 个核心 Python 测试通过

## Files Changed

- `py/wsha/expand.py` — `invoke_cmd()` 中的非复杂命令执行逻辑
