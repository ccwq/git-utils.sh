"""CLI entry point for wsha - alias command launcher."""

import fnmatch
import subprocess
from typing import Tuple, List, Dict, Optional

import click

from .config import load_config, AliasEntry
from .cache import CacheManager
from .expand import expand_template, invoke_cmd
from .matching import get_tokens
from .matcher import AliasMatcher


def show_list_table(aliases: List[AliasEntry], sources: Dict[str, str]) -> None:
    """以表格格式按来源分组显示别名列表。per D-24。"""
    found_any = False
    for source_name, config_path in sources.items():
        # 过滤属于该来源的条目（按 source_name 匹配）
        group = [a for a in aliases if a.source_name == source_name]
        if not group:
            continue
        found_any = True
        max_alias_len = max((len(a.name) for a in group), default=4)
        max_alias_len = max(max_alias_len, 4)  # 最小宽度 4

        # 来源标题
        click.echo(f"[{source_name}] {config_path}")
        click.echo("")
        # 表头
        click.echo(f"{'别名':<{max_alias_len}}  命令")
        click.echo(f"{'----':<{max_alias_len}}  ----")
        # 数据行
        for entry in group:
            template = entry.template if len(entry.template) <= 60 else entry.template[:57] + "..."
            click.echo(f"{entry.name:<{max_alias_len}}  {template}")
        click.echo("")
    if not found_any:
        click.echo("[wsha] no alias found.")


def show_list_view(aliases: List[AliasEntry], sources: Dict[str, str]) -> None:
    """显示完整别名元数据：名称/模板/来源配置文件/行号。per D-29。"""
    found_any = False
    for source_name, config_path in sources.items():
        group = [a for a in aliases if a.source_name == source_name]
        if not group:
            continue
        found_any = True
        click.echo(f"[{source_name}] {config_path}")
        click.echo("")
        for entry in group:
            click.echo(f"  {entry.name}")
            click.echo(f"    Template: {entry.template}")
            click.echo(f"    Source:   {entry.source_name}")
            click.echo(f"    Config:   {entry.config_path}:{entry.line_no}")
            click.echo("")
    if not found_any:
        click.echo("[wsha] no alias found.")


def find_aliases(aliases: List[AliasEntry], pattern: str) -> List[AliasEntry]:
    """使用 fnmatch glob 模式搜索别名。per D-28。不使用 regex。"""
    return [a for a in aliases if fnmatch.fnmatch(a.name, pattern)]


@click.command(context_settings=dict(help_option_names=['-h', '--help']))
@click.argument('alias_input', required=False)
@click.argument('args', nargs=-1, type=click.UNPROCESSED)
@click.option('--list', '-l', 'list_mode', is_flag=True, help='List all aliases in table format')          # CLI-01, D-24
@click.option('--list-view', '-lv', 'list_view_mode', is_flag=True, help='Show detailed alias view')       # CLI-02, D-29
@click.option('--find', '-f', 'find_pattern', default=None, metavar='PATTERN', help='Search aliases by glob pattern')  # CLI-03, D-28
@click.option('--cache-clear', is_flag=True, help='Clear config cache')                                    # CLI-04
def main(
    alias_input: str,
    args: Tuple[str, ...],
    list_mode: bool,
    list_view_mode: bool,
    find_pattern: Optional[str],
    cache_clear: bool,
) -> None:
    """wsha - alias command launcher (Python implementation)"""
    # CLI-04: --cache-clear 立即执行后退出，不加载 config
    if cache_clear:
        CacheManager().clear()
        click.echo("Cache cleared.")
        return

    # 加载配置（--list / --list-view / --find 需要 aliases 数据）
    if list_mode or list_view_mode or find_pattern is not None:
        aliases, errors, sources = load_config()
        if errors:
            for err in errors:
                click.echo(f"[wsha] config error: {err}", err=True)

        # CLI-01: --list / -l  per D-24
        if list_mode:
            show_list_table(aliases, sources)
            return

        # CLI-02: --list-view / -lv  per D-29
        if list_view_mode:
            show_list_view(aliases, sources)
            return

        # CLI-03: --find  per D-28
        if find_pattern is not None:
            matches = find_aliases(aliases, find_pattern)
            if not matches:
                click.echo(f"[wsha] no alias matching '{find_pattern}'")
            else:
                max_len = max(len(e.name) for e in matches)
                for entry in matches:
                    click.echo(f"{entry.name:<{max_len}}  {entry.template}")
            return

    # 无参数或 --help：显示帮助
    if not alias_input:
        click.echo("wsha - alias command launcher")
        click.echo("Usage: w <alias> [args...]")
        click.echo("       w --list | -l")
        click.echo("       w --list-view | -lv")
        click.echo("       w --find <pattern>")
        click.echo("       w --cache-clear")
        return

    # Build full input text
    input_text = alias_input
    if args:
        input_text = f"{alias_input} {' '.join(args)}"

    # Load config - returns (aliases, errors, sources)
    aliases, errors, sources = load_config()

    # Build matcher with all aliases
    matcher = AliasMatcher()
    for entry in aliases:
        matcher.add_alias(entry)

    # Tokenize input for matching
    input_tokens = get_tokens(input_text)
    if not input_tokens:
        # Empty input - passthrough (shouldn't normally happen)
        result = subprocess.run(input_text, shell=True)
        raise SystemExit(result.returncode)

    # Find best match
    match_result = matcher.find_best_match(input_tokens)

    if match_result is None:
        # No alias matched - passthrough to shell
        result = subprocess.run(input_text, shell=True)
        raise SystemExit(result.returncode)

    matched_alias, template, captures, rest_capture, args_start = match_result

    # Extract runtime args from remaining tokens
    runtime_args: list[str] = []
    if args_start < len(input_tokens):
        runtime_args = list(input_tokens[args_start:])

    # Expand template with captures and runtime args
    final_cmd, _ = expand_template(template, captures, rest_capture, runtime_args)

    # Execute and propagate exit code
    exit_code = invoke_cmd(final_cmd)
    raise SystemExit(exit_code)


if __name__ == '__main__':
    main()
