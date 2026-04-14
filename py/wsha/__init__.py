"""wsha - alias command launcher (Python implementation)."""

from .errors import (
    WshaError,
    ConfigParseError,
    DuplicateAliasError,
    CacheError,
    ConfigNotFoundError,
)
from .parser import parse_line, parse_file, parse_dir
from .parser import PREFIX_NORMAL, PREFIX_SEQUENTIAL, PREFIX_OR
from .cache import CacheManager
from .config import load_config, AliasEntry, get_default_config_paths
from .matching import get_tokens, match_token_pattern, match_double_star_remainder
from .matcher import AliasMetadata, AliasMatcher, build_alias_metadata
from .expand import expand_template, invoke_cmd, is_complex_shell_command, expand_env_vars, print_alias_hit

VERSION = "0.1.0"

__all__ = [
    "VERSION",
    "WshaError",
    "ConfigParseError",
    "DuplicateAliasError",
    "CacheError",
    "ConfigNotFoundError",
    "parse_line",
    "parse_file",
    "parse_dir",
    "PREFIX_NORMAL",
    "PREFIX_SEQUENTIAL",
    "PREFIX_OR",
    "CacheManager",
    "load_config",
    "AliasEntry",
    "get_default_config_paths",
    # Phase 2: Matching engine
    "get_tokens",
    "match_token_pattern",
    "match_double_star_remainder",
    "AliasMetadata",
    "AliasMatcher",
    "build_alias_metadata",
    # Phase 3: Template expansion
    "expand_template",
    "invoke_cmd",
    "is_complex_shell_command",
    "expand_env_vars",
    "print_alias_hit",
]
