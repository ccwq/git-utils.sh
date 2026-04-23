"""Tests for sh/wsha-core.py top-level argument parsing."""

from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
CORE_PATH = ROOT / "sh" / "wsha-core.py"


def load_wsha_core():
    """Load the script module directly from sh/wsha-core.py."""
    spec = spec_from_file_location("wsha_core", CORE_PATH)
    module = module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_parse_cli_args_keeps_dash_prefixed_runtime_args():
    """Alias runtime flags should be preserved verbatim after the alias."""
    mod = load_wsha_core()

    result = mod.parse_cli_args(["-e", "w", "codex-l", "--model", "gpt-5.4-mini"])

    assert result == (False, False, False, "w", "codex-l", ["--model", "gpt-5.4-mini"])


def test_parse_cli_args_keeps_alias_help_as_runtime_arg():
    """`w alias --help` should forward help to the target command, not wsha-core."""
    mod = load_wsha_core()

    result = mod.parse_cli_args(["codex-l", "--help"])

    assert result == (False, False, False, mod.WSHA_ENTRY, "codex-l", ["--help"])
