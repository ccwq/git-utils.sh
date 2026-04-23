"""Regression tests for Windows batch wrapper entrypoints."""

from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def test_w_bat_delegates_to_exec_git_bash():
    """`w.bat` should use the Git Bash launcher instead of a hardcoded Python path."""
    content = (ROOT / "sh" / "w.bat").read_text(encoding="utf-8")

    assert 'set "WSHA_ENTRY=w"' in content
    assert 'call "%SCRIPT_DIR%exec-git-bash.bat" "%SCRIPT_DIR%wsha.sh" %*' in content
    assert "python.exe" not in content.lower()
