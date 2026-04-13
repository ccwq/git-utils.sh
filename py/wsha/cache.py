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
