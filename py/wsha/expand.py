"""Template expansion and command execution engine for wsha.

This module provides the final stage of alias processing:
1. Expand template variables ($1, $2, $$) with captured values
2. Handle -- placeholder for runtime argument insertion
3. Expand %VAR% environment variables at runtime
4. Execute the final command with proper exit codes
"""

import os
import re
import subprocess
import shlex
from typing import Tuple


def is_complex_shell_command(text: str) -> bool:
    """
    Detect complex shell command patterns that require shell evaluation.

    Per shell L69-79: 检测 &&, ||, |, ;, >, <, $(), ``
    These patterns indicate shell features that can't be directly executed.

    Args:
        text: Command string to check

    Returns:
        True if command contains shell metacharacters, False otherwise
    """
    if "&&" in text:
        return True
    if "||" in text:
        return True
    if "|" in text:
        return True
    if ";" in text:
        return True
    if ">" in text:
        return True
    if "<" in text:
        return True
    if "$(" in text:
        return True
    if "`" in text:
        return True
    return False


def expand_env_vars(text: str) -> str:
    """
    Expand %VAR% style environment variables at runtime.

    Per D-21: 运行时展开 — 每次执行时从当前环境读取 %VAR% 并替换

    Args:
        text: String containing %VAR% patterns

    Returns:
        String with %VAR% replaced by environment values

    Example:
        >>> os.environ['HOME'] = '/home/user'
        >>> expand_env_vars('cd %HOME%')
        'cd /home/user'
    """
    # Pattern: %VAR% (Windows-style env var syntax)
    pattern = r'%([^%]+)%'

    def replacer(match):
        var_name = match.group(1)
        return os.environ.get(var_name, match.group(0))

    return re.sub(pattern, replacer, text)


def expand_template(
    template: str, captures: list[str], rest_capture: str, runtime_args: list[str]
) -> Tuple[str, int]:
    """
    Expand template variables with captured values and runtime arguments.

    Per D-19: 从后向前 scan 替换 $1, $2, $$
    Per D-20: -- 占位符控制运行时参数插入位置

    Processing order:
    1. Replace $1, $2, ... from captures (end-to-start to avoid $10误匹配)
    2. Replace $$ with rest_capture (remainder from ** pattern)
    3. Insert runtime_args at -- position or append to end

    Args:
        template: Template string with $1, $2, $$ placeholders
        captures: List of captured values from pattern matching
        rest_capture: Remainder capture from ** pattern
        runtime_args: Arguments to insert at -- or append

    Returns:
        Tuple of (expanded_command, exit_code_hint)
        exit_code_hint is 0 for success, non-zero for known error conditions

    Example:
        >>> expand_template('echo $1 $2', ['arg1', 'arg2'], '', [])
        ('echo arg1 arg2', 0)
        >>> expand_template('run $$', [], 'rest args', [])
        ('run rest args', 0)
        >>> expand_template('cmd -- extra', [], '', ['arg1', 'arg2'])
        ('cmd arg1 arg2 extra', 0)
    """
    final_template = template

    # From back to front to ensure $10 is not mistakenly matched as $1+0
    # Per shell L1012: for ((ci = ${#_BEST_CAPTURES[@]}; ci >= 1; ci--))
    for ci in range(len(captures), 0, -1):
        final_template = final_template.replace(f"${ci}", captures[ci - 1])

    # Replace $$ with rest capture (remainder from ** pattern)
    final_template = final_template.replace("$$", rest_capture)

    # Handle -- placeholder for runtime argument insertion.
    # Only a standalone "--" token is a placeholder; flags like "--cdp"
    # must behave like normal arguments and still keep appended runtime args.
    tokens = shlex.split(final_template)
    final_tokens = []
    placeholder_found = False

    for token in tokens:
        if token == "--":
            placeholder_found = True
            if runtime_args:
                final_tokens.extend(runtime_args)
        else:
            final_tokens.append(token)

    if placeholder_found:
        final_template = " ".join(final_tokens)
    elif runtime_args:
        final_template = final_template + " " + " ".join(runtime_args)

    # Success exit code
    return (final_template, 0)


def print_alias_hit(entry: str, raw_input: str, final_cmd: str) -> None:
    """
    Print the alias hit message to stderr.

    Per shell L1056:
    echo "[wsha] alias hit: $entry $raw_input -> $final_cmd" >&2
    """
    import sys

    print(f"[wsha] alias hit: {entry} {raw_input} -> {final_cmd}", file=sys.stderr)


def invoke_cmd(cmd_text: str) -> int:
    """
    Execute the expanded command and return exit code.

    Per D-22, D-23:
    1. Expand %VAR% environment variables
    2. Detect complex shell commands (pipes, redirects, etc.)
    3. Execute appropriately (subprocess vs shell)
    4. Return standardized exit codes (0, 1, 127)

    Args:
        cmd_text: Command string to execute

    Returns:
        Exit code: 0 (success), 1 (error), 127 (command not found)
    """
    # Step 1: Expand environment variables
    cmd_text = expand_env_vars(cmd_text)

    # Step 2: Check if it's a complex shell command
    if not is_complex_shell_command(cmd_text):
        # Simple command - use shell=True so Windows searches PATH
        try:
            result = subprocess.run(cmd_text, shell=True)
            return result.returncode
        except FileNotFoundError:
            import sys

            # Command not found
            command_name = shlex.split(cmd_text)[0] if cmd_text else 'cmd'
            print(f"bash: {command_name}: command not found", file=sys.stderr)
            return 127
        except Exception as exc:
            import sys

            # General error
            print(f"Error executing command: {exc}", file=sys.stderr)
            return 1
    else:
        # Complex shell command - use bash -c
        try:
            result = subprocess.run(["bash", "-c", cmd_text])
            return result.returncode
        except FileNotFoundError:
            import sys

            # bash not found
            print("bash: command not found", file=sys.stderr)
            return 127
        except Exception as exc:
            import sys

            # General error
            print(f"Error executing command: {exc}", file=sys.stderr)
            return 1
