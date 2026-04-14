"""Config loading and multi-source merging."""

import os
from pathlib import Path
from typing import List, Tuple, Optional, Dict, Any
from .parser import parse_file
from .cache import CacheManager
from .errors import ConfigParseError, DuplicateAliasError


class AliasEntry:
    """Represents a parsed alias entry."""

    def __init__(self, name: str, template: str, config_path: str,
                 source_name: str, line_no: int):
        self.name = name
        self.template = template
        self.config_path = config_path
        self.source_name = source_name
        self.line_no = line_no


def get_default_config_paths() -> Dict[str, str]:
    """
    Get default config file paths with priority.
    Returns dict of source_name -> config_path
    """
    home_override = os.environ.get('WSHA_OVERRIDE_HOME') or os.environ.get('HOME')
    if home_override:
        home = Path(home_override)
    else:
        home = Path.home()

    app_home = os.environ.get('APP_HOME', '')
    configs = {}

    # Built-in: APP_HOME/config/wsh-alias.txt
    if app_home:
        builtin_path = Path(app_home) / "config" / "wsh-alias.txt"
        if builtin_path.exists():
            configs['builtin'] = str(builtin_path)

    # User-level: $HOME/.config/wsh-alias.txt
    user_path = home / ".config" / "wsh-alias.txt"
    if user_path.exists():
        configs['user'] = str(user_path)

    # Project-level: $PWD/.config/wsh-alias.txt
    local_path = Path.cwd() / ".config" / "wsh-alias.txt"
    if local_path.exists():
        configs['project'] = str(local_path)

    return configs


def load_config(
    mode: str = "multi",
    config_path: Optional[str] = None,
    use_cache: bool = True
) -> Tuple[List[AliasEntry], List[ConfigParseError], Dict[str, str]]:
    """
    Load configuration with multi-source merging.

    Args:
        mode: "multi" for default merging, "single" for single file
        config_path: Explicit config file path (overrides defaults)
        use_cache: Whether to use cache

    Returns:
        (aliases, errors, sources)
            - aliases: List of AliasEntry objects
            - errors: List of ConfigParseError objects
            - sources: Dict of source_name -> config_path
    """
    cache_mgr = CacheManager()
    sources = {}

    # Honor WSHA_CONFIG_FILE env var for single-file mode used by tests
    env_config_file = os.environ.get('WSHA_CONFIG_FILE')
    if env_config_file and mode == "multi" and config_path is None:
        mode = "single"
        config_path = env_config_file

    # Determine config paths based on mode
    if mode == "single" and config_path:
        sources['custom'] = config_path
        config_paths = [config_path]
        fail_on_duplicate = True
    else:
        default_configs = get_default_config_paths()
        sources = default_configs.copy()
        config_paths = list(default_configs.values())
        fail_on_duplicate = False

    if not config_paths:
        return [], [], sources

    # Try loading from cache first
    if use_cache:
        cached_aliases, cache_key = cache_mgr.load(mode, config_paths)
        if cached_aliases is not None:
            # Reconstruct AliasEntry objects from cached data
            aliases = []
            for item in cached_aliases:
                aliases.append(AliasEntry(
                    name=item['name'],
                    template=item['template'],
                    config_path=item['config_path'],
                    source_name=item['source_name'],
                    line_no=item['line_no']
                ))
            return aliases, [], sources

    # Parse all config files
    all_aliases = {}  # name -> AliasEntry (for merging)
    all_errors = []
    seen_in_file = {}  # (config_path, name) -> line_no (for duplicate detection)

    for source_name, path in sources.items():
        aliases, parse_errors = parse_file(path)
        all_errors.extend(parse_errors)

        for name, template, line_no in aliases:
            if fail_on_duplicate:
                key = (path, name)
                if key in seen_in_file:
                    all_errors.append(DuplicateAliasError(
                        name, path, line_no
                    ))
                    continue
                seen_in_file[key] = line_no

            # Merge: higher priority overrides lower
            all_aliases[name] = AliasEntry(
                name=name,
                template=template,
                config_path=path,
                source_name=source_name,
                line_no=line_no
            )

    # Convert to list preserving order
    alias_list = list(all_aliases.values())

    # Save to cache (even if there are errors, cache valid entries)
    if use_cache and all_errors:
        # Don't cache if there are parse errors
        pass
    elif use_cache:
        cache_data = [
            {
                'name': a.name,
                'template': a.template,
                'config_path': a.config_path,
                'source_name': a.source_name,
                'line_no': a.line_no
            }
            for a in alias_list
        ]
        cache_mgr.save(mode, config_paths, cache_data, cache_key)

    return alias_list, all_errors, sources
