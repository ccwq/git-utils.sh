"""Config file parser for wsh-alias.txt format."""

import re
import glob
import os
from typing import Optional, Tuple, List
from .errors import ConfigParseError

# Prefix types for alias execution chains
PREFIX_NORMAL = "normal"
PREFIX_SEQUENTIAL = "sequential"  # &foo - execute in sequence, stop on error
PREFIX_OR = "or"  # |foo - execute in sequence, stop on success


def parse_line(line: str, config_path: str, line_no: int) -> Optional[Tuple[str, str, str]]:
    """
    Parse a single line from wsh-alias.txt.

    Args:
        line: The raw line content (already stripped of line ending)
        config_path: Path to the config file (for error messages)
        line_no: Line number in the file (1-based)

    Returns:
        Tuple of (alias_name, template, prefix_type) if valid, None if skip (comment/empty)
        prefix_type is one of PREFIX_NORMAL, PREFIX_SEQUENTIAL, or PREFIX_OR

    Raises:
        ConfigParseError: If the line has invalid syntax
    """
    # Strip leading/trailing whitespace but preserve internal content
    trimmed = line.strip()

    # Skip empty lines
    if not trimmed:
        return None

    # Skip comment lines
    if trimmed.startswith('#'):
        return None

    alias_name = ""
    template = ""
    prefix_type = PREFIX_NORMAL

    # Check for prefix indicators (& or |) at the start of alias name
    # & prefix: sequential execution (stop on error)
    # | prefix: or execution (stop on success)
    if trimmed.startswith('&'):
        prefix_type = PREFIX_SEQUENTIAL
        trimmed = trimmed[1:]
    elif trimmed.startswith('|'):
        prefix_type = PREFIX_OR
        trimmed = trimmed[1:]

    if trimmed.startswith('"'):
        # Quoted alias: "alias name" template content
        # Match: "..." followed by whitespace and then template
        match = re.match(r'^"([^"]+)"\s+(.+)$', trimmed)
        if not match:
            raise ConfigParseError(
                "invalid config: invalid quoted alias syntax",
                config_path,
                line_no
            )
        alias_name = match.group(1)
        template = match.group(2).strip()
    else:
        # Unquoted alias: alias_name template content
        # Split on first whitespace sequence
        parts = trimmed.split(None, 1)
        if len(parts) == 1:
            raise ConfigParseError(
                f'invalid config: alias "{parts[0]}" has no target command',
                config_path,
                line_no
            )
        alias_name = parts[0]
        template = parts[1]

    if not alias_name:
        raise ConfigParseError("invalid config: missing alias name", config_path, line_no)

    if not template:
        raise ConfigParseError(
            f'invalid config: alias "{alias_name}" has no target command',
            config_path,
            line_no
        )

    # Strip outer quotes from template if present (both ends are quotes)
    if len(template) >= 2 and template.startswith('"') and template.endswith('"'):
        template = template[1:-1]

    return (alias_name, template, prefix_type)


def parse_file(file_path: str) -> Tuple[List, List]:
    """
    Parse an entire config file.

    Args:
        file_path: Path to the config file

    Returns:
        Tuple of (aliases, errors) where:
            - aliases: list of (alias_name, template, line_no) tuples
            - errors: list of ConfigParseError instances

    Both lists preserve insertion order.
    """
    aliases = []
    errors = []

    with open(file_path, 'r', encoding='utf-8') as f:
        for line_no, line in enumerate(f, start=1):
            # Remove line endings
            line = line.rstrip('\r\n')

            try:
                result = parse_line(line, file_path, line_no)
                if result:
                    # result is (alias_name, template, prefix_type)
                    aliases.append((result[0], result[1], result[2], line_no))
            except ConfigParseError as e:
                errors.append(e)

    return aliases, errors


def parse_dir(dir_path: str) -> Tuple[List, List]:
    """
    Parse all config files in a directory using glob.

    Args:
        dir_path: Path to the config directory

    Returns:
        Tuple of (aliases, errors) where:
            - aliases: list of (alias_name, template, prefix_type, line_no, file_path) tuples
            - errors: list of ConfigParseError instances

        Files are processed in alphabetical order.
        Files starting with underscore (_) are ignored.
        Only matches *.txt files (1 level deep).
    """
    aliases = []
    errors = []

    if not os.path.isdir(dir_path):
        return aliases, errors

    # glob.glob("*.txt") matches 1 level deep
    pattern = os.path.join(dir_path, "*.txt")
    files = sorted(glob.glob(pattern))

    for file_path in files:
        # Filter out files starting with underscore
        basename = os.path.basename(file_path)
        if basename.startswith('_'):
            continue

        file_aliases, file_errors = parse_file(file_path)
        for alias_name, template, prefix_type, line_no in file_aliases:
            aliases.append((alias_name, template, prefix_type, line_no, file_path))
        errors.extend(file_errors)

    return aliases, errors
