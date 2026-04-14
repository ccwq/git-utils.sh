"""CLI entry point for wsha - alias command launcher."""

import os
import subprocess as sp
import sys
from typing import Dict, List, Optional, Tuple

import click

from .cache import CacheManager
from .config import AliasEntry, load_config, get_app_env, ensure_user_config
from .errors import ConfigParseError
from .expand import expand_template, invoke_cmd, print_alias_hit
from .matching import get_tokens
from .matcher import AliasMatcher


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


def print_list(aliases: List[AliasEntry], sources: Dict[str, str]) -> None:
    """Print aliases grouped by source using shell-compatible table output."""
    # Show environment variables
    app_env = get_app_env()
    click.echo("# 环境变量:")
    for key in ['APP_HOME', 'APP_SH', 'APP_CONFIG']:
        val = app_env.get(key, '')
        if val:
            display_val = to_display_path(val)
            click.echo(f"# {key}={display_val}")
    click.echo("")
    click.echo(f"{'别名':<18} 命令")

    by_source: Dict[str, List[AliasEntry]] = {}
    source_order: List[str] = []
    for alias in aliases:
        if alias.source_name not in by_source:
            by_source[alias.source_name] = []
            source_order.append(alias.source_name)
        by_source[alias.source_name].append(alias)

    for source_name in source_order:
        source_path = sources.get(source_name, "")
        display_path = _resolve_display_path(source_name, source_path)
        click.echo(f"{get_source_label(source_name)} {display_path}")

        for entry in by_source[source_name]:
            click.echo(f"  {entry.name:<16} {entry.template}")

        click.echo("")


def find_aliases(aliases: List[AliasEntry], pattern: str) -> List[AliasEntry]:
    """Find aliases using glob-style matching against names and templates."""
    import fnmatch

    return [
        entry for entry in aliases
        if fnmatch.fnmatch(entry.name, pattern) or fnmatch.fnmatch(entry.template, pattern)
    ]


@click.command(context_settings=dict(help_option_names=["-h", "--help"]))
@click.argument("alias_input", required=False)
@click.argument("args", nargs=-1, type=click.UNPROCESSED)
@click.option("--list", "-l", "do_list", is_flag=True, help="List all aliases in table format")
@click.option("--list-view", "do_list_view", is_flag=True, help="List all aliases in table format")
@click.option("--find", "-f", "find_pattern", default=None, help="Search aliases by pattern")
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
    ensure_user_config()

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
