#!/usr/bin/env python3
"""CLI entry point for wsha."""

import sys
import click

# Add parent directory to path for local development
sys.path.insert(0, str(__file__).rsplit('/', 1)[0])

from wsha import load_config, CacheManager, VERSION


@click.group()
@click.version_option(version=VERSION)
def main():
    """wsha - alias command launcher."""
    pass


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
