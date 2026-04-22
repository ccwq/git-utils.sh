#!/usr/bin/env python3
"""
wsha-core.py - wsha alias command launcher core

将 wsha.sh 的核心逻辑移植到 Python，实现独立的别名查找和模板展开。
"""

import sys
import os
import argparse

WSHA_ENTRY = os.environ.get("WSHA_ENTRY", "wsha")
CACHE_DIR = os.path.expanduser("~/.cache/wsha")
CACHE_MAX_AGE = 300  # 5 minutes


def print_help():
    """打印帮助信息"""
    print("""wsha-core - alias command launcher

Usage:
  wsha-core <alias> [args...]
  wsha-core --list | -l
  wsha-core --clear

Config priority:
  1. config/wsh-alias/*.txt  (APP_HOME)
  2. $HOME/.config/wsh-alias/*.txt
  3. $PWD/.config/wsh-alias/*.txt

Rules:
  - Ignore empty lines and lines starting with '#'
  - Files starting with '_' are ignored (e.g. _disabled.txt)
  - Same alias: first wins (loaded alphabetically within each dir)
  - Alias supports '*' wildcard (single token capture), map to $1..$N
  - Alias supports '**' wildcard (match all remaining input), map to $$
  - If template contains '--', runtime args are inserted there
  - Otherwise runtime args are appended at the end
""")


def clear_cache():
    """清理缓存目录中的缓存文件"""
    if not os.path.exists(CACHE_DIR):
        print("[wsha-core] cache directory does not exist")
        return 0

    removed = 0
    for f in os.listdir(CACHE_DIR):
        if f.endswith(".cache"):
            try:
                os.remove(os.path.join(CACHE_DIR, f))
                removed += 1
            except OSError:
                pass

    print(f"[wsha-core] cleared {removed} cache file(s)")
    return 0


def list_aliases():
    """列出所有可用的别名（空实现）"""
    print("[wsha-core] listing aliases...")
    return 0


def main():
    """主入口函数"""
    parser = argparse.ArgumentParser(
        prog="wsha-core",
        description="wsha alias command launcher core"
    )
    parser.add_argument("alias", nargs="?", help="alias name")
    parser.add_argument("args", nargs="*", help="additional arguments")
    parser.add_argument("-l", "--list", action="store_true", help="list all aliases")
    parser.add_argument("--clear", action="store_true", help="clear cache")
    parser.add_argument("-e", "--entry", default=WSHA_ENTRY, help="entry name")

    parsed = parser.parse_args()

    # argparse 会自动处理 --help 和 -h

    if parsed.clear:
        return clear_cache()

    if parsed.list:
        return list_aliases()

    if not parsed.alias:
        print("[wsha] missing alias.", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
