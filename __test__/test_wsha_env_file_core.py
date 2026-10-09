"""Tests for dotenv parsing and repeated env CLI options."""

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
CORE_PARENT = ROOT / "sh" / "core"


def load_wsha_core():
    core_parent = str(CORE_PARENT)
    if core_parent not in sys.path:
        sys.path.insert(0, core_parent)
    import wsha_core
    return wsha_core


# Given：dotenv 文件包含 BOM、注释、export、引号和重复键。
# When：调用 core 的 dotenv 解析函数。
# Then：应得到按文件顺序解析的键值，重复键保留为后续覆盖流。
# 防回归：防止 BOM 进入键名，或解析器执行 shell 语法。
def test_parse_env_file_supports_utf8_dotenv_subset(tmp_path):
    mod = load_wsha_core()
    env_file = tmp_path / "foo.env"
    env_file.write_text("\ufeff# comment\nexport NAME=first\nMESSAGE=\"hello world\"\nNAME=last\n", encoding="utf-8")

    assert mod.parse_env_file("./foo.env", str(tmp_path)) == [
        ("NAME", "first"),
        ("MESSAGE", "hello world"),
        ("NAME", "last"),
    ]


# Given：命令行包含两个独立的 env 文件和一个显式赋值。
# When：调用 parse_cli_args。
# Then：文件与赋值应按出现顺序合并，alias 和运行参数保持原样。
# 防回归：防止重复 -e 被 PowerShell 或 core parser 吞掉，或文件参数继续读取 alias。
def test_parse_cli_args_keeps_repeated_env_sources_in_order(tmp_path):
    mod = load_wsha_core()
    (tmp_path / "base.env").write_text("BASE=1\n", encoding="utf-8")
    (tmp_path / "local.env").write_text("LOCAL=2\n", encoding="utf-8")
    old_cwd = Path.cwd()
    try:
        import os
        os.chdir(tmp_path)
        result = mod.parse_cli_args(["-e", "./base.env", "-e", "./local.env", "-e", "NAME=cli", "echo", "ok"])
    finally:
        os.chdir(old_cwd)

    assert result.valid is True
    assert result.alias == "echo"
    assert result.args == ["ok"]
    assert result.env_assignments == [("BASE", "1"), ("LOCAL", "2"), ("NAME", "cli")]


# Given：dotenv 文件包含未闭合引号。
# When：解析该文件。
# Then：应抛出带文件和行号的环境解析错误。
# 防回归：防止坏配置被静默执行目标命令。
def test_parse_env_file_reports_invalid_line(tmp_path):
    mod = load_wsha_core()
    (tmp_path / "bad.env").write_text("BROKEN=\"value\n", encoding="utf-8")

    try:
        mod.parse_env_file("./bad.env", str(tmp_path))
    except mod.EnvResolutionError as exc:
        assert "bad.env:1" in str(exc)
    else:
        raise AssertionError("expected EnvResolutionError")


# Given：文件赋值连续出现，值含空白、等号、井号及不同引号。
# When：读取文件并按顺序解析变量。
# Then：保留引号内空白和特殊字符，后值可引用前值且不修改父环境。
# 防回归：防止值被按 shell 分词，或文件内重复键提前合并而丢失引用时机。
def test_env_file_preserves_values_and_ordered_references(tmp_path):
    mod = load_wsha_core()
    (tmp_path / "values.env").write_text(
        "  # comment\n\nexport KEY = first\n"
        "BEFORE=$KEY\nKEY=last\nAFTER='${KEY}'\n"
        "SPACES=\"  hello world  \"\nEMPTY=\nHASH=value # literal\nEQUAL=a=b=c\n",
        encoding="utf-8",
    )
    parent = {"KEY": "parent"}
    assignments = mod.parse_env_file("./values.env", str(tmp_path))
    _, env = mod.resolve_env_assignments(assignments, parent, "bash", str(tmp_path))
    assert env["BEFORE"] == "first"
    assert env["AFTER"] == "last"
    assert env["SPACES"] == "  hello world  "
    assert env["EMPTY"] == ""
    assert env["HASH"] == "value # literal"
    assert env["EQUAL"] == "a=b=c"
    assert parent == {"KEY": "parent"}


# Given：用户混用连续赋值、env 文件与长参数赋值。
# When：解析完整 CLI 参数，包括路径型命令和目标参数中的 -e。
# Then：仅在命令前读取 env 选项，命令后的参数原样保留。
# 防回归：防止 env 文件吞掉路径型命令或目标工具自己的 -e。
def test_env_groups_keep_path_command_and_target_options(tmp_path, monkeypatch):
    mod = load_wsha_core()
    (tmp_path / "base.env").write_text("VALUE=file\n", encoding="utf-8")
    monkeypatch.chdir(tmp_path)
    result = mod.parse_cli_args([
        "-e", "VALUE=first", "OTHER=second", "--env", "./base.env",
        "--env=VALUE=last", "./scripts/start.sh", "-e", "target.env",
    ])
    assert result.valid
    assert result.env_assignments == [("VALUE", "first"), ("OTHER", "second"), ("VALUE", "file"), ("VALUE", "last")]
    assert result.alias == "./scripts/start.sh"
    assert result.args == ["-e", "target.env"]


# Given：文件的编码与换行可能来自 Windows 编辑器。
# When：解析 BOM、CRLF 和中文值。
# Then：变量名和值不受 BOM 或 CRLF 污染。
# 防回归：防止 Windows 文件读取出现不可见字符和错误变量名。
def test_env_file_supports_bom_crlf_and_unicode(tmp_path):
    mod = load_wsha_core()
    (tmp_path / "windows.env").write_bytes(b"\xef\xbb\xbf" + "NAME=中文\r\nEMPTY=\r\n".encode("utf-8"))
    assert mod.parse_env_file("./windows.env", str(tmp_path)) == [("NAME", "中文"), ("EMPTY", "")]


# Given：文件为空或仅有注释，读取过程中仍需明确命令边界。
# When：解析空文件、重复空文件或未提供命令的请求。
# Then：空文件是合法来源，但缺少目标命令必须报错。
# 防回归：防止以变量数量而不是选项存在性判断缺命令。
def test_empty_env_files_are_valid_but_require_command(tmp_path, monkeypatch):
    mod = load_wsha_core()
    (tmp_path / "empty.env").write_text("# only comments\n", encoding="utf-8")
    monkeypatch.chdir(tmp_path)
    result = mod.parse_cli_args(["-e", "./empty.env", "-e", "./empty.env", "echo", "ok"])
    assert result.valid
    assert result.env_assignments == []
    assert result.alias == "echo"
    assert not mod.parse_cli_args(["-e", "./empty.env"]).valid


# Given：同名环境文件存在于不同工作目录，文件内容也可能在调用间改变。
# When：分别读取目录中的文件，并在修改后重新读取。
# Then：使用调用目录和当前内容，不按 alias 目录定位或读取旧缓存。
# 防回归：防止 env 文件被 alias 配置缓存冻结。
def test_env_file_uses_cwd_and_reads_fresh_content(tmp_path):
    mod = load_wsha_core()
    first = tmp_path / "first"
    second = tmp_path / "second"
    first.mkdir()
    second.mkdir()
    (first / "foo.env").write_text("KEY=first\n", encoding="utf-8")
    (second / "foo.env").write_text("KEY=second\n", encoding="utf-8")
    assert mod.parse_env_file("./foo.env", str(first)) == [("KEY", "first")]
    assert mod.parse_env_file("./foo.env", str(second)) == [("KEY", "second")]
    (first / "foo.env").write_text("KEY=changed\n", encoding="utf-8")
    assert mod.parse_env_file("./foo.env", str(first)) == [("KEY", "changed")]


# Given：非法 env 行可能包含错误键、缺失等号、未闭合引号或 shell 表达式。
# When：逐一读取不支持的配置。
# Then：在执行前报错，提供行号但不回显原始秘密值。
# 防回归：防止坏配置被静默忽略或被作为 shell 执行。
def test_env_file_rejects_invalid_syntax_without_echoing_values(tmp_path):
    mod = load_wsha_core()
    import pytest
    cases = [
        "NOT_ASSIGNMENT", "1KEY=secret", "BAD-KEY=secret", "export BROKEN",
        'KEY="secret', "KEY='secret", 'KEY="one" trailing',
        'KEY="first\nsecond"', "KEY=$(echo secret)", "KEY=`echo secret`",
        "KEY=secret\x00",
    ]
    for value in cases:
        (tmp_path / "bad.env").write_text(value + "\n", encoding="utf-8")
        with pytest.raises(mod.EnvResolutionError) as exc:
            mod.parse_env_file("./bad.env", str(tmp_path))
        assert "bad.env:1" in str(exc.value)
        assert "secret" not in str(exc.value)


# Given：env 文件可能不存在、指向目录或不是 UTF-8 编码。
# When：读取无效文件来源。
# Then：抛出统一环境错误，且路径明确。
# 防回归：防止文件访问错误泄漏 traceback 或被当成普通 alias。
def test_env_file_rejects_missing_directory_and_invalid_encoding(tmp_path):
    mod = load_wsha_core()
    import pytest
    (tmp_path / "directory").mkdir()
    (tmp_path / "bad.env").write_bytes(b"KEY=\xff\n")
    for path in ["./missing.env", "./directory", "./bad.env"]:
        with pytest.raises(mod.EnvResolutionError, match="unable to read env file"):
            mod.parse_env_file(path, str(tmp_path))


# Given：文件变量引用了尚未定义的变量。
# When：按顺序展开文件赋值。
# Then：报错包含文件路径、行号和缺失变量名。
# 防回归：防止前向引用被静默替换为空，或错误失去来源定位。
def test_env_file_undefined_reference_reports_origin(tmp_path):
    mod = load_wsha_core()
    import pytest
    (tmp_path / "foo.env").write_text("OK=1\nSECRET=$NOT_DEFINED\n", encoding="utf-8")
    with pytest.raises(mod.EnvResolutionError) as exc:
        mod.resolve_env_assignments(mod.parse_env_file("./foo.env", str(tmp_path)), {}, "bash")
    assert "foo.env:2" in str(exc.value)
    assert "NOT_DEFINED" in str(exc.value)


# Given：env 文件定义逻辑路径、URI 与多种环境引用语法。
# When：为不同目标 shell 渲染环境值。
# Then：引用复用现有规则，仅适配本地路径，不改动 URI。
# 防回归：防止文件来源与 KEY=VALUE 采用不同展开链路。
def test_env_file_reuses_reference_and_path_rules(tmp_path):
    mod = load_wsha_core()
    (tmp_path / "paths.env").write_text(
        "ROOT=%HOME_VALUE%\nA=$ROOT\nB=${ROOT}\nC=$env:ROOT\nD=${env:ROOT}\n"
        "LOCAL=./workspace\nURI=https://example.com/path\n", encoding="utf-8"
    )
    assignments = mod.parse_env_file("./paths.env", str(tmp_path))
    rendered, env = mod.resolve_env_assignments(assignments, {"HOME_VALUE": "base"}, "cmd", str(tmp_path))
    assert [env[name] for name in ["ROOT", "A", "B", "C", "D"]] == ["base"] * 5
    assert dict(rendered)["LOCAL"] == r".\workspace"
    assert dict(rendered)["URI"] == "https://example.com/path"


# Given：env 选项只应接受本地文件或合法赋值。
# When：提供缺失操作数、URI 或没有路径证据的普通 alias。
# Then：请求无效，不联网读取也不把错误参数当成命令。
# 防回归：防止不明确的 env 选项启动错误命令。
def test_env_options_reject_missing_or_nonlocal_operands():
    mod = load_wsha_core()
    for argv in [["-e"], ["--env="], ["-e", "https://example.com/foo.env", "echo"], ["-e", "not-a-path", "echo"]]:
        assert not mod.parse_cli_args(argv).valid


# Given：Windows 用户传入 Git Bash 盘符路径来读取文件。
# When：将 /c/... 转成文件系统路径。
# Then：Windows Python 应收到 C:/... 对应路径，而不是当前盘下的 /c 目录。
# 防回归：防止 Linux 风格路径在原生 Windows core 中定位错误。
def test_env_file_host_path_supports_git_bash_drive(tmp_path):
    mod = load_wsha_core()
    import os
    if os.name == "nt":
        assert Path(mod.host_path_from_cli("/c/Users/test/foo.env", str(tmp_path))) == Path("C:/Users/test/foo.env")


# Given：Windows 当前环境中存在不同大小写的同名键。
# When：文件以新大小写覆盖键并引用旧大小写名称。
# Then：后面的引用必须读取到覆盖后的值。
# 防回归：防止环境字典同时保留 PATH/Path 导致覆盖失败。
def test_env_file_windows_keys_override_case_insensitively(tmp_path):
    mod = load_wsha_core()
    import os
    if os.name == "nt":
        _, env = mod.resolve_env_assignments([("Name", "new"), ("REF", "$NAME")], {"NAME": "old"}, "cmd")
        assert env["REF"] == "new"
        assert "NAME" not in env
