"""Config loading and multi-source merging."""

import os
from pathlib import Path
from typing import List, Tuple, Optional, Dict, Any
from .parser import parse_dir, parse_file, PREFIX_NORMAL, PREFIX_SEQUENTIAL, PREFIX_OR
from .cache import CacheManager
from .errors import ConfigParseError, DuplicateAliasError


class AliasEntry:
    """Represents a parsed alias entry."""

    def __init__(self, name: str, template: str, config_path: str,
                 source_name: str, line_no: int, prefix_type: str = PREFIX_NORMAL):
        self.name = name
        self.template = template
        self.config_path = config_path
        self.source_name = source_name
        self.line_no = line_no
        self.prefix_type = prefix_type


def _detect_package_root() -> Optional[Path]:
    """
    Detect the package root when APP_HOME is not set.
    Used when wsha is installed via pip install -e . or pip install.
    """
    try:
        # wsha package is at py/wsha/, so parent.parent gives project root
        import wsha as wsha_pkg
        pkg_file = Path(wsha_pkg.__file__).resolve()
        # py/wsha/__init__.py -> py/wsha -> project root
        package_dir = pkg_file.parent  # py/wsha/
        project_root = package_dir.parent  # py/
        if project_root.name == 'py' and (project_root.parent / 'config').exists():
            return project_root.parent
    except (ImportError, ValueError, TypeError):
        pass
    return None


def get_app_env() -> Dict[str, str]:
    """
    Get effective APP_* environment variables.
    Returns detected or configured paths for APP_HOME, APP_SH, APP_CONFIG.
    """
    env = {}

    # APP_HOME: use env var or detect from package
    app_home = os.environ.get('APP_HOME', '')
    if not app_home:
        detected = _detect_package_root()
        if detected:
            app_home = str(detected.resolve())
    env['APP_HOME'] = app_home

    # APP_SH: sh directory relative to APP_HOME
    if app_home:
        env['APP_SH'] = str(Path(app_home) / 'sh')
    else:
        env['APP_SH'] = ''

    # APP_CONFIG: config directory relative to APP_HOME
    if app_home:
        env['APP_CONFIG'] = str(Path(app_home) / 'config')
    else:
        env['APP_CONFIG'] = ''

    return env


def get_default_config_paths() -> Dict[str, str]:
    """
    Get default config directory paths with priority.
    Returns dict of source_name -> config_directory_path
    """
    home_override = os.environ.get('WSHA_OVERRIDE_HOME') or os.environ.get('HOME')
    if home_override:
        home = Path(home_override)
    else:
        home = Path.home()

    app_home = os.environ.get('APP_HOME', '')
    configs = {}

    # Built-in: APP_HOME/config/wsh-alias/ (glob directory)
    # If APP_HOME not set, auto-detect from package location
    if app_home:
        builtin_dir = Path(app_home) / "config" / "wsh-alias"
        if builtin_dir.is_dir():
            configs['builtin'] = str(builtin_dir)
    else:
        # Auto-detect: find project root from package location
        detected_root = _detect_package_root()
        if detected_root:
            builtin_dir = detected_root / "config" / "wsh-alias"
            if builtin_dir.is_dir():
                configs['builtin'] = str(builtin_dir)

    # User-level: $HOME/.config/wsh-alias/ (glob directory)
    user_dir = home / ".config" / "wsh-alias"
    if user_dir.is_dir():
        configs['user'] = str(user_dir)

    # Project-level: $PWD/.config/wsh-alias/ (glob directory)
    local_dir = Path.cwd() / ".config" / "wsh-alias"
    if local_dir.is_dir():
        configs['project'] = str(local_dir)

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

    # Parse all config files/directories
    all_aliases = {}  # name -> AliasEntry (for merging, first wins)
    all_errors = []
    seen_in_file = {}  # (config_path, name) -> line_no (for duplicate detection)

    for source_name, path in sources.items():
        # Use parse_dir for directories, parse_file for single files
        if os.path.isdir(path):
            dir_aliases, parse_errors = parse_dir(path)
            all_errors.extend(parse_errors)

            for name, template, prefix_type, line_no in dir_aliases:
                if fail_on_duplicate:
                    key = (path, name)
                    if key in seen_in_file:
                        all_errors.append(DuplicateAliasError(
                            name, path, line_no
                        ))
                        continue
                    seen_in_file[key] = line_no

                # Merge: higher priority overrides lower
                # First occurrence wins (duplicate detection as per plan)
                if name not in all_aliases:
                    all_aliases[name] = AliasEntry(
                        name=name,
                        template=template,
                        config_path=path,
                        source_name=source_name,
                        line_no=line_no,
                        prefix_type=prefix_type
                    )
        elif os.path.isfile(path):
            file_aliases, parse_errors = parse_file(path)
            all_errors.extend(parse_errors)

            for name, template, prefix_type, line_no in file_aliases:
                if fail_on_duplicate:
                    key = (path, name)
                    if key in seen_in_file:
                        all_errors.append(DuplicateAliasError(
                            name, path, line_no
                        ))
                        continue
                    seen_in_file[key] = line_no

                # Merge: higher priority overrides lower
                if name not in all_aliases:
                    all_aliases[name] = AliasEntry(
                        name=name,
                        template=template,
                        config_path=path,
                        source_name=source_name,
                        line_no=line_no,
                        prefix_type=prefix_type
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
                'line_no': a.line_no,
                'prefix_type': a.prefix_type
            }
            for a in alias_list
        ]
        cache_mgr.save(mode, config_paths, cache_data, cache_key)

    return alias_list, all_errors, sources


def detect_duplicates(aliases: List[AliasEntry]) -> List[DuplicateAliasError]:
    """
    Detect aliases with the same name but different content.

    Args:
        aliases: List of AliasEntry objects to check

    Returns:
        List of DuplicateAliasError for aliases with conflicting definitions
    """
    # Group by name
    by_name: Dict[str, List[AliasEntry]] = {}
    for entry in aliases:
        if entry.name not in by_name:
            by_name[entry.name] = []
        by_name[entry.name].append(entry)

    # Find duplicates with different content
    errors = []
    for name, entries in by_name.items():
        if len(entries) > 1:
            # Check if templates differ
            templates = set(e.template for e in entries)
            if len(templates) > 1:
                # Has same name but different content - report first one
                first = entries[0]
                errors.append(DuplicateAliasError(
                    name, first.config_path, first.line_no
                ))

    return errors
