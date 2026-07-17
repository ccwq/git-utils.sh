"""End-to-end tests for the public wsha --env command interface."""

from pathlib import Path
import os
import subprocess


ROOT = Path(__file__).resolve().parent.parent
GIT_BASH_LAUNCHER = ROOT / "sh" / "core" / "exec-git-bash.bat"
WSHA_SH = ROOT / "sh" / "wsha.sh"
WSHA_BAT = ROOT / "sh" / "wsha.bat"
WSHA_PS1 = ROOT / "sh" / "wsha.ps1"


def git_bash_path() -> str:
    """Resolve the repository's supported Git Bash runtime."""
    proc = subprocess.run(
        [str(GIT_BASH_LAUNCHER), "--print-path"],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=True,
    )
    return proc.stdout.strip()


# Given：Windows 用户通过项目公开的 Git Bash `wsha.sh` 入口执行命令。
# When：传入 `-e name=ccwq printenv name`。
# Then：子命令应读取到临时变量 name=ccwq，且命令成功退出。
# 防回归：防止 `-e` 继续解析成旧 `--entry`，或只打印而不实际注入环境。
def test_wsha_env_injects_value_through_git_bash_entry():
    proc = subprocess.run(
        [git_bash_path(), str(WSHA_SH), "-e", "name=ccwq", "printenv", "name"],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )

    assert proc.returncode == 0, proc.stderr
    assert proc.stdout.strip() == "ccwq"


# Given：用户通过长参数连续声明多个变量，其中 tag 的值包含空格。
# When：执行 `--env name=ccwq tag=env plan printenv name tag`。
# Then：两个变量均应作为单次子命令环境传入，空格不得截断 tag。
# 防回归：防止 --env 与 -e 行为分叉，或 shell quote 破坏赋值边界。
def test_wsha_env_supports_long_flag_and_space_values_through_git_bash():
    proc = subprocess.run(
        [
            git_bash_path(),
            str(WSHA_SH),
            "--env",
            "name=ccwq",
            "tag=env plan",
            "printenv",
            "name",
            "tag",
        ],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )

    assert proc.returncode == 0, proc.stderr
    assert proc.stdout.splitlines() == ["ccwq", "env plan"]


# Given：用户启用 env 模式后，在命令参数中引用不存在的变量。
# When：执行 `-e name=ccwq printenv %NOT_DEFINED%`。
# Then：wsha 应在执行前以 exit code 2 报错，并指出变量名。
# 防回归：防止未定义变量被静默替换为空字符串或误传给子命令。
def test_wsha_env_rejects_undefined_command_variable_before_execution():
    proc = subprocess.run(
        [
            git_bash_path(),
            str(WSHA_SH),
            "-e",
            "name=ccwq",
            "printenv",
            "%NOT_DEFINED%",
        ],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )

    assert proc.returncode == 2
    assert "undefined environment variable: NOT_DEFINED" in proc.stderr


# Given：当前环境存在 Windows 用户目录，且第二个 -e 赋值引用第一个赋值。
# When：Git Bash 执行 `ROOT=%USERPROFILE%\\foo CACHE=$ROOT\\cache printenv ROOT CACHE`。
# Then：两个值应按顺序解析，并转换成 Git Bash 可用的 `/c/...` 本地路径。
# 防回归：防止赋值间引用失效，或把 Windows 反斜杠路径原样交给 Git Bash。
def test_wsha_env_resolves_current_and_prior_values_as_git_bash_paths():
    child_env = os.environ.copy()
    child_env["USERPROFILE"] = r"C:\Users\ccwq"
    proc = subprocess.run(
        [
            git_bash_path(),
            str(WSHA_SH),
            "-e",
            r"ROOT=%USERPROFILE%\foo",
            r"CACHE=$ROOT\cache",
            "printenv",
            "ROOT",
            "CACHE",
        ],
        cwd=ROOT,
        text=True,
        capture_output=True,
        env=child_env,
    )

    assert proc.returncode == 0, proc.stderr
    assert proc.stdout.splitlines() == [
        "/c/Users/ccwq/foo",
        "/c/Users/ccwq/foo/cache",
    ]


# Given：当前用户主目录是 Windows 路径，命令同时包含 `~`、URI 与歧义斜杠文本。
# When：Git Bash 执行带 env 前缀的 echo 命令。
# Then：仅 `~` 转为 `/c/...`；`socks5://` 和 `feature/foo` 必须逐字保留。
# 防回归：防止 URI、Git ref 或包名被激进路径转换破坏。
def test_wsha_env_adapts_home_path_without_mutating_uri_or_ambiguous_text():
    child_env = os.environ.copy()
    child_env["USERPROFILE"] = r"C:\Users\ccwq"
    proc = subprocess.run(
        [
            git_bash_path(),
            str(WSHA_SH),
            "-e",
            "tag=test",
            "echo",
            "~/config.json",
            "socks5://localhost:7897",
            "feature/foo",
        ],
        cwd=ROOT,
        text=True,
        capture_output=True,
        env=child_env,
    )

    assert proc.returncode == 0, proc.stderr
    assert proc.stdout.strip() == "/c/Users/ccwq/config.json socks5://localhost:7897 feature/foo"


# Given：alias 配置显式指定 cmd block runner。
# When：Git Bash 入口以 `-e name=ccwq` 调用该 block alias。
# Then：生成的 .cmd 脚本自身应读取到 name，而不是依赖外层 Bash 语法。
# 防回归：保证最终 runner 优先时，跨 Shell block 仍能获得临时环境变量。
def test_wsha_env_injects_into_explicit_cmd_block_runner(tmp_path):
    config_file = tmp_path / "env-block.txt"
    config_file.write_text(
        '"show-env" """cmd\n@echo off\necho %name%\n"""\n',
        encoding="utf-8",
    )
    child_env = os.environ.copy()
    child_env["WSHA_CONFIG_FILE"] = str(config_file)
    proc = subprocess.run(
        [
            git_bash_path(),
            str(WSHA_SH),
            "-e",
            "name=ccwq",
            "show-env",
        ],
        cwd=ROOT,
        text=True,
        capture_output=True,
        env=child_env,
    )

    assert proc.returncode == 0, proc.stderr
    assert proc.stdout.strip() == "ccwq"


# Given：用户配置中的 proxy alias 递归调用 `wsha --env` 注入代理变量。
# When：通过公开 Git Bash 入口执行 `proxy printenv http_proxy https_proxy`。
# Then：递归 alias 里的 --env 必须被重新解析，两个变量传给最终子命令。
# 防回归：防止 --env 在递归展开后退化成 CMD/Bash 试图执行的字面命令。
def test_wsha_proxy_alias_reparses_recursive_env_prefix(tmp_path):
    config_file = tmp_path / "proxy-env.txt"
    config_file.write_text(
        "proxy wsha --env http_proxy=http://localhost:7897 https_proxy=http://localhost:7897\n",
        encoding="utf-8",
    )
    child_env = os.environ.copy()
    child_env["WSHA_CONFIG_FILE"] = str(config_file)
    proc = subprocess.run(
        [
            git_bash_path(),
            str(WSHA_SH),
            "proxy",
            "printenv",
            "http_proxy",
            "https_proxy",
        ],
        cwd=ROOT,
        text=True,
        capture_output=True,
        env=child_env,
    )

    assert proc.returncode == 0, proc.stderr
    assert proc.stdout.splitlines() == [
        "http://localhost:7897",
        "http://localhost:7897",
    ]


# Given：Windows CMD 用户通过公开的 `wsha.bat` 入口执行子命令。
# When：传入 `-e name=ccwq cmd /c set name`。
# Then：CMD 子进程应继承临时变量并输出 `name=ccwq`。
# 防回归：防止 CMD 渲染格式错误，或临时变量未传给真正执行的子进程。
def test_wsha_env_injects_value_through_cmd_entry():
    proc = subprocess.run(
        [str(WSHA_BAT), "-e", "name=ccwq", "cmd", "/d", "/c", "set name"],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )

    assert proc.returncode == 0, proc.stderr
    assert proc.stdout.strip() == "name=ccwq"


# Given：CMD 目标 Shell 的 USERPROFILE 是 Windows 绝对路径。
# When：用户将 `~\\config.json` 作为命令参数传给 wsha。
# Then：CMD 子进程收到的应是 `%USERPROFILE%` 展开的 Windows 路径。
# 防回归：防止 `~` 只在 Bash 生效，或被错误保留为字面量。
def test_wsha_env_expands_home_path_through_cmd_entry():
    proc = subprocess.run(
        [
            str(WSHA_BAT),
            "-e",
            r"USERPROFILE=C:\Users\ccwq",
            "cmd",
            "/d",
            "/c",
            "echo",
            r"~\config.json",
        ],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )

    assert proc.returncode == 0, proc.stderr
    assert proc.stdout.strip() == r"C:\Users\ccwq\config.json"


# Given：PowerShell 用户通过公开的 `wsha.ps1` 原生入口执行命令。
# When：传入 `-e name=ccwq powershell -Command Write-Output $env:name`。
# Then：PowerShell 子进程应读取到 name=ccwq，且入口可正常返回退出码。
# 防回归：防止 PowerShell 被迫走 CMD 语法，或临时环境变量泄漏到调用会话。
def test_wsha_env_injects_value_through_powershell_entry():
    proc = subprocess.run(
        [
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(WSHA_PS1),
            "-e",
            "name=ccwq",
            "powershell.exe",
            "-NoProfile",
            "-Command",
            "Write-Output $env:name",
        ],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )

    assert proc.returncode == 0, proc.stderr
    assert proc.stdout.strip() == "ccwq"


# Given：PowerShell 目标 Shell 使用 Windows USERPROFILE 路径。
# When：通过 `wsha.ps1` 将 `~/config.json` 传给 Write-Output。
# Then：输出应是 Windows 格式的用户目录路径。
# 防回归：防止 PowerShell 入口错误复用 Git Bash 的 `/c/...` 路径格式。
def test_wsha_env_expands_home_path_through_powershell_entry():
    proc = subprocess.run(
        [
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(WSHA_PS1),
            "-e",
            r"USERPROFILE=C:\Users\ccwq",
            "Write-Output",
            "~/config.json",
        ],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )

    assert proc.returncode == 0, proc.stderr
    assert proc.stdout.strip() == r"C:\Users\ccwq\config.json"
