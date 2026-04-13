"""wsha - alias command launcher (Python implementation)."""

from .errors import (
    WshaError,
    ConfigParseError,
    DuplicateAliasError,
    CacheError,
    ConfigNotFoundError,
)
from .parser import parse_line, parse_file
from .cache import CacheManager
from .config import load_config, AliasEntry, get_default_config_paths
from .matching import get_tokens, match_token_pattern, match_double_star_remainder
from .matcher import AliasMetadata, AliasMatcher, build_alias_metadata

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
]
