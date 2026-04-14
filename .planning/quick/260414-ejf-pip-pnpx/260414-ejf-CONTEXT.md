# Quick Task 260414-ejf: 修复 pip 安装后 pnpx 命令不可用的问题

**Status:** Ready for planning
**Date:** 2026-04-14

## Task Boundary

修复 Python 版本的 `wsha` 在执行 `pnpx @openai/codex@latest` 等命令时提示 `command not found` 的问题。

## Root Cause

Shell 版本 (`sh/wsha.sh`) 的 `invoke_cmd()` 直接通过 bash 执行命令，bash 会做 PATH 查找。

Python 版本 (`py/wsha/expand.py`) 的 `invoke_cmd()` 使用 `subprocess.run([...])` 不带 `shell=True`，Windows 的 `CreateProcess` API 不会查找 PATH。

当执行 `pnpx @openai/codex@latest` 时：
- 不是复杂命令（无 `&&`, `|`, `$()` 等）
- Python 用 `shlex.split()` 分解为 `['pnpx', '@openai/codex@latest']`
- `subprocess.run(['pnpx', ...])` 直接传给 `CreateProcess`，不查 PATH
- Windows 找不到 `pnpx`，报错

## Implementation Decisions

### 执行方式
- 使用 `shell=True` 让 Windows 通过 `cmd.exe` 执行，利用 PATH 查找
- 安全风险：已有 `is_complex_shell_command()` 过滤危险字符，模板是用户配置的 alias 表达式，风险可控

## Specific Ideas

- 修改 `expand.py` 的 `invoke_cmd()`，对非复杂命令使用 `shell=True` 执行

## Canonical References

- `py/wsha/expand.py` L176-182: 当前 `subprocess.run(cmd_tokens)` 无 PATH 查找
