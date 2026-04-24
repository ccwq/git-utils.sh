"""Regression tests for Windows batch wrapper entrypoints."""

from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def test_w_bat_delegates_to_wsha_bat():
    """`w.bat` should stay a thin sugar wrapper around `wsha.bat`."""
    content = (ROOT / "sh" / "w.bat").read_text(encoding="utf-8")

    assert 'set "WSHA_ENTRY=w"' in content
    assert 'call "%SCRIPT_DIR%wsha.bat" %*' in content
    assert "exec-git-bash.bat" not in content.lower()


def test_wsha_bat_uses_python_core_runtime():
    """`wsha.bat` should call `wsha-core.py` directly on Windows."""
    content = (ROOT / "sh" / "wsha.bat").read_text(encoding="utf-8")

    assert 'if not defined WSHA_ENTRY set "WSHA_ENTRY=wsha"' in content
    assert r'set "APP_CONFIG=%APP_SH%\config"' in content
    assert "wsha-core.py" in content
    assert "cmd /c" in content.lower()
    assert "exec-git-bash.bat" not in content.lower()


def test_wsha_core_keeps_batch_wrappers_on_windows():
    """Windows normalization should keep batch entrypoints instead of rewriting them to bash."""
    content = (ROOT / "sh" / "wsha-core.py").read_text(encoding="utf-8")

    assert "os.name == 'nt'" in content or 'os.name == "nt"' in content
    assert "wsha.bat" in content
    assert "w.bat" in content


def test_wsh_ping_bat_reads_presets_from_sh_config():
    """`wsh-ping.bat` should read presets from the runtime sh/config directory."""
    content = (ROOT / "sh" / "wsh-ping.bat").read_text(encoding="utf-8")

    assert r'set "CONFIG_FILE=%SCRIPT_DIR%config\wsh-ping.txt"' in content
