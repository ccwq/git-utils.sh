"""CLI entry point for wsha - alias command launcher."""

import subprocess
from typing import Tuple

import click

from .config import load_config, AliasEntry
from .expand import expand_template, invoke_cmd
from .matching import get_tokens
from .matcher import AliasMatcher


@click.command()
@click.argument('alias_input', required=False)
@click.argument('args', nargs=-1, type=click.UNPROCESSED)
@click.option('--help', '-h', is_flag=True, help='Show help')
def main(alias_input: str, args: Tuple[str, ...], help: bool) -> None:
    """wsha - alias command launcher (Python implementation)

    Args:
        alias_input: The alias name or command to expand
        args: Additional arguments to pass to the command
        help: Show help flag
    """
    if help or not alias_input:
        click.echo("wsha - alias command launcher")
        click.echo("Usage: w <alias> [args...]")
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
