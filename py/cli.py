#!/usr/bin/env python3
"""CLI entry point for wsha."""

import sys
import click

# Add parent directory to path for local development
sys.path.insert(0, str(__file__).rsplit('/', 1)[0])

from wsha import load_config, CacheManager, VERSION
from wsha.matcher import AliasMatcher, expand_alias


@click.group()
@click.version_option(version=VERSION)
def main():
    """wsha - alias command launcher."""
    pass


@main.command()
@click.argument('alias_name', required=False)
@click.argument('args', nargs=-1, required=False)
@click.option('--cache-clear', is_flag=True, help='Clear the config cache')
def expand(alias_name, args, cache_clear):
    """Expand an alias with optional arguments.

    This is Phase 2 - we verify matching works.
    Template substitution comes in Phase 3.
    """
    if cache_clear:
        cache_mgr = CacheManager()
        cache_mgr.clear()
        click.echo("Cache cleared.")
        return

    if not alias_name:
        click.echo("Usage: wsha expand <alias> [args...]")
        return

    # Load config and build matcher
    aliases, errors, sources = load_config()
    if errors:
        for err in errors:
            click.echo(f"Config error: {err}", err=True)

    matcher = AliasMatcher()
    for alias in aliases:
        matcher.add_alias(alias)

    # Combine alias_name and args into input_text
    if args:
        input_text = alias_name + " " + " ".join(args)
    else:
        input_text = alias_name

    # Try to expand the alias
    result = expand_alias(matcher, input_text)
    if result is not None:
        matched_alias, template, captures, rest_capture, args_start = result
        if captures or rest_capture:
            click.echo(f"Would expand: {matched_alias} -> {template} (captures: {captures}, rest: {rest_capture})")
        else:
            click.echo(f"Would expand: {matched_alias} -> {template}")
    else:
        # MATCH-07: passthrough for unknown aliases
        click.echo(f"Would passthrough: {input_text}")


@main.command()
@click.option('--cache-clear', is_flag=True, help='Clear the config cache')
def list_aliases(cache_clear):
    """List all aliases."""
    if cache_clear:
        cache_mgr = CacheManager()
        cache_mgr.clear()
        click.echo("Cache cleared.")
        return

    aliases, errors, sources = load_config()

    if errors:
        for err in errors:
            click.echo(f"Error: {err}", err=True)

    if not aliases:
        click.echo("No aliases found.")
        return

    # Group by source
    by_source = {}
    for alias in aliases:
        if alias.source_name not in by_source:
            by_source[alias.source_name] = []
        by_source[alias.source_name].append(alias)

    for source_name, source_aliases in by_source.items():
        source_path = sources.get(source_name, 'unknown')
        click.echo(f"[{source_name}] {source_path}")
        click.echo("")
        for alias in source_aliases:
            click.echo(f"  {alias.name:20} {alias.template}")
        click.echo("")


if __name__ == "__main__":
    main()
