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
    "user": "[用户级]",
    "project": "[项目级]",
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

    for config_path in group_order:
        entries = grouped[config_path]
        if not entries:
            continue

        source_name = entries[0].source_name
        display_path = _resolve_display_path(source_name, config_path)
        dir_path, file_name = _split_display_path(config_path, display_path)

        # 先给出目录上下文，再强调具体文件名，方便按文件浏览配置来源。
        title = click.style(get_source_label(source_name), fg="yellow", bold=True)
        click.echo(f"{title} {dir_path}", color=True)
        click.echo(f"  {click.style(file_name, fg='yellow', bold=True)}", color=True)
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


def find_aliases(aliases: List[AliasEntry], pattern: str) -> List[AliasEntry]:
    """Find aliases using glob-style matching against names and templates."""
    import fnmatch

    return [
        entry
        for entry in aliases
        if fnmatch.fnmatch(entry.name, pattern)
        or fnmatch.fnmatch(entry.template, pattern)
    ]


@click.command(context_settings=dict(help_option_names=["-h", "--help"]))
@click.argument("alias_input", required=False)
@click.argument("args", nargs=-1, type=click.UNPROCESSED)
@click.option(
    "--list", "-l", "do_list", is_flag=True, help="List all aliases in table format"
)
@click.option(
    "--list-view", "do_list_view", is_flag=True, help="List all aliases in table format"
)
@click.option(
    "--find", "-f", "find_pattern", default=None, help="Search aliases by pattern"
)
@click.option("--cache-clear", is_flag=True, help="Clear the config cache")
def main(
    alias_input: Optional[str],
    args: Tuple[str, ...],
    do_list: bool,
    do_list_view: bool,
    find_pattern: Optional[str],
    cache_clear: bool,
) -> None:
    """wsha - alias command launcher (Python implementation)."""
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

    entry_name = os.environ.get("WSHA_ENTRY", "wsha")
    print_alias_hit(entry_name, input_text, final_cmd)

    exit_code = invoke_cmd(final_cmd)
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

    result = sp.run(["bash", wsha_sh] + sys.argv[1:], capture_output=False)
    return result.returncode


def _normalize_argv() -> None:
    """Normalize shell-style shorthand flags before Click parses argv."""
    sys.argv = ["--list-view" if arg == "-lv" else arg for arg in sys.argv]


def run_with_fallback() -> None:
    """CLI entry point with shell fallback for startup failures."""
    try:
        _normalize_argv()
        main()
    except (ImportError, FileNotFoundError, RuntimeError):
        raise SystemExit(fallback_to_shell())


if __name__ == "__main__":
    run_with_fallback()
