"""CLI entry point for wsha - alias command launcher."""

import os
import subprocess as sp
import sys
from collections import defaultdict
from typing import Dict, List, Optional, Tuple

import click

from .cache import CacheManager
from .config import AliasEntry, ensure_user_config, get_app_env, load_config
from .errors import ConfigParseError
from .expand import expand_template, invoke_cmd, print_alias_hit
from .matcher import AliasMatcher
from .matching import get_tokens

SOURCE_LABEL_MAP = {
    "custom": "[自定义]",
    "builtin": "[内置]",
    "user": "[用户]",
    "project": "[项目]",
}


def to_display_path(path: str) -> str:
    """Convert Windows paths to Unix/Git Bash format for display."""
    try:
        result = sp.run(["cygpath", "-u", path], capture_output=True, text=True)
        if result.returncode == 0:
            return result.stdout.strip()
    except FileNotFoundError:
        pass

    return path.replace("\\", "/")


def get_source_label(source_name: str) -> str:
    """Map internal source names to user-facing labels."""
    return SOURCE_LABEL_MAP.get(source_name, f"[{source_name}]")


def _resolve_display_path(source_name: str, source_path: str) -> str:
    """Resolve the path shown in list output."""
    if source_name == "custom" and os.environ.get("WSHA_CONFIG_FILE_DISPLAY"):
        return os.environ["WSHA_CONFIG_FILE_DISPLAY"]
    return to_display_path(source_path)


def _split_display_path(source_path: str, display_path: str) -> Tuple[str, str]:
    """Split a path into directory context and filename for list rendering."""
    if not display_path:
        return "", ""

    normalized = display_path.rstrip("/") or display_path

    # 目录型配置先显示目录上下文，再从目录中挑出实际文件名。
    if source_path and os.path.isdir(source_path):
        try:
            candidates = sorted(
                name
                for name in os.listdir(source_path)
                if name.endswith(".txt") and not name.startswith("_")
            )
        except OSError:
            candidates = []
        if candidates:
            return normalized, candidates[0]
        return normalized, os.path.basename(normalized)

    parent_dir = os.path.dirname(normalized)
    file_name = os.path.basename(normalized)
    if parent_dir in ("", "."):
        return normalized, file_name
    return parent_dir, file_name


def print_list(aliases: List[AliasEntry], sources: Dict[str, str]) -> None:
    """Print aliases grouped by config file with colored table output."""
    # Show environment variables
    app_env = get_app_env()
    click.echo("# 环境变量:")
    for key in ["APP_HOME", "APP_SH", "APP_CONFIG"]:
        val = app_env.get(key, "")
        if val:
            display_val = to_display_path(val)
            click.echo(f"# {key}={display_val}")
    click.echo("")

    grouped: Dict[str, List[AliasEntry]] = defaultdict(list)
    group_order: List[str] = []
    for alias in aliases:
        group_key = os.path.normpath(alias.config_path or "")
        if group_key not in grouped:
            group_order.append(group_key)
        grouped[group_key].append(alias)

    if not group_order:
        click.echo(click.style("[wsha] no alias found.", fg="bright_black"))
        return

    for index, config_path in enumerate(group_order):
        entries = grouped[config_path]
        if not entries:
            continue

        source_name = entries[0].source_name
        display_path = _resolve_display_path(source_name, config_path)
        title = click.style(get_source_label(source_name), fg="yellow", bold=True)
        click.echo(f"{title} {display_path}", color=True)
        click.echo("")

        # 按当前文件组计算列宽，保持别名列和命令列真正对齐。
        max_alias_len = max([len("别名")] + [len(entry.name) for entry in entries])
        max_command_len = max(
            [len("命令")] + [len(entry.template) for entry in entries]
        )

        header_name = click.style(f"{'别名':<{max_alias_len}}", fg="cyan", bold=True)
        header_template = click.style(
            f"{'命令':<{max_command_len}}", fg="cyan", bold=True
        )
        separator_name = click.style(f"{'-' * max_alias_len}", fg="bright_black")
        separator_template = click.style(f"{'-' * max_command_len}", fg="bright_black")

        click.echo(f"{header_name}  {header_template}", color=True)
        click.echo(f"{separator_name}  {separator_template}", color=True)

        for entry in entries:
            alias_cell = f"{entry.name:<{max_alias_len}}"
            command_cell = f"{entry.template:<{max_command_len}}"
            alias_name = click.style(alias_cell, fg="green", bold=True)
            click.echo(f"{alias_name}  {command_cell}", color=True)

        click.echo("")
        if index < len(group_order) - 1:
            click.echo("============")


def find_aliases(aliases: List[AliasEntry], pattern: str) -> List[AliasEntry]:
    """Find aliases using glob-style matching against names and templates."""
    import fnmatch

    return [
        entry
        for entry in aliases
        if fnmatch.fnmatch(entry.name, pattern)
        or fnmatch.fnmatch(entry.template, pattern)
    ]


def _parse_cli_request(
    argv: Tuple[str, ...],
) -> Tuple[Optional[str], Tuple[str, ...], bool, bool, Optional[str], bool]:
    """Parse top-level CLI controls while preserving dash-prefixed commands."""
    alias_input: Optional[str] = None
    args: Tuple[str, ...] = ()
    do_list = False
    do_list_view = False
    find_pattern: Optional[str] = None
    cache_clear = False

    if not argv:
        return alias_input, args, do_list, do_list_view, find_pattern, cache_clear

    first = argv[0]
    rest = tuple(argv[1:])

    # 只在首个 token 命中管理指令时拦截，其余内容都按原始命令透传。
    if first in ("--list", "-l"):
        do_list = True
    elif first == "--list-view":
        do_list_view = True
    elif first in ("--find", "-f"):
        if not rest:
            raise click.UsageError("Option '--find' requires an argument.")
        find_pattern = rest[0]
        if len(rest) > 1:
            extra = " ".join(rest[1:])
            raise click.UsageError(f"Got unexpected extra arguments ({extra})")
    elif first.startswith("--find="):
        find_pattern = first.split("=", 1)[1]
    elif first == "--cache-clear":
        cache_clear = True
        if rest:
            extra = " ".join(rest)
            raise click.UsageError(f"Got unexpected extra arguments ({extra})")
    else:
        alias_input = first
        args = rest

    return alias_input, args, do_list, do_list_view, find_pattern, cache_clear


@click.command(
    context_settings=dict(
        help_option_names=["-h", "--help"],
        ignore_unknown_options=True,
        allow_extra_args=True,
    )
)
@click.argument("argv", nargs=-1, type=click.UNPROCESSED)
def main(argv: Tuple[str, ...]) -> None:
    """wsha - alias command launcher (Python implementation)."""
    (
        alias_input,
        args,
        do_list,
        do_list_view,
        find_pattern,
        cache_clear,
    ) = _parse_cli_request(argv)

    # 确保用户配置存在（首次运行时自动创建）
    # ensure_user_config()

    if cache_clear:
        CacheManager().clear()
        click.echo("Cache cleared.")
        return

    if do_list or do_list_view or find_pattern is not None or alias_input:
        aliases, errors, sources = load_config()
        if errors:
            for error in errors:
                click.echo(str(error), err=True)
            raise SystemExit(1)
    else:
        aliases, sources = [], {}

    if do_list or do_list_view:
        print_list(aliases, sources)
        return

    if find_pattern is not None:
        matched = find_aliases(aliases, find_pattern)
        if not matched:
            click.echo(f"[wsha] no alias matching '{find_pattern}'")
            return

        click.echo(f"{'别名':<18} 命令")
        for entry in matched:
            click.echo(f"  {entry.name:<16} {entry.template}")
        return

    if not alias_input:
        click.echo("wsha - alias command launcher")
        click.echo("Usage: w <alias> [args...]  |  w --list  |  w --list-view")
        return

    input_text = alias_input
    if args:
        input_text = f"{alias_input} {' '.join(args)}"

    matcher = AliasMatcher()
    for entry in aliases:
        matcher.add_alias(entry)

    input_tokens = get_tokens(input_text)
    if not input_tokens:
        result = sp.run(input_text, shell=True)
        raise SystemExit(result.returncode)

    match_result = matcher.find_best_match(input_tokens)
    if match_result is None:
        result = sp.run(input_text, shell=True)
        raise SystemExit(result.returncode)

    _matched_alias, template, captures, rest_capture, args_start = match_result

    runtime_args: List[str] = []
    if args_start < len(input_tokens):
        runtime_args = list(input_tokens[args_start:])

    final_cmd, _ = expand_template(template, captures, rest_capture, runtime_args)

    entry_name = _get_entry_name()
    print_alias_hit(entry_name, input_text, final_cmd)

    previous_entry = os.environ.get("WSHA_ENTRY")
    os.environ["WSHA_ENTRY"] = entry_name
    try:
        exit_code = invoke_cmd(final_cmd)
    finally:
        if previous_entry is None:
            os.environ.pop("WSHA_ENTRY", None)
        else:
            os.environ["WSHA_ENTRY"] = previous_entry
    raise SystemExit(exit_code)


def fallback_to_shell() -> int:
    """Fall back to the shell implementation when Python cannot start."""
    pkg_dir = os.path.dirname(os.path.abspath(__file__))
    py_dir = os.path.dirname(pkg_dir)
    project_dir = os.path.dirname(py_dir)
    wsha_sh = os.path.join(project_dir, "sh", "wsha.sh")

    if not os.path.exists(wsha_sh):
        click.echo(f"[wsha] fallback failed: wsha.sh not found at {wsha_sh}", err=True)
        return 1

    fallback_env = os.environ.copy()
    fallback_env.setdefault("WSHA_ENTRY", _get_entry_name())
    result = sp.run(
        ["bash", wsha_sh] + sys.argv[1:],
        capture_output=False,
        env=fallback_env,
    )
    return result.returncode


def _normalize_argv() -> None:
    """Normalize shell-style shorthand flags before Click parses argv."""
    sys.argv = ["--list-view" if arg == "-lv" else arg for arg in sys.argv]


def _get_entry_name() -> str:
    """Infer whether the current executable is `w` or `wsha`."""
    if os.environ.get("WSHA_ENTRY"):
        return os.environ["WSHA_ENTRY"]

    argv0 = os.path.basename(sys.argv[0] or "")
    stem, _ext = os.path.splitext(argv0)
    stem = stem.lower()
    if stem in {"w", "wsha"}:
        return stem
    return "wsha"


def run_with_fallback() -> None:
    """CLI entry point with shell fallback for startup failures."""
    try:
        _normalize_argv()
        main()
    except (ImportError, FileNotFoundError, RuntimeError):
        raise SystemExit(fallback_to_shell())


if __name__ == "__main__":
    run_with_fallback()
