"""Tests for sh/core/wsha_core top-level argument parsing."""

from importlib import import_module
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parent.parent
CORE_PARENT = ROOT / "sh" / "core"


def load_wsha_core():
    """Load the wsha_core package from sh/core."""
    core_parent = str(CORE_PARENT)
    if core_parent not in sys.path:
        sys.path.insert(0, core_parent)
    return import_module("wsha_core")


# Given：wrapper 通过内部长参数指定 w 入口，并在 alias 后传入 dash-prefixed 参数。
# When：解析 --entry w codex-l --model gpt-5.4-mini。
# Then：--model 应保留为 alias 的运行时参数，而不是被 core 当成顶层选项。
# 防回归：`-e` 改为用户 env 参数后，内部 entry 仍能通过 `--entry` 传递。
def test_parse_cli_args_keeps_dash_prefixed_runtime_args():
    """Alias runtime flags should be preserved verbatim after the alias."""
    mod = load_wsha_core()

    result = mod.parse_cli_args(["--entry", "w", "codex-l", "--model", "gpt-5.4-mini"])

    assert result.valid is True
    assert result.entry == "w"
    assert result.alias == "codex-l"
    assert result.args == ["--model", "gpt-5.4-mini"]
    assert result.env_assignments == []


# Given：用户调用 alias 并把 --help 作为目标命令参数。
# When：解析 codex-l --help。
# Then：--help 应保留在 runtime args 中，不触发 wsha-core 自身帮助。
# 防回归：防止 w alias --help 无法转发到目标命令。
def test_parse_cli_args_keeps_alias_help_as_runtime_arg():
    """`w alias --help` should forward help to the target command, not wsha-core."""
    mod = load_wsha_core()

    result = mod.parse_cli_args(["codex-l", "--help"])

    assert result.valid is True
    assert result.entry == mod.WSHA_ENTRY
    assert result.alias == "codex-l"
    assert result.args == ["--help"]
