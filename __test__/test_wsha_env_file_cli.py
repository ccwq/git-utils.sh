"""Public-entry integration tests for dotenv files."""

from pathlib import Path
import json
import os
import subprocess
import sys

import pytest

ROOT = Path(__file__).resolve().parent.parent


def entry_command(entry):
    if entry == "bash":
        launcher = ROOT / "sh/core/exec-git-bash.bat"
        bash = subprocess.run([str(launcher), "--print-path"], capture_output=True, text=True, check=True).stdout.strip()
        return [bash, str(ROOT / "sh/wsha.sh")]
    if entry == "powershell":
        return ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(ROOT / "sh/wsha.ps1")]
    return [str(ROOT / "sh" / entry)]


def invoke(entry, args, cwd, config="", env=None):
    child_env = dict(os.environ if env is None else env)
    child_env["WSHA_CONFIG_FILE"] = str(config or cwd / "aliases.txt")
    child_env["PYTHONIOENCODING"] = "utf-8"
    return subprocess.run(entry_command(entry) + args, cwd=cwd, env=child_env, capture_output=True, text=True, encoding="utf-8")


def make_probe(tmp_path):
    probe = tmp_path / "probe.py"
    probe.write_text("import json, os, sys\nprint(json.dumps({key: os.environ.get(key) for key in sys.argv[1:]}, ensure_ascii=True))\n", encoding="utf-8")
    return [sys.executable, "./probe.py"]


# Given：四个公开入口和两个带空格路径的 dotenv 文件，父环境含旧值。
# When：混用 -e/--env 文件与显式赋值执行 Python 子命令。
# Then：重复选项保持顺序、值边界正确，父环境不污染。
# 防回归：防止 PowerShell 参数绑定吞掉重复 -e 或 Windows wrapper 丢失文件路径引号。
@pytest.mark.parametrize("entry", ["bash", "w.bat", "wsha.bat", "powershell"])
def test_public_entries_load_ordered_env_files(entry, tmp_path):
    probe = make_probe(tmp_path)
    (tmp_path / "base config.env").write_text("WSHA_TEST_VALUE=base\nBEFORE=$WSHA_TEST_VALUE\nMESSAGE=\"hello world\"\n", encoding="utf-8")
    (tmp_path / "local.env").write_text("WSHA_TEST_VALUE=local\nAFTER=${WSHA_TEST_VALUE}\n", encoding="utf-8")
    parent = os.environ.get("WSHA_TEST_VALUE")
    child_env = dict(os.environ, WSHA_TEST_VALUE="parent")
    proc = invoke(entry, ["-e", "./base config.env", "--env", "./local.env", "-e", "WSHA_TEST_VALUE=cli"] + probe + ["WSHA_TEST_VALUE", "BEFORE", "AFTER", "MESSAGE"], tmp_path, env=child_env)
    assert proc.returncode == 0, proc.stderr
    assert json.loads(proc.stdout) == {"WSHA_TEST_VALUE": "cli", "BEFORE": "base", "AFTER": "local", "MESSAGE": "hello world"}
    assert os.environ.get("WSHA_TEST_VALUE") == parent


# Given：env 文件包含 shell 元字符，值应仅作为环境数据传给子命令。
# When：经各入口执行探针读取这些值。
# Then：值不得截断、重复转义或执行为 shell 语句。
# 防回归：防止读取 dotenv 文件变成代码执行入口。
@pytest.mark.parametrize("entry", ["bash", "w.bat", "powershell"])
def test_env_file_special_characters_are_data(entry, tmp_path):
    probe = make_probe(tmp_path)
    value = 'a&b|c;d>e<f!g^h#i=j "quote"'
    (tmp_path / "special.env").write_text("VALUE=" + value + "\n", encoding="utf-8")
    proc = invoke(entry, ["-e", "./special.env"] + probe + ["VALUE"], tmp_path)
    assert proc.returncode == 0, proc.stderr
    assert json.loads(proc.stdout) == {"VALUE": value}


# Given：普通 alias 模板引用文件变量，变量中含空格。
# When：通过 env 文件调用 alias。
# Then：模板引用和最终参数应得到同一值，仍保留单参数边界。
# 防回归：防止 %VAR% 在模板分词前被清空或展开后拆成多个参数。
@pytest.mark.parametrize("entry", ["bash", "w.bat", "powershell"])
def test_file_variables_expand_in_alias_templates(entry, tmp_path):
    (tmp_path / "foo.env").write_text('NAME="hello world"\n', encoding="utf-8")
    config = tmp_path / "aliases.txt"
    argv_script = tmp_path / "argv.py"
    argv_script.write_text("import json, sys\nprint(json.dumps(sys.argv[1:]))\n", encoding="utf-8")
    config.write_text('show python ./argv.py "%NAME%"\n', encoding="utf-8")
    proc = invoke(entry, ["-e", "./foo.env", "show"], tmp_path, config)
    assert proc.returncode == 0, proc.stderr
    assert json.loads(proc.stdout) == ["hello world"]


# Given：递归 alias 自行引入 env 文件，嵌套赋值引用该层覆盖后的值。
# When：从外层 A=outer 调用递归 alias。
# Then：嵌套 B 应为 inner，不得过早引用 outer。
# 防回归：防止在解析嵌套 env 来源之前展开赋值右值。
def test_recursive_alias_loads_file_and_preserves_reference_order(tmp_path):
    make_probe(tmp_path)
    (tmp_path / "inner.env").write_text("A=inner\n", encoding="utf-8")
    config = tmp_path / "aliases.txt"
    config.write_text('nested wsha -e ./inner.env -e B=$A show\nshow python ./probe.py A B\n', encoding="utf-8")
    proc = invoke("bash", ["-e", "A=outer", "nested"], tmp_path, config)
    assert proc.returncode == 0, proc.stderr
    assert json.loads(proc.stdout) == {"A": "inner", "B": "inner"}


# Given：递归 alias 在没有外层 env 时自行引入文件来源。
# When：调用普通 alias 进入嵌套 --env 文件加载。
# Then：文件变量可用于下一层模板，且未定义引用执行前报错。
# 防回归：防止嵌套来源被最终 wrapper 当作字面命令执行。
def test_recursive_alias_file_without_outer_env(tmp_path):
    (tmp_path / "inner.env").write_text("NAME=nested\n", encoding="utf-8")
    config = tmp_path / "aliases.txt"
    config.write_text('nested wsha --env ./inner.env show\nshow echo %NAME%\n', encoding="utf-8")
    proc = invoke("bash", ["nested"], tmp_path, config)
    assert proc.returncode == 0, proc.stderr
    assert proc.stdout.strip() == "nested"


# Given：文件含格式错误、缺失变量或不存在路径，目标命令会创建 marker。
# When：在不同入口使用该文件执行命令。
# Then：返回 2、不创建 marker、不泄漏 traceback。
# 防回归：防止无效配置在 shell 中继续执行目标命令。
@pytest.mark.parametrize("entry", ["bash", "w.bat", "powershell"])
@pytest.mark.parametrize("content", ["INVALID\n", "KEY=$WSHA_TEST_NOT_DEFINED\n", None])
def test_file_errors_stop_before_target(entry, content, tmp_path):
    marker = tmp_path / "marker.txt"
    (tmp_path / "target.py").write_text("from pathlib import Path\nPath('marker.txt').touch()\n", encoding="utf-8")
    if content is not None:
        (tmp_path / "bad.env").write_text(content, encoding="utf-8")
    proc = invoke(entry, ["-e", "./bad.env", sys.executable, "./target.py"], tmp_path)
    combined_output = proc.stdout + proc.stderr
    assert proc.returncode == 2, combined_output
    assert not marker.exists()
    assert "bad.env" in combined_output
    assert "Traceback" not in combined_output


# Given：明确 runner 的 block alias 需要接收文件环境，而非外层 shell 前缀。
# When：通过 Git Bash 调用 bash/cmd/powershell block。
# Then：每个 runner 内的 NAME 都来自同一 env 文件。
# 防回归：防止跨 shell block 使用错误环境语法或未注入变量。
@pytest.mark.parametrize("runner,body", [("bash", 'printf "%s" "$NAME"'), ("cmd", "@echo off\necho %NAME%"), ("powershell", "Write-Output $env:NAME")])
def test_file_environment_in_block_runners(runner, body, tmp_path):
    (tmp_path / "foo.env").write_text("NAME=block-value\n", encoding="utf-8")
    config = tmp_path / "aliases.txt"
    config.write_text('show """' + runner + '\n' + body + '\n"""\n', encoding="utf-8")
    proc = invoke("bash", ["-e", "./foo.env", "show"], tmp_path, config)
    assert proc.returncode == 0, proc.stderr
    assert proc.stdout.strip() == "block-value"


# Given：目标脚本使用非零退出码，调用方要求透传该状态。
# When：带 env 文件调用目标脚本。
# Then：入口返回目标的退出码。
# 防回归：防止加载文件后错误地返回最后一条环境赋值的状态。
@pytest.mark.parametrize("entry", ["bash", "w.bat", "powershell"])
def test_env_file_preserves_target_exit_status(entry, tmp_path):
    (tmp_path / "foo.env").write_text("NAME=ok\n", encoding="utf-8")
    (tmp_path / "exit.py").write_text("raise SystemExit(7)\n", encoding="utf-8")
    proc = invoke(entry, ["-e", "./foo.env", sys.executable, "./exit.py"], tmp_path)
    assert proc.returncode == 7, proc.stderr
