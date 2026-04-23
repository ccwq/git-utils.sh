"""Tests for CLI entry parsing behavior in pip-installed entry points."""

import os
import sys
from unittest.mock import Mock, patch

from click.testing import CliRunner

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "py"))

from wsha.cli import main
from wsha.config import AliasEntry


def make_entry(
    name: str,
    template: str,
    source_name: str = "builtin",
    config_path: str = "/cfg/wsh-alias.txt",
    line_no: int = 1,
) -> AliasEntry:
    """Create an alias entry for CLI tests."""
    return AliasEntry(name, template, config_path, source_name, line_no)


def test_dash_prefixed_command_is_not_treated_as_top_level_option():
    """`w -u` should passthrough as a command input, not fail in Click."""
    runner = CliRunner()
    proc = Mock(returncode=0)

    with patch("wsha.cli.load_config", return_value=([], [], {})), patch(
        "wsha.cli.sp.run", return_value=proc
    ) as run_mock:
        result = runner.invoke(main, ["-u"])

    assert result.exit_code == 0
    run_mock.assert_called_once_with("-u", shell=True)


def test_dash_prefixed_runtime_arg_reaches_alias_template():
    """`w alias -u` should keep `-u` as runtime args for the matched alias."""
    runner = CliRunner()
    aliases = [make_entry("ab", "echo hi --")]

    with patch("wsha.cli.load_config", return_value=(aliases, [], {})), patch(
        "wsha.cli.print_alias_hit"
    ), patch("wsha.cli.invoke_cmd", return_value=0) as invoke_mock:
        result = runner.invoke(main, ["ab", "-u"])

    assert result.exit_code == 0
    invoke_mock.assert_called_once_with("echo hi -u")


def test_top_level_list_flag_still_works():
    """Top-level management flags should still be handled by the Python entry."""
    runner = CliRunner()

    with patch("wsha.cli.load_config", return_value=([], [], {})), patch(
        "wsha.cli.print_list"
    ) as print_list_mock:
        result = runner.invoke(main, ["-l"])

    assert result.exit_code == 0
    print_list_mock.assert_called_once_with([], {})


def test_entry_name_is_exported_for_nested_alias_invocation():
    """Nested commands should inherit `WSHA_ENTRY` from the active entry point."""
    runner = CliRunner()
    aliases = [make_entry("ab", "echo hi")]
    seen = {}

    def fake_invoke(_cmd_text):
        seen["entry"] = os.environ.get("WSHA_ENTRY")
        return 0

    with patch("wsha.cli.load_config", return_value=(aliases, [], {})), patch(
        "wsha.cli.print_alias_hit"
    ), patch("wsha.cli.invoke_cmd", side_effect=fake_invoke), patch(
        "wsha.cli.sys.argv", ["w", "ab"]
    ):
        result = runner.invoke(main, ["ab"])

    assert result.exit_code == 0
    assert seen["entry"] == "w"


def test_alias_hit_prints_exec_preview_to_stderr():
    """Alias execution should print alias hit and final exec command."""
    runner = CliRunner()
    aliases = [make_entry("ab", "echo hi")]

    with patch("wsha.cli.load_config", return_value=(aliases, [], {})), patch(
        "wsha.cli.invoke_cmd", return_value=0
    ), patch("wsha.cli.sys.argv", ["w", "ab"]):
        result = runner.invoke(main, ["ab"])

    assert result.exit_code == 0
    assert "[wsha] alias hit: w ab -> echo hi" in result.stderr
    assert "[wsha] exec: echo hi" in result.stderr


def test_passthrough_command_prints_exec_preview_to_stderr():
    """Non-alias commands should still print the final command preview."""
    runner = CliRunner()
    proc = Mock(returncode=0)

    with patch("wsha.cli.load_config", return_value=([], [], {})), patch(
        "wsha.cli.sp.run", return_value=proc
    ) as run_mock:
        result = runner.invoke(main, ["echo", "hello"])

    assert result.exit_code == 0
    run_mock.assert_called_once_with("echo hello", shell=True)
    assert "[wsha] exec: echo hello" in result.stderr


def test_exec_preview_can_be_disabled_via_env_var():
    """WSHA_PRINT_EXEC=0 should suppress exec preview lines."""
    runner = CliRunner()
    aliases = [make_entry("ab", "echo hi")]

    with patch("wsha.cli.load_config", return_value=(aliases, [], {})), patch(
        "wsha.cli.invoke_cmd", return_value=0
    ), patch("wsha.cli.sys.argv", ["w", "ab"]):
        result = runner.invoke(main, ["ab"], env={"WSHA_PRINT_EXEC": "0"})

    assert result.exit_code == 0
    assert "[wsha] alias hit: w ab -> echo hi" in result.stderr
    assert "[wsha] exec:" not in result.stderr
