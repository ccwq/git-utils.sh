#!/usr/bin/env python3
"""
wsha-core.py - wsha alias command launcher core

将 wsha.sh 的核心逻辑移植到 Python，实现独立的别名查找和模板展开。
"""

import sys
import os
import re
import argparse
from typing import List, Dict, Optional, Tuple

WSHA_ENTRY = os.environ.get("WSHA_ENTRY", "wsha")
CACHE_DIR = os.path.expanduser("~/.cache/wsha")
CACHE_MAX_AGE = 300  # 5 minutes

# 配置优先级
CONFIG_PRIORITY = ["内置", "用户", "项目"]


# 别名数据结构
class Alias:
    def __init__(self, key: str, template: str, config_path: str, source_name: str):
        self.key = key
        self.template = template
        self.config_path = config_path
        self.source_name = source_name
        self.tokens: List[str] = []
        self.token_count = 0
        self.double_index = -1
        self.wildcard_weight = 0
        self.literal_chars = 0
        self.first_token_mode = "wildcard"
        self.first_token_lower = ""
        self.prefix_type = "normal"  # normal, sequential(&), or(|)

    def build_metadata(self):
        """从 alias key 构建元数据"""
        self.tokens = tokenize(self.key)
        self.token_count = len(self.tokens)
        self.double_index = -1
        self.wildcard_weight = 0
        self.literal_chars = 0
        self.first_token_mode = "wildcard"
        self.first_token_lower = ""

        if self.token_count > 0:
            first = self.tokens[0]
            if '*' not in first:
                self.first_token_mode = "literal"
                self.first_token_lower = first.lower()
            else:
                self.first_token_mode = "wildcard"

        for i, token in enumerate(self.tokens):
            if '**' in token:
                if self.double_index == -1:
                    self.double_index = i
                else:
                    self.double_index = -2  # 多个 **
                self.wildcard_weight += 1000
            elif '*' in token:
                wc = token.count('*')
                self.wildcard_weight += wc

        stripped = self.key.replace('**', '').replace('*', '').replace(' ', '')
        self.literal_chars = len(stripped)


# 全局别名存储
_aliases: List[Alias] = []
_alias_buckets: Dict[str, List[int]] = {}  # literal first token -> index list
_alias_wildcard_first: List[int] = []  # wildcard first token indexes


def tokenize(text: str) -> List[str]:
    """将文本按空白分割为 token 数组"""
    if not text:
        return []
    # 禁用 glob 展开
    words = text.split()
    return [w for w in words if w]


def parse_config_line(line: str, config_path: str, line_no: int) -> Optional[Tuple[str, str, str]]:
    """
    解析配置行，返回 (alias_name, template, prefix_type) 或 None
    prefix_type: "normal", "sequential", "or"
    """
    trimmed = line.strip()
    if not trimmed or trimmed.startswith('#'):
        return None

    alias_name = ""
    template = ""
    prefix_type = "normal"

    # 检查引号包裹的 alias
    if trimmed.startswith('"'):
        match = re.match(r'^"([^"]+)"\s+(.+)$', trimmed)
        if match:
            alias_name = match.group(1)
            template = match.group(2).strip()
        else:
            print(f"[wsha] invalid config at line {line_no} in \"{config_path}\": missing alias", file=sys.stderr)
            return None
    else:
        # 非引号 alias
        match = re.match(r'^(\S+)\s+(.+)$', trimmed)
        if match:
            alias_name = match.group(1)
            template = match.group(2).strip()
        elif re.match(r'^\S+$', trimmed):
            print(f"[wsha] invalid config at line {line_no} in \"{config_path}\": alias \"{trimmed}\" has no target command", file=sys.stderr)
            return None
        else:
            print(f"[wsha] invalid config at line {line_no} in \"{config_path}\": missing alias", file=sys.stderr)
            return None

    # 去除 template 首尾引号
    if len(template) >= 2 and template.startswith('"') and template.endswith('"'):
        template = template[1:-1]

    # 检查 & 或 | 前缀
    if alias_name.startswith('&'):
        prefix_type = "sequential"
        alias_name = alias_name[1:]
    elif alias_name.startswith('|'):
        prefix_type = "or"
        alias_name = alias_name[1:]

    if not alias_name or not template:
        return None

    return (alias_name, template, prefix_type)


def load_config_dir(dir_path: str, source_name: str) -> bool:
    """加载目录中的所有 *.txt 文件"""
    if not os.path.isdir(dir_path):
        return True  # 目录不存在不算错误

    txt_files = []
    for f in os.listdir(dir_path):
        if f.endswith('.txt') and not f.startswith('_'):
            txt_files.append(f)

    # 按字母序排序
    txt_files.sort()

    for filename in txt_files:
        config_path = os.path.join(dir_path, filename)
        if not load_single_config_file(config_path, source_name):
            return False

    return True


def load_single_config_file(config_path: str, source_name: str) -> bool:
    """加载单个配置文件"""
    if not os.path.isfile(config_path):
        return True

    line_no = 0
    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            for line in f:
                line_no += 1
                line = line.rstrip('\r\n')
                result = parse_config_line(line, config_path, line_no)
                if result is None:
                    continue

                alias_name, template, prefix_type = result

                # 检查是否已存在
                existing_idx = find_alias_index(alias_name)
                alias = Alias(alias_name, template, config_path, source_name)
                alias.prefix_type = prefix_type
                alias.build_metadata()

                if existing_idx >= 0:
                    _aliases[existing_idx] = alias
                    update_buckets(existing_idx, alias)
                else:
                    _aliases.append(alias)
                    existing_idx = len(_aliases) - 1
                    update_buckets(existing_idx, alias)

    except IOError as e:
        print(f"[wsha] error reading {config_path}: {e}", file=sys.stderr)
        return False

    return True


def find_alias_index(key: str) -> int:
    """查找 alias 索引，不存在返回 -1"""
    for i, a in enumerate(_aliases):
        if a.key == key:
            return i
    return -1


def update_buckets(idx: int, alias: Alias):
    """更新分桶索引"""
    if alias.first_token_mode == "literal":
        bucket_key = alias.first_token_lower
        if bucket_key not in _alias_buckets:
            _alias_buckets[bucket_key] = []
        _alias_buckets[bucket_key].append(idx)
    else:
        _alias_wildcard_first.append(idx)


def get_app_env():
    """获取应用环境变量"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    app_home = os.path.dirname(script_dir)
    app_sh = script_dir
    app_config = os.path.join(app_home, 'config')
    return app_home, app_sh, app_config


def load_config() -> bool:
    """加载所有配置"""
    global _aliases, _alias_buckets, _alias_wildcard_first

    _aliases = []
    _alias_buckets = {}
    _alias_wildcard_first = []

    app_home, app_sh, app_config = get_app_env()

    builtin_dir = os.path.join(app_home, 'config', 'wsh-alias')
    user_dir = os.path.expanduser('~/.config/wsh-alias')
    local_dir = os.path.join(os.getcwd(), '.config', 'wsh-alias')

    if not load_config_dir(builtin_dir, "内置"):
        return False
    if not load_config_dir(user_dir, "用户"):
        return False
    if not load_config_dir(local_dir, "项目"):
        return False

    return True


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


def match_token_pattern(pattern: str, token: str) -> Tuple[bool, List[str], int]:
    """
    单 token 通配符匹配
    返回: (是否匹配, 捕获列表, 通配符数量)
    """
    # 不含通配符，直接比较（忽略大小写）
    if '*' not in pattern:
        if pattern.lower() == token.lower():
            return (True, [], 0)
        return (False, [], 0)

    # 含通配符，构建正则
    regex = "^"
    remaining = pattern
    wildcard_count = 0

    while '*' in remaining:
        idx = remaining.index('*')
        before = remaining[:idx]
        escaped_before = re.escape(before)
        regex += escaped_before
        if escaped_before:
            regex += ".*"
        remaining = remaining[idx + 1:]
        wildcard_count += 1

    regex += re.escape(remaining) + "$"
    regex = regex.replace('.*.*', '.*')

    token_lower = token.lower()
    match = re.match(regex, token_lower, re.IGNORECASE)
    if match:
        return (True, list(match.groups()), wildcard_count)
    return (False, [], wildcard_count)


def match_double_star_remainder(pattern: str, input_text: str) -> Tuple[bool, List[str], str]:
    """
    双星号匹配：匹配 pattern 中 ** 之前的前缀，捕获剩余部分
    返回: (是否匹配, 捕获列表, rest)
    """
    if '**' not in pattern:
        return (False, [], "")

    idx = pattern.index('**')
    head = pattern[:idx]
    tail = pattern[idx + 2:]

    head_regex = re.escape(head).replace('\\*', '.*')
    tail_regex = re.escape(tail).replace('\\*', '.*')

    full_regex = f"^{head_regex}(.*?){tail_regex}$"
    full_regex = full_regex.replace('.*.*', '.*')

    match = re.match(full_regex, input_text, re.IGNORECASE)
    if match:
        return (True, list(match.groups()[:-1]), match.group(len(match.groups())))
    return (False, [], "")


def find_best_match(input_tokens: List[str]) -> Tuple[str, str, List[str], str, int]:
    """
    查找最佳匹配
    返回: (alias_key, template, captures, rest_capture, args_start)
    """
    if not input_tokens:
        return ("", "", [], "", 0)

    input_count = len(input_tokens)
    first_lower = input_tokens[0].lower()

    # 收集候选
    candidates = []
    if first_lower in _alias_buckets:
        candidates.extend(_alias_buckets[first_lower])
    candidates.extend(_alias_wildcard_first)

    best_alias = None
    best_template = ""
    best_captures = []
    best_rest_capture = ""
    best_args_start = 0
    best_score = -1

    for idx in candidates:
        alias = _aliases[idx]

        # 数量检查
        if alias.double_index >= 0:
            if alias.double_index == alias.token_count - 1:
                if input_count < alias.token_count:
                    continue
            else:
                if input_count < alias.token_count:
                    continue
        else:
            if input_count < alias.token_count:
                continue

        if alias.double_index == -2:
            continue

        # 匹配
        ok = True
        captures = []
        rest_capture = ""
        input_consumed = 0
        wildcard_count = 0

        for ti in range(alias.token_count):
            if alias.double_index >= 0 and ti == alias.double_index:
                remain_text = " ".join(input_tokens[ti:])
                matched, dc, rest = match_double_star_remainder(alias.tokens[ti], remain_text)
                if not matched or not rest:
                    ok = False
                    break
                captures.extend(dc)
                rest_capture = rest
                wildcard_count += 1000
                input_consumed = input_count
            else:
                matched, mc, wc = match_token_pattern(alias.tokens[ti], input_tokens[ti])
                if not matched:
                    ok = False
                    break
                captures.extend(mc)
                wildcard_count += wc
                input_consumed = ti + 1

        if not ok:
            continue

        score = alias.token_count * 10000 + alias.literal_chars * 100 - wildcard_count

        if score > best_score:
            best_score = score
            best_alias = alias
            best_template = alias.template
            best_captures = captures
            best_rest_capture = rest_capture
            best_args_start = input_consumed

    if best_alias:
        return (best_alias.key, best_template, best_captures, best_rest_capture, best_args_start)
    return ("", "", [], "", 0)


def expand_template(template: str, captures: List[str], rest_capture: str, runtime_args: List[str]) -> str:
    """展开模板中的变量"""
    result = template

    for i in range(len(captures) - 1, -1, -1):
        result = result.replace(f"${i + 1}", captures[i])

    result = result.replace("$$", rest_capture)

    tokens = tokenize(result)
    final_tokens = []
    placeholder_used = False

    for t in tokens:
        if t == "--":
            placeholder_used = True
            final_tokens.extend(runtime_args)
        else:
            final_tokens.append(t)

    if not placeholder_used and runtime_args:
        final_tokens.extend(runtime_args)

    return " ".join(final_tokens)


def list_aliases():
    """列出所有别名"""
    if not _aliases:
        load_config()

    if not _aliases:
        print("[wsha] no alias found.")
        return 0

    # 按配置文件分组
    groups = {}
    for i, alias in enumerate(_aliases):
        if alias.config_path not in groups:
            groups[alias.config_path] = {"source": alias.source_name, "aliases": []}
        groups[alias.config_path]["aliases"].append((alias.key, alias.template))

    for config_path, group in groups.items():
        print(f"[{group['source']}] {os.path.dirname(config_path)}")
        print(f"  {os.path.basename(config_path)}")
        print()
        for key, template in group["aliases"]:
            print(f"  {key}  {template}")
        print()

    return 0


def main():
    """主入口函数"""
    parser = argparse.ArgumentParser(prog="wsha-core", add_help=False)
    parser.add_argument("alias", nargs="?", help="alias name")
    parser.add_argument("args", nargs="*", help="additional arguments")
    parser.add_argument("--help", action="store_true")
    parser.add_argument("-l", "--list", action="store_true")
    parser.add_argument("--clear", action="store_true")
    parser.add_argument("-e", "--entry", default=WSHA_ENTRY)

    parsed, unknown = parser.parse_known_args()

    if parsed.help:
        print_help()
        return 0

    if parsed.clear:
        return clear_cache()

    if parsed.list:
        load_config()
        return list_aliases()

    if not parsed.alias:
        print("[wsha] missing alias.", file=sys.stderr)
        return 1

    # 加载配置
    load_config()

    # 构建输入 token
    input_tokens = [parsed.alias] + parsed.args

    # 如果只有一个 token 且包含空格，拆分
    if len(input_tokens) == 1 and ' ' in input_tokens[0]:
        input_tokens = input_tokens[0].split()

    # 查找最佳匹配
    alias_key, template, captures, rest_capture, args_start = find_best_match(input_tokens)

    if not alias_key:
        # 未找到，直接透传
        final_cmd = " ".join(input_tokens)
        print(final_cmd)
        return 0

    # 收集运行时参数
    runtime_args = input_tokens[args_start:] if args_start < len(input_tokens) else []

    # 展开模板
    final_cmd = expand_template(template, captures, rest_capture, runtime_args)

    print(final_cmd)
    return 0


if __name__ == "__main__":
    sys.exit(main())
