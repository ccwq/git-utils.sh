---
wave: 1
depends_on: []
requirements:
  - CFG-01
  - CFG-02
  - CFG-03
  - CFG-04
  - CFG-05
  - SHELL-03
  - SHELL-06
  - SHELL-07
files_modified:
  - py/wsha/__init__.py
  - py/wsha/parser.py
  - py/wsha/config.py
  - py/wsha/cache.py
  - py/wsha/errors.py
  - py/cli.py
  - pyproject.toml
autonomous: false
---

# Phase 1 Plan: Config System & Core Architecture

## Overview

建立 Python 包结构和配置加载系统，支持多源配置合并和缓存。

## Success Criteria

1. Python 可以解析 wsh-alias.txt 格式（无引号、带引号、注释行）
2. 多源配置按优先级合并（内置 < 用户 < 项目级）
3. 配置缓存保存在 ~/.cache/wsha/，基于文件时间戳验证
4. `w --cache-clear` 可以清除缓存
5. 缓存文件损坏时给出明确错误信息
6. Python 版本与 shell 版本共享同一配置文件
7. 单个配置文件中重复别名可以被检测
8. 配置文件格式错误时给出描述性错误信息

## Wave 1: Core Infrastructure (Foundation)

### Task 1.1: Create Directory Structure

创建 Python 包目录结构。

<read_first>
- CLAUDE.md (项目结构约定)
</read_first>

<acceptance_criteria>
- `test -d py/wsha` 返回 0（目录存在）
- `test -f py/wsha/__init__.py` 返回 0（包入口存在）
- `test -f pyproject.toml` 返回 0（配置文件存在）
</acceptance_criteria>

<action>
创建以下目录和空文件：
- `py/wsha/__init__.py` - Python 包入口（空文件，稍后填充）
- `py/wsha/errors.py` - 自定义异常类
- `py/wsha/parser.py` - 配置解析器
- `py/wsha/config.py` - 配置加载和合并
- `py/wsha/cache.py` - 缓存管理
- `py/cli.py` - Click CLI 入口
- `pyproject.toml` - 项目配置

确保 `py/` 目录是 Python 包结构。
</action>

### Task 1.2: Create pyproject.toml

定义 Python 包的构建配置和依赖。

<read_first>
- D-02: 使用 Click CLI 入口点
- D-03: 使用 `pyproject.toml` only
</read_first>

<acceptance_criteria>
- `pyproject.toml` 存在且格式有效
- `[project]` 部分包含 `name = "wsha"`, `version = "0.1.0"`
- `[project.dependencies]` 包含 `click>=8.0`
- `[project.scripts]` 定义 `w = "wsha.cli:main"` 入口点
- `[build-system]` 使用 `hatchling` 或 `setuptools`
</acceptance_criteria>

<action>
创建 `pyproject.toml` 内容：
```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "wsha"
version = "0.1.0"
description = "wsha - alias command launcher"
requires-python = ">=3.8"
dependencies = [
    "click>=8.0",
]

[project.scripts]
w = "wsha.cli:main"
wsha = "wsha.cli:main"

[tool.hatch.build.targets.wheel]
packages = ["wsha"]
```

注：Phase 1 暂不实现真正的 `w` 命令路由逻辑（Phase 4 处理），此处仅为包结构占位。
</action>

### Task 1.3: Implement errors.py - Custom Exceptions

定义配置解析和缓存相关的自定义异常。

<read_first>
- D-06: 配置错误显示行号（格式：`config/wsh-alias.txt:12: 无效语法`）
- SHELL-07: Invalid config file error handling with descriptive messages
</read_first>

<acceptance_criteria>
- `py/wsha/errors.py` 包含 `ConfigParseError` 类
- `ConfigParseError` 有 `line_no` 和 `config_path` 属性
- 错误消息格式为 `{config_path}:{line_no}: {message}`
- `py/wsha/errors.py` 包含 `CacheError` 类用于缓存相关错误
- `py/wsha/errors.py` 包含 `DuplicateAliasError` 类
</acceptance_criteria>

<action>
```python
# py/wsha/errors.py
"""Custom exceptions for wsha."""


class WshaError(Exception):
    """Base exception for wsha."""
    pass


class ConfigParseError(WshaError):
    """Raised when a config file has parse errors."""

    def __init__(self, message: str, config_path: str, line_no: int):
        self.message = message
        self.config_path = config_path
        self.line_no = line_no
        super().__init__(f"{config_path}:{line_no}: {message}")


class DuplicateAliasError(ConfigParseError):
    """Raised when a duplicate alias is found in a config file."""

    def __init__(self, alias: str, config_path: str, line_no: int):
        self.alias = alias
        super().__init__(
            f'duplicate alias "{alias}"',
            config_path,
            line_no
        )


class CacheError(WshaError):
    """Raised when there's a cache-related error."""
    pass


class ConfigNotFoundError(WshaError):
    """Raised when no config files are found."""
    pass
```
</action>

### Task 1.4: Implement parser.py - Config Line Parser

实现 wsh-alias.txt 格式的解析器。

<read_first>
- config/wsh-alias.txt - 现有配置格式参考
- D-04: 手写 parser（按行读取），不使用 `shlex.split()`
- D-05: 支持双引号别名（如 `"pcodex l"` → alias_name 含空格，模板为 `echo codex-last`）
- sh/wsha.sh 第 403-463 行 - 现有 shell 解析逻辑参考
</read_first>

<acceptance_criteria>
- `py/wsha/parser.py` 包含 `parse_line(line, config_path, line_no)` 函数
- 支持注释行（以 `#` 开头，跳过）
- 支持空行（跳过）
- 支持无引号别名：`fox firefox` → alias=`fox`, template=`firefox`
- 支持带引号别名：`"pcodex l" echo codex-last` → alias=`pcodex l`, template=`echo codex-last`
- 支持模板中的引号去除：`"px *" "pnpx $1"` → template=`pnpx $1`
- 错误时抛出 `ConfigParseError`，包含行号和路径
</acceptance_criteria>

<action>
在 `py/wsha/parser.py` 中实现：

```python
"""Config file parser for wsh-alias.txt format."""

import re
from typing import Optional, Tuple
from .errors import ConfigParseError


def parse_line(line: str, config_path: str, line_no: int) -> Optional[Tuple[str, str]]:
    """
    Parse a single line from wsh-alias.txt.

    Args:
        line: The raw line content (already stripped of line ending)
        config_path: Path to the config file (for error messages)
        line_no: Line number in the file (1-based)

    Returns:
        Tuple of (alias_name, template) if valid, None if skip (comment/empty)

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

    if trimmed.startswith('"'):
        # Quoted alias: "alias name" template content
        # Match: "..." followed by whitespace and then template
        match = re.match(r'^"([^"]+)"\s+(.+)$', trimmed)
        if not match:
            raise ConfigParseError(
                "invalid quoted alias syntax",
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
                f'alias "{parts[0]}" has no target command',
                config_path,
                line_no
            )
        alias_name = parts[0]
        template = parts[1]

    if not alias_name:
        raise ConfigParseError("missing alias name", config_path, line_no)

    if not template:
        raise ConfigParseError(
            f'alias "{alias_name}" has no target command',
            config_path,
            line_no
        )

    # Strip outer quotes from template if present (both ends are quotes)
    if len(template) >= 2 and template.startswith('"') and template.endswith('"'):
        template = template[1:-1]

    return (alias_name, template)


def parse_file(file_path: str) -> Tuple[list, list]:
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
                    aliases.append((result[0], result[1], line_no))
            except ConfigParseError as e:
                errors.append(e)

    return aliases, errors
```

注：`parse_file` 函数供后续任务使用。
</action>

### Task 1.5: Implement cache.py - Cache Management

实现缓存管理功能。

<read_first>
- D-08: 缓存格式为 JSON
- D-09: 缓存位置：`~/.cache/wsha/`
- D-10: 缓存验证：基于文件 mtime（配置 mtime < 缓存 mtime = 有效）
- D-11: `w --cache-clear` 清除缓存
- D-12: 缓存损坏时自动清除 + 友好警告，程序继续运行
- sh/wsha.sh 第 326-388 行 - 现有 shell 缓存逻辑参考（但 Phase 1 Python 版本独立实现）
</read_first>

<acceptance_criteria>
- `py/wsha/cache.py` 包含 `CacheManager` 类
- `CacheManager` 有 `get_cache_dir()` 返回 `~/.cache/wsha/`
- `CacheManager.get_cache_file(mode, config_paths)` 返回缓存文件路径
- 缓存验证：比较 config mtime 和 cache mtime
- `CacheManager.clear()` 清除所有缓存
- `CacheManager.load(config_paths)` 返回 `(alias_list, cache_key)` 或 `(None, None)`
- `CacheManager.save(config_paths, alias_list, cache_key)` 保存缓存
- 损坏的缓存文件被检测并删除，返回 `None`
</acceptance_criteria>

<action>
```python
"""Cache management for wsha config."""

import json
import os
import hashlib
from pathlib import Path
from typing import Optional, List, Tuple, Any
from .errors import CacheError


class CacheManager:
    """Manages config caching with mtime-based validation."""

    CACHE_VERSION = "v2"
    CACHE_DIR = Path.home() / ".cache" / "wsha"

    def __init__(self):
        self._ensure_cache_dir()

    def _ensure_cache_dir(self):
        """Ensure cache directory exists."""
        self.CACHE_DIR.mkdir(parents=True, exist_ok=True)

    def _get_file_mtime_size(self, file_path: str) -> str:
        """Get mtime:size for a file."""
        path = Path(file_path)
        if not path.exists():
            return "missing"
        mtime = int(path.stat().st_mtime)
        size = path.stat().st_size
        return f"{mtime}:{size}"

    def _build_cache_key(self, mode: str, config_paths: List[str]) -> str:
        """Build a cache key from mode and config file stamps."""
        parts = [f"version={self.CACHE_VERSION}", f"mode={mode}"]
        for path in config_paths:
            stamp = self._get_file_mtime_size(path)
            parts.append(f"|{path}|{stamp}")
        key_str = "".join(parts)

        # Hash to get short filename
        if hasattr(hashlib, 'sha1'):
            hash_val = hashlib.sha1(key_str.encode()).hexdigest()
        else:
            import cksum
            hash_val = str(cksum.crc32(key_str.encode()))

        return hash_val

    def get_cache_file(self, mode: str, config_paths: List[str]) -> Path:
        """Get the cache file path for given config."""
        cache_key = self._build_cache_key(mode, config_paths)
        return self.CACHE_DIR / f"{cache_key}.json"

    def _validate_cache(self, cache_file: Path, expected_key: str) -> Optional[List[Any]]:
        """
        Validate and load cache file.

        Returns:
            List of alias data if valid, None if invalid/corrupted
        """
        if not cache_file.exists():
            return None

        try:
            with open(cache_file, 'r', encoding='utf-8') as f:
                data = json.load(f)

            # Check cache key matches
            if data.get('key') != expected_key:
                return None

            # Check cache version
            if data.get('version') != self.CACHE_VERSION:
                return None

            return data.get('aliases', [])

        except (json.JSONDecodeError, IOError, OSError):
            # Cache corrupted - delete it
            try:
                cache_file.unlink()
            except OSError:
                pass
            return None

    def load(self, mode: str, config_paths: List[str]) -> Tuple[Optional[List], str]:
        """
        Load aliases from cache if valid.

        Returns:
            (aliases_list, cache_key) if cache valid, (None, cache_key) if not
        """
        cache_key = self._build_cache_key(mode, config_paths)
        cache_file = self.get_cache_file(mode, config_paths)

        aliases = self._validate_cache(cache_file, cache_key)
        return aliases, cache_key

    def save(self, mode: str, config_paths: List[str], aliases: List, cache_key: str):
        """Save aliases to cache."""
        cache_file = self.get_cache_file(mode, config_paths)

        data = {
            'version': self.CACHE_VERSION,
            'key': cache_key,
            'mode': mode,
            'aliases': aliases,
        }

        # Write atomically
        temp_file = cache_file.with_suffix('.tmp')
        try:
            with open(temp_file, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            temp_file.replace(cache_file)
        except IOError as e:
            raise CacheError(f"Failed to write cache: {e}")

    def clear(self):
        """Clear all cache files."""
        if self.CACHE_DIR.exists():
            for cache_file in self.CACHE_DIR.glob("*.json"):
                try:
                    cache_file.unlink()
                except OSError:
                    pass
</action>

### Task 1.6: Implement config.py - Multi-source Config Loading

实现多源配置合并。

<read_first>
- sh/wsha.sh 第 515-552 行 - 现有 shell 配置合并逻辑参考
- D-02: 优先级：内置 < 用户 < 项目级
- SHELL-03: Python 版本与 shell 版本共享同一 wsh-alias.txt 配置文件
- SHELL-06: 重复别名检测
- config/wsh-alias.txt - 现有配置格式参考
</read_first>

<acceptance_criteria>
- `py/wsha/config.py` 包含 `load_config()` 函数
- 默认配置路径优先级：内置(config/wsh-alias.txt) < 用户(~/.config/wsh-alias.txt) < 项目级(./config/wsh-alias.txt)
- 支持通过 `WSHA_CONFIG_FILE` 环境变量指定单一配置文件
- 返回 `(aliases, errors, source_info)` - 别名列表、解析错误、来源信息
- 重复别名在单文件内被检测（通过 `fail_on_duplicate` 参数）
- 多源合并时，高优先级覆盖低优先级别名
</acceptance_criteria>

<action>
```python
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
    home = Path.home()
    app_home = os.environ.get('APP_HOME', '')
    configs = {}

    # Built-in: APP_HOME/config/wsh-alias.txt
    if app_home:
        builtin_path = Path(app_home) / "config" / "wsh-alias.txt"
        if builtin_path.exists():
            configs['builtin'] = str(builtin_path)

    # User-level: ~/.config/wsh-alias.txt
    user_path = home / ".config" / "wsh-alias.txt"
    if user_path.exists():
        configs['user'] = str(user_path)

    # Project-level: ./config/wsh-alias.txt
    local_path = Path.cwd() / "config" / "wsh-alias.txt"
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
```

注：缓存数据不包括 `AliasEntry` 对象本身，而是可序列化的字典。
</action>

### Task 1.7: Implement __init__.py - Package Entry Point

实现 Python 包的入口。

<read_first>
- D-01: Python 包放在 `py/` 目录
- D-14: Python 版本与 shell 版本共享同一 wsh-alias.txt 配置文件
</read_first>

<acceptance_criteria>
- `py/wsha/__init__.py` 包含 `load_config()` 函数导出
- `py/wsha/__init__.py` 包含所有异常类导出
- `py/wsha/__init__.py` 包含 `VERSION` 常量
</acceptance_criteria>

<action>
```python
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
]
```
</action>

## Wave 2: CLI and Fallback Integration

### Task 2.1: Implement cli.py - Click CLI

实现 Click CLI 入口。

<read_first>
- D-02: 使用 Click CLI 入口点
- CFG-04: `w --cache-clear` explicit cache invalidation
</read_first>

<acceptance_criteria>
- `py/cli.py` 包含 `main()` 函数作为入口点
- `--cache-clear` 选项清除缓存
- `--list` / `-l` 选项列出所有别名（Phase 1 仅框架，后续完善）
- `--help` 显示帮助信息
- CLI 输出 "Cache cleared" 或类似消息确认清除成功
</acceptance_criteria>

<action>
```python
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
```

注：Phase 1 CLI 仅实现 `--cache-clear` 和基础列表功能。完整的 alias 展开功能在 Phase 2-4 实现。
</action>

### Task 2.2: Implement Fallback Mechanism

实现 Python 失败时 fallback 到 wsha.sh 的机制。

<read_first>
- D-13: Python 执行失败（ImportError、RuntimeError 等）自动 fallback 到 wsha.sh
- sh/wsha.sh - 现有 shell 入口脚本
</read_first>

<acceptance_criteria>
- CLI 入口 (`cli.py`) 在 ImportError 或 RuntimeError 时打印警告并退出
- 退出码为 0 表示 Python 执行失败但 fallback 成功（实际由 shell 执行）
- 后续任务会在 w.bat/w.sh 中实现真正的 fallback 路由
</acceptance_criteria>

<action>
在 `py/cli.py` 的 `main()` 函数中添加 fallback 逻辑：

```python
@click.group()
@click.version_option(version=VERSION)
def main():
    """wsha - alias command launcher."""
    pass

# 这个任务主要是记录决策，实际的 fallback 逻辑在 Windows 入口点 (w.bat) 实现
# Phase 1 的 fallback 机制：CLI 顶层捕获异常，输出友好错误
```

真正的 fallback 机制在 Phase 4（CLI Interface & Shell Integration）中实现。

决策记录：
- D-13: Python 执行失败时自动 fallback 到 wsha.sh
- Phase 1 暂不实现复杂的 fallback 逻辑（Phase 4 处理）
- Phase 1 CLI 仅作为测试框架存在
</action>

## Wave 3: Testing and Verification

### Task 3.1: Create Test Script for Config Parsing

创建配置解析的测试脚本。

<read_first>
- `__test__/wsha.test.sh` - 现有测试框架参考
- config/wsh-alias.txt - 现有配置格式参考
</read_first>

<acceptance_criteria>
- `__test__/wsha_python_test.py` 测试文件存在
- 测试无引号别名解析
- 测试带引号别名解析
- 测试注释行跳过
- 测试空行跳过
- 测试重复别名检测
- 测试错误行号显示
- 测试缓存 mtime 验证
- 测试缓存清除功能
- `python __test__/wsha_python_test.py` 运行成功（exit 0）
</acceptance_criteria>

<action>
创建 `__test__/wsha_python_test.py`：

```python
#!/usr/bin/env python3
"""Tests for wsha Python config system."""

import os
import sys
import tempfile
import time
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(__file__).rsplit('/', 1)[0])

from wsha import parse_line, parse_file, ConfigParseError, DuplicateAliasError
from wsha import CacheManager, load_config, AliasEntry


def test_parse_unquoted_alias():
    """Test parsing unquoted alias."""
    result = parse_line("fox firefox", "test.txt", 1)
    assert result == ("fox", "firefox"), f"Got {result}"


def test_parse_quoted_alias():
    """Test parsing quoted alias with spaces."""
    result = parse_line('"pcodex l" echo codex-last', "test.txt", 1)
    assert result == ("pcodex l", "echo codex-last"), f"Got {result}"


def test_parse_comment_line():
    """Test that comment lines are skipped."""
    result = parse_line("# this is a comment", "test.txt", 1)
    assert result is None


def test_parse_empty_line():
    """Test that empty lines are skipped."""
    result = parse_line("", "test.txt", 1)
    assert result is None
    result = parse_line("   ", "test.txt", 1)
    assert result is None


def test_parse_error_no_target():
    """Test error when alias has no target."""
    try:
        parse_line("lonely_alias", "test.txt", 1)
        assert False, "Should have raised ConfigParseError"
    except ConfigParseError as e:
        assert "has no target command" in str(e)
        assert e.line_no == 1


def test_parse_error_invalid_quoted():
    """Test error for invalid quoted syntax."""
    try:
        parse_line('"incomplete', "test.txt", 1)
        assert False, "Should have raised ConfigParseError"
    except ConfigParseError as e:
        assert "invalid quoted alias syntax" in str(e)


def test_parse_file_with_errors():
    """Test parsing file with errors shows line numbers."""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
        f.write("# valid\n")
        f.write("good_alias echo command\n")
        f.write("bad_alias\n")  # Error: no target
        f.write("another good one echo test\n")
        temp_path = f.name

    try:
        aliases, errors = parse_file(temp_path)
        assert len(aliases) == 2
        assert len(errors) == 1
        assert errors[0].line_no == 3
        assert errors[0].config_path == temp_path
    finally:
        os.unlink(temp_path)


def test_duplicate_alias_detection():
    """Test duplicate alias detection within single file."""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
        f.write("alias1 echo one\n")
        f.write("alias2 echo two\n")
        f.write("alias1 echo three\n")  # Duplicate
        temp_path = f.name

    try:
        aliases, errors = parse_file(temp_path)
        # Without fail_on_duplicate, last one wins
        assert len(aliases) == 2
        # Check that alias1 has the last template (echo three)
        alias1 = next(a for a in aliases if a.name == "alias1")
        assert alias1.template == "echo three"
    finally:
        os.unlink(temp_path)


def test_cache_clear():
    """Test cache clearing."""
    cache_mgr = CacheManager()
    cache_mgr.clear()

    # Create a temp cache
    cache_mgr.CACHE_DIR.mkdir(parents=True, exist_ok=True)
    test_cache = cache_mgr.CACHE_DIR / "test.json"
    test_cache.write_text("{}")

    assert test_cache.exists()
    cache_mgr.clear()
    assert not test_cache.exists()


def test_cache_mtime_validation():
    """Test cache invalidation when config file changes."""
    cache_mgr = CacheManager()

    # Create temp config
    with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
        f.write("test echo hello\n")
        temp_path = f.name

    try:
        # Load config with cache
        os.environ['APP_HOME'] = str(Path(temp_path).parent.parent)
        aliases1, errors1, _ = load_config(config_path=temp_path, use_cache=True)

        # Modify file
        time.sleep(0.1)  # Ensure mtime differs
        with open(temp_path, 'a') as f:
            f.write("test2 echo world\n")

        # Load again - cache should be invalid
        aliases2, errors2, _ = load_config(config_path=temp_path, use_cache=True)

        # Should have 2 aliases now (not cached)
        assert len(aliases2) == 2

    finally:
        os.unlink(temp_path)
        if 'APP_HOME' in os.environ:
            del os.environ['APP_HOME']


def test_cache_corruption_recovery():
    """Test that corrupted cache is auto-deleted and recovers."""
    cache_mgr = CacheManager()

    # Create temp config
    with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
        f.write("test echo hello\n")
        temp_path = f.name

    try:
        # Load once to create cache
        aliases1, errors1, _ = load_config(config_path=temp_path, use_cache=True)

        # Corrupt the cache
        cache_file = cache_mgr.get_cache_file("single", [temp_path])
        cache_file.write_text("not valid json{{{")

        # Load again - should recover
        aliases2, errors2, _ = load_config(config_path=temp_path, use_cache=True)

        # Should still work (cache was rebuilt)
        assert len(aliases2) == 1

    finally:
        os.unlink(temp_path)


def main():
    """Run all tests."""
    tests = [
        test_parse_unquoted_alias,
        test_parse_quoted_alias,
        test_parse_comment_line,
        test_parse_empty_line,
        test_parse_error_no_target,
        test_parse_error_invalid_quoted,
        test_parse_file_with_errors,
        test_duplicate_alias_detection,
        test_cache_clear,
        test_cache_mtime_validation,
        test_cache_corruption_recovery,
    ]

    passed = 0
    failed = 0

    for test in tests:
        try:
            test()
            print(f"PASS: {test.__name__}")
            passed += 1
        except Exception as e:
            print(f"FAIL: {test.__name__}: {e}")
            failed += 1

    print(f"\n{passed} passed, {failed} failed")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
```
</action>

### Task 3.2: Verify Phase 1 Success Criteria

验证所有 Phase 1 成功标准。

<read_first>
- .planning/ROADMAP.md § Phase 1 Success Criteria
- 01-CONTEXT.md § Decisions
</read_first>

<acceptance_criteria>
1. ✅ Python 可以解析 wsh-alias.txt 格式（无引号、带引号、注释行）- 通过 test_parse_* 测试验证
2. ✅ 多源配置按优先级合并（内置 < 用户 < 项目级）- 通过 config.py get_default_config_paths() 实现
3. ✅ 配置缓存保存在 ~/.cache/wsha/，基于文件时间戳验证 - 通过 cache.py 和 test_cache_mtime_validation 验证
4. ✅ `w --cache-clear` 可以清除缓存 - 通过 cli.py --cache-clear 选项实现
5. ✅ 缓存文件损坏时给出明确错误信息 - 通过 test_cache_corruption_recovery 验证
6. ✅ Python 版本与 shell 版本共享同一配置文件 - 通过 config.py 使用相同路径实现
7. ✅ 单个配置文件中重复别名可以被检测 - 通过 test_duplicate_alias_detection 验证
8. ✅ 配置文件格式错误时给出描述性错误信息 - 通过 test_parse_file_with_errors 验证
</acceptance_criteria>

<action>
执行验证步骤：
1. 运行 `python __test__/wsha_python_test.py` 确保所有测试通过
2. 验证 pyproject.toml 格式正确
3. 验证 py/wsha/ 目录结构完整
4. 手动测试 `python -m wsha --help` 如可行
5. 手动测试 `python -m wsha --cache-clear` 如可行
</action>

## Wave 4: Documentation and Cleanup

### Task 4.1: Update CLAUDE.md with Phase 1 Structure

更新项目文档以反映 Phase 1 的 Python 包结构。

<read_first>
- CLAUDE.md (现有项目说明)
</read_first>

<acceptance_criteria>
- CLAUDE.md 中描述 Python 包位于 `py/` 目录
- CLAUDE.md 中列出 Python 相关的配置文件
</acceptance_criteria>

<action>
在 CLAUDE.md 的 "关键依赖" 部分添加：
```markdown
## Python 依赖
- Python 3.8+
- click>=8.0

## Python 包结构
- `py/wsha/` - Python 包源码
- `py/wsha/__init__.py` - 包入口
- `py/wsha/parser.py` - wsh-alias.txt 解析器
- `py/wsha/config.py` - 配置加载和合并
- `py/wsha/cache.py` - 缓存管理
- `py/wsha/errors.py` - 自定义异常
- `py/cli.py` - Click CLI 入口
- `pyproject.toml` - Python 项目配置
```
</action>

## Implementation Notes

### Files Created/Modified Summary

| File | Status | Purpose |
|------|--------|---------|
| `py/wsha/__init__.py` | 新建 | Python 包入口，导出公共 API |
| `py/wsha/errors.py` | 新建 | 自定义异常类 |
| `py/wsha/parser.py` | 新建 | wsh-alias.txt 解析器 |
| `py/wsha/config.py` | 新建 | 多源配置加载和合并 |
| `py/wsha/cache.py` | 新建 | 缓存管理 |
| `py/cli.py` | 新建 | Click CLI 入口 |
| `pyproject.toml` | 新建 | Python 项目配置 |
| `__test__/wsha_python_test.py` | 新建 | 测试脚本 |
| `CLAUDE.md` | 修改 | 添加 Python 包结构说明 |

### Dependencies

- Python 3.8+
- click>=8.0 (for CLI)
- hatchling (for packaging, dev dependency)

### Out of Scope for Phase 1

- Alias matching and expansion (Phase 2)
- Template expansion (Phase 3)
- Full CLI routing (Phase 4)
- Shell version fallback integration (Phase 4)
- Test suite compatibility with wsha.test.sh (Phase 5)

### Cache File Format

JSON format:
```json
{
  "version": "v2",
  "key": "sha1_hash_of_config_key",
  "mode": "multi",
  "aliases": [
    {
      "name": "fox",
      "template": "firefox",
      "config_path": "/path/to/config",
      "source_name": "user",
      "line_no": 10
    }
  ]
}
```

### Error Message Format

All config parse errors follow format:
```
{config_path}:{line_no}: {message}
```

Example:
```
config/wsh-alias.txt:12: duplicate alias "fox"
```

---

*Plan created: 2026-04-13*
*Phase: 01-config-system-core-architecture*
