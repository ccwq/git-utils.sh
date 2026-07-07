"""Regression tests for runtime-arg insertion around long-option flags."""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "py"))

from wsha.expand import expand_template


# Given：模板中包含普通 long option，但没有 $@ 插入点。
# When：传入运行时参数。
# Then：运行时参数应追加到末尾，--cdp 不应被当作占位符。
# 防回归：防止 long option 误吞 alias 后续参数。
def test_long_option_is_not_mistaken_for_placeholder():
    """Flags like `--cdp` must not swallow runtime args."""
    final_cmd, exit_code = expand_template(
        "wsha ab --cdp 9222", [], "", ["open", "t.cn"]
    )

    assert exit_code == 0
    assert final_cmd == "wsha ab --cdp 9222 open t.cn"


# Given：模板中包含显式 $@ 插入点，后面还有目标命令固定参数。
# When：传入运行时参数。
# Then：运行时参数应插入到 $@ 位置，且 -- 不再具备占位符语义。
# 防回归：防止旧 -- placeholder 语义重新与目标 CLI option terminator 冲突。
def test_dollar_at_placeholder_inserts_runtime_args():
    """A real `$@` token should insert runtime args at that position."""
    final_cmd, exit_code = expand_template("echo hi $@ tail", [], "", ["open", "t.cn"])

    assert exit_code == 0
    assert final_cmd == "echo hi open t.cn tail"


# Given：模板中包含 standalone --，它属于目标 CLI 的真实 option terminator。
# When：传入运行时参数。
# Then：运行时参数应追加到末尾，而不是插入到 -- 位置。
# 防回归：防止 breaking change 后旧 -- 占位符语义回流。
def test_standalone_dash_dash_is_target_cli_argument():
    """A standalone `--` token should stay literal for the target CLI."""
    final_cmd, exit_code = expand_template("echo hi -- tail", [], "", ["open", "t.cn"])

    assert exit_code == 0
    assert final_cmd == "echo hi -- tail open t.cn"
