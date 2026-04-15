"""Regression tests for runtime-arg insertion around long-option flags."""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "py"))

from wsha.expand import expand_template


def test_long_option_is_not_mistaken_for_placeholder():
    """Flags like `--cdp` must not swallow runtime args."""
    final_cmd, exit_code = expand_template(
        "wsha ab --cdp 9222", [], "", ["open", "t.cn"]
    )

    assert exit_code == 0
    assert final_cmd == "wsha ab --cdp 9222 open t.cn"


def test_standalone_placeholder_still_inserts_runtime_args():
    """A real `--` token should keep placeholder behavior."""
    final_cmd, exit_code = expand_template("echo hi -- tail", [], "", ["open", "t.cn"])

    assert exit_code == 0
    assert final_cmd == "echo hi open t.cn tail"
