"""Regression tests for Windows batch wrapper entrypoints."""

from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


# Given：Windows 用户通过 w.bat 作为 wsha.bat 的语法糖入口。
# When：读取 sh/w.bat 内容。
# Then：应只设置 WSHA_ENTRY=w 并转发到 wsha.bat，不直接依赖 Git Bash launcher。
# 防回归：防止 w.bat 重新引入较重的 exec-git-bash 链路。
def test_w_bat_delegates_to_wsha_bat():
    """`w.bat` should stay a thin sugar wrapper around `wsha.bat`."""
    content = (ROOT / "sh" / "w.bat").read_text(encoding="utf-8")

    assert 'set "WSHA_ENTRY=w"' in content
    assert 'call "%SCRIPT_DIR%wsha.bat" %*' in content
    assert "exec-git-bash.bat" not in content.lower()


# Given：wsha Python core 已迁入 sh/core。
# When：读取 sh/wsha.bat 内容。
# Then：应直接调用 core\wsha_core.py，并继续通过 cmd /c 执行最终命令。
# 防回归：防止 Windows alias 入口仍指向已删除的 sh/wsha-core.py。
def test_wsha_bat_uses_python_core_runtime():
    """`wsha.bat` should call the Python core under `sh/core` directly on Windows."""
    content = (ROOT / "sh" / "wsha.bat").read_text(encoding="utf-8")

    assert 'if not defined WSHA_ENTRY set "WSHA_ENTRY=wsha"' in content
    assert r'set "APP_CONFIG=%APP_SH%\config"' in content
    assert r'set "PY_ENTRY=%SCRIPT_DIR%core\wsha_core.py"' in content
    assert "cmd /c" in content.lower()
    assert "exec-git-bash.bat" not in content.lower()


# Given：Windows 下 wsha_core 需要保留 w/wsha batch 入口规范化。
# When：读取 sh/core/wsha_core.py 内容。
# Then：应仍包含 wsha.bat、w.bat 和 core 路径相关逻辑。
# 防回归：防止迁移 core 后把 Windows batch 入口错误改写成 bash 入口。
def test_wsha_core_keeps_batch_wrappers_on_windows():
    """Windows normalization should keep batch entrypoints while using core helpers."""
    content = (ROOT / "sh" / "core" / "wsha_core.py").read_text(encoding="utf-8")

    assert "os.name == 'nt'" in content or 'os.name == "nt"' in content
    assert "wsha.bat" in content
    assert "w.bat" in content
    assert "core" in content


# Given：exec-git-bash.bat 已迁入 sh/core。
# When：读取 sh/wsh.bat 内容。
# Then：wsh.bat 应调用 %SCRIPT_DIR%core\exec-git-bash.bat。
# 防回归：防止 wsh.bat 继续调用已删除的旧根目录 launcher。
def test_wsh_bat_uses_core_exec_git_bash():
    """`wsh.bat` should call the Git Bash launcher from `sh/core`."""
    content = (ROOT / "sh" / "wsh.bat").read_text(encoding="utf-8")

    assert r'set "EXEC_GIT_BASH=%SCRIPT_DIR%core\exec-git-bash.bat"' in content


# Given：wsh-ping.bat 仍是面向用户的 sh 根目录入口。
# When：读取 sh/wsh-ping.bat 内容。
# Then：预设配置仍应来自 sh/config/wsh-ping.txt。
# 防回归：防止 core 迁移误改与 wsha 无关的 ping 预设路径。
def test_wsh_ping_bat_reads_presets_from_sh_config():
    """`wsh-ping.bat` should read presets from the runtime sh/config directory."""
    content = (ROOT / "sh" / "wsh-ping.bat").read_text(encoding="utf-8")

    assert r'set "CONFIG_FILE=%SCRIPT_DIR%config\wsh-ping.txt"' in content
