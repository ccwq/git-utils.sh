#!/usr/bin/env python3
"""wsha alias command launcher core.

真实运行时核心位于 sh/core 下：负责配置解析、别名匹配、模板展开、
三引号 block 编译，以及为 shell/batch wrapper 输出单行可执行命令。
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import shlex
import sys
import tempfile
import time
from dataclasses import dataclass, asdict
from typing import Dict, List, Optional, Tuple

PY_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "py"))
if PY_DIR not in sys.path:
    sys.path.insert(0, PY_DIR)

from wsha.list_table import AliasListEntry, classify_alias, render_alias_table

WSHA_ENTRY = os.environ.get("WSHA_ENTRY", "wsha")
CACHE_MAX_AGE = 300  # 5 minutes
CACHE_VERSION = "v5"
CMDLINE_OUTPUT = os.environ.get("WSHA_CMDLINE_OUTPUT", "")
VALID_BLOCK_RUNNERS = {"bash", "sh", "cmd", "bat", "pwsh", "powershell"}
RECURSIVE_ALIAS_COMMANDS = {"wsha", "wsha.bat", "w", "w.bat"}
MAX_ALIAS_DEPTH = 16


@dataclass
class Alias:
    key: str
    template: str
    config_path: str
    source_name: str
    prefix_type: str = "normal"
    is_block: bool = False
    block_runner: str = ""
    line_no: int = 0

    def __post_init__(self) -> None:
        self.tokens: List[str] = []
        self.token_count = 0
        self.double_index = -1
        self.wildcard_weight = 0
        self.literal_chars = 0
        self.first_token_mode = "wildcard"
        self.first_token_lower = ""
        self.build_metadata()

    def build_metadata(self) -> None:
        """从 alias key 构建匹配元数据。"""
        self.tokens = tokenize(self.key)
        self.token_count = len(self.tokens)
        self.double_index = -1
        self.wildcard_weight = 0
        self.literal_chars = 0
        self.first_token_mode = "wildcard"
        self.first_token_lower = ""

        if self.token_count > 0:
            first = self.tokens[0]
            if "*" not in first:
                self.first_token_mode = "literal"
                self.first_token_lower = first.lower()

        for i, token in enumerate(self.tokens):
            if "**" in token:
                if self.double_index == -1:
                    self.double_index = i
                else:
                    self.double_index = -2
                self.wildcard_weight += 1000
            elif "*" in token:
                self.wildcard_weight += token.count("*")

        stripped = self.key.replace("**", "").replace("*", "").replace(" ", "")
        self.literal_chars = len(stripped)

    def to_cache_item(self) -> Dict[str, object]:
        return {
            "key": self.key,
            "template": self.template,
            "config_path": self.config_path,
            "source_name": self.source_name,
            "prefix_type": self.prefix_type,
            "is_block": self.is_block,
            "block_runner": self.block_runner,
            "line_no": self.line_no,
        }

    @classmethod
    def from_cache_item(cls, item: Dict[str, object]) -> "Alias":
        return cls(
            str(item.get("key", "")),
            str(item.get("template", "")),
            str(item.get("config_path", "")),
            str(item.get("source_name", "")),
            str(item.get("prefix_type", "normal")),
            bool(item.get("is_block", False)),
            str(item.get("block_runner", "")),
            int(item.get("line_no", 0) or 0),
        )


_aliases: List[Alias] = []
_alias_buckets: Dict[str, List[int]] = {}
_alias_wildcard_first: List[int] = []


def get_home_dir() -> str:
    """Use Git Bash HOME before Windows profile expansion."""
    return os.environ.get("HOME") or os.path.expanduser("~")


def get_core_dir() -> str:
    return os.path.dirname(os.path.abspath(__file__))


def get_app_sh_dir() -> str:
    return os.path.dirname(get_core_dir())


def resolve_app_config_dir(app_home: str, app_sh: str) -> str:
    """Resolve config root, preferring sh/config and falling back to legacy config/."""
    new_dir = os.path.join(app_sh, "config")
    old_dir = os.path.join(app_home, "config")
    return new_dir if os.path.isdir(new_dir) or not os.path.isdir(old_dir) else old_dir


def get_app_env() -> Tuple[str, str, str]:
    """获取应用环境变量，注意当前文件位于 sh/core。"""
    app_home = os.environ.get("APP_HOME", "")
    if app_home:
        app_sh = os.environ.get("APP_SH", os.path.join(app_home, "sh"))
        app_config = os.environ.get("APP_CONFIG", resolve_app_config_dir(app_home, app_sh))
    else:
        app_sh = get_app_sh_dir()
        app_home = os.path.dirname(app_sh)
        app_config = resolve_app_config_dir(app_home, app_sh)
    return app_home, app_sh, app_config


def tokenize(text: str) -> List[str]:
    """将文本按空白分割为 token 数组。"""
    if not text:
        return []
    return [w for w in text.split() if w]


def strip_outer_template_quotes(template: str) -> str:
    if len(template) >= 2 and template.startswith('"') and template.endswith('"'):
        return template[1:-1]
    return template


def parse_alias_prefix(alias_name: str) -> Tuple[str, str]:
    """解析 & / | 前缀。"""
    prefix_type = "normal"
    if alias_name.startswith("&"):
        prefix_type = "sequential"
        alias_name = alias_name[1:]
    elif alias_name.startswith("|"):
        prefix_type = "or"
        alias_name = alias_name[1:]
    return alias_name, prefix_type


def parse_alias_name_from_prefix(prefix: str, config_path: str, line_no: int) -> Optional[Tuple[str, str]]:
    """解析 block opener 前面的 alias 名称。block 允许未引号 alias 含空格。"""
    alias_text = prefix.strip()
    if not alias_text:
        print(f"[wsha] invalid config at line {line_no} in \"{config_path}\": missing alias", file=sys.stderr)
        return None

    if alias_text.startswith('"'):
        match = re.match(r'^"([^"]+)"$', alias_text)
        if not match:
            print(f"[wsha] invalid config at line {line_no} in \"{config_path}\": missing alias", file=sys.stderr)
            return None
        alias_name = match.group(1)
    else:
        alias_name = alias_text

    alias_name, prefix_type = parse_alias_prefix(alias_name)
    if not alias_name:
        return None
    return alias_name, prefix_type


def parse_config_line(line: str, config_path: str, line_no: int) -> Optional[Tuple[str, str, str, bool, str]]:
    """解析单行 alias，返回 (alias, template, prefix_type, is_block, runner)。"""
    trimmed = line.strip()
    if not trimmed or trimmed.startswith("#"):
        return None

    # block opener：alias 部分 + 空白 + """runner，runner 必须在 opener 上显式给出。
    block_match = re.match(r'^(.*?)\s+"""([A-Za-z]+)\s*$', trimmed)
    if block_match:
        parsed_alias = parse_alias_name_from_prefix(block_match.group(1), config_path, line_no)
        if parsed_alias is None:
            return None
        runner = block_match.group(2).lower()
        if runner not in VALID_BLOCK_RUNNERS:
            print(f"[wsha] invalid block runner \"{runner}\" at line {line_no} in \"{config_path}\"", file=sys.stderr)
            return ("", "", "invalid", True, runner)
        alias_name, prefix_type = parsed_alias
        return alias_name, "", prefix_type, True, runner

    alias_name = ""
    template = ""

    if trimmed.startswith('"'):
        match = re.match(r'^"([^"]+)"\s+(.+)$', trimmed)
        if match:
            alias_name = match.group(1)
            template = match.group(2).strip()
        else:
            print(f"[wsha] invalid config at line {line_no} in \"{config_path}\": missing alias", file=sys.stderr)
            return None
    else:
        match = re.match(r'^(\S+)\s+(.+)$', trimmed)
        if match:
            alias_name = match.group(1)
            template = match.group(2).strip()
        elif re.match(r'^\S+$', trimmed):
            print(
                f"[wsha] invalid config at line {line_no} in \"{config_path}\": alias \"{trimmed}\" has no target command",
                file=sys.stderr,
            )
            return None
        else:
            print(f"[wsha] invalid config at line {line_no} in \"{config_path}\": missing alias", file=sys.stderr)
            return None

    template = strip_outer_template_quotes(template)
    alias_name, prefix_type = parse_alias_prefix(alias_name)
    if not alias_name or not template:
        return None
    return alias_name, template, prefix_type, False, ""


def load_config_dir(dir_path: str, source_name: str, fail_on_duplicate: bool = False) -> bool:
    """加载目录中的所有 *.txt 文件。"""
    if not os.path.isdir(dir_path):
        return True

    txt_files = [f for f in os.listdir(dir_path) if f.endswith(".txt") and not f.startswith("_")]
    txt_files.sort()

    for filename in txt_files:
        config_path = os.path.join(dir_path, filename)
        if not load_single_config_file(config_path, source_name, fail_on_duplicate):
            return False
    return True


def add_alias(alias: Alias, fail_on_duplicate: bool, line_no: int, config_path: str) -> bool:
    existing_idx = find_alias_index(alias.key)
    if fail_on_duplicate and existing_idx >= 0:
        print(f"[wsha] duplicate alias \"{alias.key}\" at line {line_no} in \"{config_path}\"", file=sys.stderr)
        return False

    if existing_idx >= 0:
        _aliases[existing_idx] = alias
        rebuild_buckets()
    else:
        _aliases.append(alias)
        update_buckets(len(_aliases) - 1, alias)
    return True


def load_single_config_file(config_path: str, source_name: str, fail_on_duplicate: bool = False) -> bool:
    """加载单个配置文件，支持三引号 block。"""
    if not os.path.isfile(config_path):
        return True

    try:
        with open(config_path, "r", encoding="utf-8") as f:
            lines = f.readlines()
    except IOError as e:
        print(f"[wsha] error reading {config_path}: {e}", file=sys.stderr)
        return False

    line_no = 0
    in_block = False
    block_alias = ""
    block_prefix = "normal"
    block_runner = ""
    block_start = 0
    block_lines: List[str] = []

    for raw_line in lines:
        line_no += 1
        line = raw_line.rstrip("\r\n")

        if in_block:
            if line.strip() == '"""':
                body = "\n".join(block_lines)
                alias = Alias(block_alias, body, config_path, source_name, block_prefix, True, block_runner, block_start)
                if not add_alias(alias, fail_on_duplicate, block_start, config_path):
                    return False
                in_block = False
                block_alias = ""
                block_lines = []
                continue
            block_lines.append(line)
            continue

        result = parse_config_line(line, config_path, line_no)
        if result is None:
            continue

        alias_name, template, prefix_type, is_block, runner = result
        if prefix_type == "invalid":
            return False

        if is_block:
            in_block = True
            block_alias = alias_name
            block_prefix = prefix_type
            block_runner = runner
            block_start = line_no
            block_lines = []
            continue

        alias = Alias(alias_name, template, config_path, source_name, prefix_type, False, "", line_no)
        if not add_alias(alias, fail_on_duplicate, line_no, config_path):
            return False

    if in_block:
        print(f"[wsha] invalid config at line {block_start} in \"{config_path}\": unclosed block", file=sys.stderr)
        return False
    return True


def find_alias_index(key: str) -> int:
    for i, a in enumerate(_aliases):
        if a.key == key:
            return i
    return -1


def update_buckets(idx: int, alias: Alias) -> None:
    if alias.first_token_mode == "literal":
        _alias_buckets.setdefault(alias.first_token_lower, []).append(idx)
    else:
        _alias_wildcard_first.append(idx)


def rebuild_buckets() -> None:
    global _alias_buckets, _alias_wildcard_first
    _alias_buckets = {}
    _alias_wildcard_first = []
    for idx, alias in enumerate(_aliases):
        alias.build_metadata()
        update_buckets(idx, alias)


def get_cache_file_path() -> str:
    cache_dir = os.path.join(get_home_dir(), ".cache", "wsha")
    os.makedirs(cache_dir, exist_ok=True)
    return os.path.join(cache_dir, "wsha.cache.json")


def get_config_cache_key() -> str:
    """Build a cache key from every effective config source."""
    _, _, app_config = get_app_env()
    builtin_dir = os.path.join(app_config, "wsh-alias")
    user_dir = os.path.join(get_home_dir(), ".config", "wsh-alias")
    local_dir = os.path.join(os.getcwd(), ".config", "wsh-alias")

    stamps = [f"cwd={os.getcwd()}", f"home={get_home_dir()}"]
    for dir_path in (builtin_dir, user_dir, local_dir):
        stamps.append(f"dir={dir_path}")
        if not os.path.isdir(dir_path):
            stamps.append("missing")
            continue
        for f in sorted(os.listdir(dir_path)):
            if f.endswith(".txt") and not f.startswith("_"):
                path = os.path.join(dir_path, f)
                try:
                    stat = os.stat(path)
                    stamps.append(f"{path}:{stat.st_mtime_ns}:{stat.st_size}")
                except OSError:
                    stamps.append(f"{path}:missing")

    return hashlib.md5("\n".join(stamps).encode()).hexdigest()


def load_alias_cache(expected_key: str) -> bool:
    cache_file = get_cache_file_path()
    if not os.path.exists(cache_file):
        return False

    try:
        stat = os.stat(cache_file)
        if time.time() - stat.st_mtime > CACHE_MAX_AGE:
            return False
        with open(cache_file, "r", encoding="utf-8") as f:
            data = json.load(f)
        if data.get("version") != CACHE_VERSION or data.get("key") != expected_key:
            return False

        global _aliases
        _aliases = [Alias.from_cache_item(item) for item in data.get("aliases", [])]
        rebuild_buckets()
        return True
    except (IOError, OSError, json.JSONDecodeError, TypeError, ValueError):
        return False


def save_alias_cache(cache_key: str) -> None:
    cache_file = get_cache_file_path()
    try:
        with open(cache_file, "w", encoding="utf-8") as f:
            json.dump(
                {
                    "version": CACHE_VERSION,
                    "key": cache_key,
                    "aliases": [alias.to_cache_item() for alias in _aliases],
                },
                f,
                ensure_ascii=False,
            )
    except IOError:
        pass


def load_config() -> bool:
    global _aliases, _alias_buckets, _alias_wildcard_first
    cache_key = get_config_cache_key()
    if load_alias_cache(cache_key):
        return True

    _aliases = []
    _alias_buckets = {}
    _alias_wildcard_first = []

    _, _, app_config = get_app_env()
    builtin_dir = os.path.join(app_config, "wsh-alias")
    user_dir = os.path.join(get_home_dir(), ".config", "wsh-alias")
    local_dir = os.path.join(os.getcwd(), ".config", "wsh-alias")

    if not load_config_dir(builtin_dir, "内置"):
        return False
    if not load_config_dir(user_dir, "用户"):
        return False
    if not load_config_dir(local_dir, "项目"):
        return False

    save_alias_cache(cache_key)
    return True


def load_config_single(config_path: str) -> bool:
    global _aliases, _alias_buckets, _alias_wildcard_first
    _aliases = []
    _alias_buckets = {}
    _alias_wildcard_first = []
    return load_single_config_file(config_path, "自定义", True)


def print_help() -> None:
    print(
        """wsha-core - alias command launcher

Usage:
  wsha-core <alias> [args...]
  wsha-core --list | -l | --list-view | -lv
  wsha-core --clear | --cache-clear

Rules:
  - Single-line aliases keep $1..$N / $$ placeholders and %VAR% expansion
  - Block aliases use triple-quoted runner blocks and [[1]] / [[...]] placeholders
  - Block runners: bash, sh, cmd, bat, pwsh, powershell
"""
    )


def clear_cache() -> int:
    cache_dir = os.path.join(get_home_dir(), ".cache", "wsha")
    if not os.path.exists(cache_dir):
        print("[wsha-core] cache directory does not exist")
        return 0

    removed = 0
    for root, _dirs, files in os.walk(cache_dir):
        for filename in files:
            path = os.path.join(root, filename)
            try:
                os.remove(path)
                removed += 1
            except OSError:
                pass
    print(f"[wsha-core] cleared {removed} cache file(s)")
    return 0


def parse_cli_args(argv: List[str]) -> Tuple[bool, bool, bool, str, Optional[str], List[str]]:
    """Parse top-level options while preserving alias runtime arguments verbatim."""
    show_help_flag = False
    list_flag = False
    clear_flag = False
    entry = WSHA_ENTRY
    alias = None
    args: List[str] = []

    i = 0
    while i < len(argv):
        token = argv[i]
        if alias is not None:
            args = argv[i:]
            break

        if token in ("-e", "--entry"):
            if i + 1 >= len(argv):
                print("[wsha] missing value for --entry.", file=sys.stderr)
                return False, False, False, entry, None, []
            entry = argv[i + 1]
            i += 2
            continue
        if token.startswith("--entry="):
            entry = token.split("=", 1)[1]
            i += 1
            continue
        if token in ("-h", "--help"):
            show_help_flag = True
            i += 1
            continue
        if token in ("-l", "--list", "-lv", "--list-view"):
            list_flag = True
            i += 1
            continue
        if token in ("--clear", "--cache-clear"):
            clear_flag = True
            i += 1
            continue

        alias = token
        args = argv[i + 1 :]
        break

    return show_help_flag, list_flag, clear_flag, entry, alias, args


def match_token_pattern(pattern: str, token: str) -> Tuple[bool, List[str], int]:
    if "*" not in pattern:
        return (pattern.lower() == token.lower(), [], 0)

    parts = pattern.split("*")
    regex_parts: List[str] = []
    wildcard_count = 0
    for i, part in enumerate(parts):
        if part:
            regex_parts.append(re.escape(part))
        if i < len(parts) - 1:
            regex_parts.append("(.*)")
            wildcard_count += 1

    match = re.match("^" + "".join(regex_parts) + "$", token, re.IGNORECASE)
    if match:
        return True, list(match.groups()), wildcard_count
    return False, [], wildcard_count


def match_double_star_remainder(pattern: str, input_text: str) -> Tuple[bool, List[str], str]:
    if "**" not in pattern:
        return False, [], ""

    idx = pattern.index("**")
    head = pattern[:idx]
    tail = pattern[idx + 2 :]

    def build_glob_regex(part: str) -> str:
        return re.escape(part).replace(r"\*", "(.*)") if part else ""

    full_regex = f"^{build_glob_regex(head)}(.*){build_glob_regex(tail)}$"
    match = re.match(full_regex, input_text, re.IGNORECASE)
    if match:
        groups = list(match.groups())
        if groups:
            return True, groups[:-1], groups[-1]
    return False, [], ""


def find_best_match(input_tokens: List[str]) -> Tuple[str, str, List[str], str, int, Optional[Alias]]:
    if not input_tokens:
        return "", "", [], "", 0, None

    input_count = len(input_tokens)
    first_lower = input_tokens[0].lower()
    candidates: List[int] = []
    if first_lower in _alias_buckets:
        candidates.extend(_alias_buckets[first_lower])
    candidates.extend(_alias_wildcard_first)

    best_alias: Optional[Alias] = None
    best_template = ""
    best_captures: List[str] = []
    best_rest_capture = ""
    best_args_start = 0
    best_score = -1

    for idx in candidates:
        alias = _aliases[idx]
        if alias.double_index == -2:
            continue
        if alias.double_index < 0 and input_count < alias.token_count:
            continue
        if alias.double_index >= 0 and input_count < alias.double_index + 1:
            continue
        if alias.double_index >= 0 and alias.double_index != alias.token_count - 1:
            continue

        ok = True
        captures: List[str] = []
        rest_capture = ""
        input_consumed = 0
        wildcard_count = 0

        for ti in range(alias.token_count):
            if ti == alias.double_index:
                remain_text = " ".join(input_tokens[ti:])
                matched, dc, rest = match_double_star_remainder(alias.tokens[ti], remain_text)
                if not matched or not rest:
                    ok = False
                    break
                captures.extend(dc)
                rest_capture = rest
                wildcard_count += 1000
                input_consumed = input_count
                continue

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
        return best_alias.key, best_template, best_captures, best_rest_capture, best_args_start, best_alias
    return "", "", [], "", 0, None


def find_empty_dstar_warning(input_tokens: List[str]) -> Optional[str]:
    """最终无命中时，提示同首 token 的 ** 候选需要非空捕获。"""
    if not input_tokens:
        return None
    first_lower = input_tokens[0].lower()
    candidates = list(_alias_buckets.get(first_lower, [])) + list(_alias_wildcard_first)
    for idx in candidates:
        alias = _aliases[idx]
        if alias.double_index < 0:
            continue
        if len(input_tokens) < alias.double_index + 1:
            return f'alias "{alias.key}" requires non-empty ** capture'
        if alias.double_index != alias.token_count - 1:
            continue

        ok = True
        for ti in range(alias.double_index):
            matched, _mc, _wc = match_token_pattern(alias.tokens[ti], input_tokens[ti])
            if not matched:
                ok = False
                break
        if not ok:
            continue

        remain_text = " ".join(input_tokens[alias.double_index:])
        matched, _captures, rest = match_double_star_remainder(alias.tokens[alias.double_index], remain_text)
        if matched and rest == "":
            return f'alias "{alias.key}" requires non-empty ** capture'
    return None


def expand_template_tokens(template: str, captures: List[str], rest_capture: str, runtime_args: List[str]) -> List[str]:
    result = expand_env_vars(template)
    for i in range(len(captures) - 1, -1, -1):
        result = result.replace(f"${i + 1}", captures[i])
    result = result.replace("$$", rest_capture)

    tokens = tokenize(result)
    final_tokens: List[str] = []
    placeholder_used = False
    for token in tokens:
        # `$@` 是 wsha 的 argv 插入点；`--` 保留给目标 CLI 作为真实 option terminator。
        if token == "$@":
            placeholder_used = True
            final_tokens.extend(runtime_args)
        else:
            final_tokens.append(token)
    if not placeholder_used and runtime_args:
        final_tokens.extend(runtime_args)
    return final_tokens


def template_starts_recursive_alias(template: str) -> bool:
    """Only recurse when the alias author explicitly starts the template with w/wsha."""
    tokens = tokenize(expand_env_vars(template))
    if not tokens:
        return False

    first = tokens[0]
    if "$" in first or "[[" in first or "]]" in first:
        return False
    return token_basename_lower(first) in RECURSIVE_ALIAS_COMMANDS


def expand_env_vars(text: str) -> str:
    result = text
    pattern = re.compile(r"%([A-Za-z_][A-Za-z0-9_]*)%")
    while True:
        match = pattern.search(result)
        if not match:
            break
        var_name = match.group(1)
        var_value = os.environ.get(var_name, "")
        if is_git_bash_runtime() and var_name in {"APP_HOME", "APP_SH", "APP_CONFIG"}:
            var_value = to_display_path(var_value)
        result = result.replace(match.group(0), var_value)
    return result


def expand_block_body(template: str, captures: List[str], rest_capture: str) -> str:
    """展开 block 专用 [[1]] / [[...]] 占位符，不做 shell quoting。"""
    result = template
    for i in range(len(captures), 0, -1):
        result = result.replace(f"[[{i}]]", captures[i - 1])
    result = result.replace("[[...]]", rest_capture)
    return result


def normalize_windows_set_chain(text: str) -> str:
    if os.name != "nt":
        return text

    rest = text.lstrip()
    normalized_parts: List[str] = []
    while True:
        match = re.match(r"^set\s+([A-Za-z_][A-Za-z0-9_]*)=(.*?)\s*&&\s*(.*)$", rest, re.IGNORECASE)
        if not match:
            break
        env_name, env_value, next_rest = match.groups()
        normalized_parts.append(f'set "{env_name}={env_value.rstrip()}"')
        rest = next_rest.lstrip()

    if not normalized_parts:
        return text
    if rest:
        normalized_parts.append(rest)
    return " && ".join(normalized_parts)


def quote_cmd_token(token: str, always: bool = False) -> str:
    if token == "":
        return '""'
    needs_quote = always or bool(re.search(r'[\s&()^|<>"]', token))
    if not needs_quote:
        return token
    return '"' + token.replace('"', '""') + '"'


def quote_shell_token(token: str) -> str:
    if token == "":
        return "''"
    if re.search(r"[\s&()|<>;'\"`$]", token):
        return shlex.quote(token)
    return token


def join_output_tokens(tokens: List[str]) -> str:
    if CMDLINE_OUTPUT == "cmd":
        return " ".join(quote_cmd_token(t) for t in tokens)
    return " ".join(quote_shell_token(t) for t in tokens)


def join_plain_tokens(tokens: List[str]) -> str:
    if CMDLINE_OUTPUT == "cmd":
        return " ".join(quote_cmd_token(t) for t in tokens)
    return " ".join(quote_shell_token(t) for t in tokens)


def token_basename_lower(token: str) -> str:
    return token.replace("\\", "/").split("/")[-1].lower()


def is_git_bash_runtime() -> bool:
    return bool(os.environ.get("MSYSTEM") or os.environ.get("MINGW_PREFIX") or os.environ.get("OSTYPE", "").startswith("msys"))


def resolve_git_bash() -> str:
    candidates: List[str] = []
    env_bash = os.environ.get("GIT_BASH", "").strip('"')
    if env_bash:
        candidates.append(env_bash)

    for path_dir in os.environ.get("PATH", "").split(os.pathsep):
        if not path_dir:
            continue
        candidate = os.path.join(path_dir.strip('"'), "bash.exe")
        if "/git/" in candidate.replace("\\", "/").lower():
            candidates.append(candidate)

    program_files = os.environ.get("ProgramFiles", r"C:\Program Files")
    candidates.extend([
        os.path.join(program_files, "Git", "bin", "bash.exe"),
        os.path.join(program_files, "Git", "usr", "bin", "bash.exe"),
    ])
    for candidate in candidates:
        if os.path.exists(candidate):
            return candidate
    return ""


def is_complex_shell_command(text: str) -> bool:
    return any(c in text for c in ["&&", "||", "|", ";", ">", "<", "$(", "`"])


def normalize_runtime_tokens(tokens: List[str]) -> List[str]:
    if not tokens:
        return tokens

    result = list(tokens)
    first_lower = token_basename_lower(tokens[0])
    _app_home, app_sh, _app_config = get_app_env()
    core_dir = os.path.join(app_sh, "core")
    is_windows = os.name == "nt"

    if first_lower in ["wsha", "wsha.bat", "w", "w.bat", "wsh", "wsh.bat"]:
        if is_windows:
            if first_lower in ["wsha", "wsha.bat"]:
                result = [os.path.join(app_sh, "wsha.bat")] + result[1:]
            elif first_lower in ["w", "w.bat"]:
                result = [os.path.join(app_sh, "w.bat")] + result[1:]
            elif first_lower in ["wsh", "wsh.bat"]:
                if len(result) >= 2 and token_basename_lower(result[1]).endswith(".sh"):
                    script_path = result[1]
                    if not os.path.isabs(script_path) and not re.search(r"[\\/]", script_path):
                        script_path = os.path.join(app_sh, script_path)
                    git_bash = resolve_git_bash()
                    if git_bash:
                        result = [git_bash, script_path] + result[2:]
                    else:
                        result = [os.path.join(core_dir, "exec-git-bash.bat"), script_path] + result[2:]
                else:
                    if CMDLINE_OUTPUT == "cmd":
                        # wsh.bat 会把命令拼成 `bash -lc "..."`，嵌套引号容易破坏 `$prompt` 等字面量。
                        # 这里直接进入 Git Bash launcher，并用 shell quoting 生成单个 -lc 命令。
                        bash_cmd = " ".join(quote_shell_token(t) for t in result[1:])
                        result = [os.path.join(core_dir, "exec-git-bash.bat"), "-lc", bash_cmd]
                    else:
                        result = [os.path.join(app_sh, "wsh.bat")] + result[1:]
        else:
            if first_lower in ["wsha", "wsha.bat"]:
                result = ["bash", os.path.join(app_sh, "wsha.sh")] + result[1:]
            elif first_lower in ["w", "w.bat"]:
                result = ["env", "WSHA_ENTRY=w", "bash", os.path.join(app_sh, "wsha.sh")] + result[1:]
            elif first_lower in ["wsh", "wsh.bat"]:
                if len(result) >= 2 and token_basename_lower(result[1]).endswith(".sh"):
                    script_path = result[1]
                    if not os.path.isabs(script_path) and not re.search(r"[\\/]", script_path):
                        script_path = os.path.join(app_sh, script_path)
                    result = ["bash", script_path] + result[2:]
                elif len(result) >= 2 and result[1] == ".":
                    result = ["/usr/bin/bash", "-i"]
                else:
                    result = result[1:]

    first_lower = token_basename_lower(result[0])
    if first_lower in ["docker", "podman"]:
        result = ["env", "MSYS_NO_PATHCONV=1", "MSYS2_ARG_CONV_EXCL=*"] + result
    return result


def warning(message: str) -> None:
    text = f"[wsha] warning: {message}"
    if sys.stderr.isatty():
        print(f"\033[33m{text}\033[0m", file=sys.stderr)
    else:
        print(text, file=sys.stderr)


def error(message: str) -> None:
    print(f"[wsha] error: {message}", file=sys.stderr)


def block_cache_enabled() -> bool:
    return os.environ.get("WSHA_BLOCK_CACHE", "1") != "0" and os.environ.get("WSHA_BLOCK_NO_CACHE", "") != "1"


def get_block_cache_dir() -> str:
    return os.path.join(get_home_dir(), ".cache", "wsha", "blocks")


def runner_ext(runner: str) -> str:
    if runner in ("bash", "sh"):
        return ".sh"
    if runner in ("cmd", "bat"):
        return ".cmd"
    return ".ps1"


def script_header(alias: Alias, runner: str) -> str:
    source = f"{alias.config_path}:{alias.line_no}" if alias.line_no else alias.config_path
    if runner in ("cmd", "bat"):
        return "\n".join([
            "@echo off",
            "REM generated by wsha",
            f"REM alias: {alias.key}",
            f"REM runner: {runner}",
            f"REM source: {source}",
        ])
    shebang = "#!/usr/bin/env sh" if runner == "sh" else "#!/usr/bin/env bash"
    if runner in ("bash", "sh"):
        return "\n".join([
            shebang,
            "# generated by wsha",
            f"# alias: {alias.key}",
            f"# runner: {runner}",
            f"# source: {source}",
        ])
    return "\n".join([
        "# generated by wsha",
        f"# alias: {alias.key}",
        f"# runner: {runner}",
        f"# source: {source}",
    ])


def write_block_script(alias: Alias, runner: str, body: str) -> str:
    ext = runner_ext(runner)
    content = script_header(alias, runner) + "\n" + body.rstrip("\n") + "\n"
    digest = hashlib.sha256((runner + "\n" + content).encode("utf-8")).hexdigest()[:24]

    if block_cache_enabled():
        block_dir = get_block_cache_dir()
        os.makedirs(block_dir, exist_ok=True)
        script_path = os.path.join(block_dir, digest + ext)
    else:
        fd, script_path = tempfile.mkstemp(prefix="wsha-block-", suffix=ext)
        os.close(fd)

    with open(script_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)
    try:
        os.chmod(script_path, 0o700)
    except OSError:
        pass
    return script_path


def resolve_runner_command(runner: str) -> Optional[str]:
    if runner in ("bash", "sh"):
        if not is_git_bash_runtime() and os.name == "nt" and runner == "bash":
            return resolve_git_bash() or shutil.which("bash")
        return shutil.which(runner)
    if runner in ("cmd", "bat"):
        if os.name != "nt":
            return None
        return os.environ.get("COMSPEC") or "cmd.exe"
    if runner in ("pwsh", "powershell"):
        return shutil.which(runner)
    return None


def block_command(alias: Alias, body: str) -> Optional[str]:
    runner = alias.block_runner
    if body.strip() == "":
        warning(f'block alias "{alias.key}" is empty; nothing to execute')
        return "__WSHA_NOOP__"

    runner_cmd = resolve_runner_command(runner)
    if not runner_cmd:
        error(f'runner "{runner}" not found or unsupported on this platform')
        return None

    script_path = write_block_script(alias, runner, body)
    if runner in ("bash", "sh"):
        tokens = [to_shell_path(runner_cmd), to_shell_path(script_path)]
    elif runner in ("cmd", "bat"):
        if CMDLINE_OUTPUT == "sh":
            tokens = [to_shell_path(runner_cmd), "/c", quote_cmd_token(script_path, always=True)]
        else:
            tokens = [runner_cmd, "/c", script_path]
    else:
        if CMDLINE_OUTPUT == "sh":
            tokens = [to_shell_path(runner_cmd), "-NoProfile", "-File", quote_cmd_token(script_path, always=True)]
        else:
            tokens = [runner_cmd, "-NoProfile", "-File", script_path]
    return join_output_tokens(tokens)


def to_shell_path(path: str) -> str:
    if CMDLINE_OUTPUT == "cmd":
        return path
    if path.endswith(".exe") or path.endswith(".EXE"):
        normalized = path.replace("\\", "/")
        if "/Git/" in normalized or "/git/" in normalized:
            return normalized
    if re.match(r"^[A-Za-z]:[\\/]", path):
        drive = path[0].lower()
        rest = path[2:].replace("\\", "/")
        return f"/{drive}{rest}"
    return path


def to_display_path(path: str) -> str:
    if re.match(r"^[A-Za-z]:[\\/]", path):
        return to_shell_path(path)
    return path


def template_display(alias: Alias) -> str:
    if not alias.is_block:
        return alias.template
    meaningful = [line for line in alias.template.splitlines() if line.strip()]
    if not meaningful:
        return f"<{alias.block_runner} block: empty>"
    suffix = "line" if len(meaningful) == 1 else "lines"
    return f"<{alias.block_runner} block: {len(meaningful)} {suffix}>"


def list_aliases() -> int:
    if not _aliases:
        load_config()
    if not _aliases:
        print("[wsha] no alias found.")
        return 0

    force_table = os.environ.get("WSHA_FORCE_TABLE_LIST", "") == "1"
    wrapper_stdout_tty = os.environ.get("WSHA_STDOUT_IS_TTY", "") == "1"
    if force_table or wrapper_stdout_tty or sys.stdout.isatty():
        entries = [
            AliasListEntry(alias.key, template_display(alias), classify_alias(alias.key, alias.is_block))
            for alias in _aliases
        ]
        width_text = os.environ.get("WSHA_TABLE_WIDTH", "")
        width = int(width_text) if width_text.isdigit() else None
        print(render_alias_table(entries, width=width))
        return 0

    groups: Dict[str, Dict[str, object]] = {}
    for alias in _aliases:
        groups.setdefault(alias.config_path, {"source": alias.source_name, "aliases": []})
        groups[alias.config_path]["aliases"].append(alias)  # type: ignore[index]

    for config_path, group in groups.items():
        display_path = config_path if group["source"] == "自定义" else os.path.dirname(config_path)
        display_path = to_display_path(display_path)
        print(f"[{group['source']}] {display_path}")
        print()
        print("  别名  命令")
        for alias in group["aliases"]:  # type: ignore[assignment]
            print(f"  {alias.key}  {template_display(alias)}")
        print()
    return 0


def resolve_alias_tokens(input_tokens: List[str]) -> Optional[List[str]]:
    """在 Python core 内递归展开 wsha/w alias，避免 Windows batch 多层重入破坏 argv 引号。"""
    current_tokens = list(input_tokens)
    for _depth in range(MAX_ALIAS_DEPTH):
        alias_key, template, captures, rest_capture, args_start, alias = find_best_match(current_tokens)
        if not alias_key or alias is None:
            dstar_warning = find_empty_dstar_warning(current_tokens)
            if dstar_warning:
                warning(dstar_warning)
            return current_tokens

        runtime_args = current_tokens[args_start:] if args_start < len(current_tokens) else []
        if alias.is_block:
            if runtime_args:
                warning(f'block alias "{alias.key}" ignores extra args: {" ".join(runtime_args)}')
            body = expand_block_body(template, captures, rest_capture)
            cmd = block_command(alias, body)
            if cmd is None:
                return None
            return [cmd]

        final_tokens = expand_template_tokens(template, captures, rest_capture, runtime_args)
        if final_tokens and template_starts_recursive_alias(template):
            current_tokens = final_tokens[1:]
            continue
        return final_tokens

    error(f"alias recursion exceeded {MAX_ALIAS_DEPTH} levels")
    return None


def main() -> int:
    show_help_flag, list_flag, clear_flag, _entry, alias_input, args = parse_cli_args(sys.argv[1:])

    if show_help_flag:
        print_help()
        return 0
    if clear_flag:
        return clear_cache()

    single_config = os.environ.get("WSHA_CONFIG_FILE", "")
    if single_config:
        if not load_config_single(single_config):
            return 1
    else:
        if not load_config():
            return 1

    if list_flag:
        return list_aliases()

    if not alias_input:
        print("[wsha] missing alias.", file=sys.stderr)
        return 1

    input_tokens = [alias_input] + args
    if len(input_tokens) == 1 and " " in input_tokens[0]:
        input_tokens = input_tokens[0].split()

    final_tokens = resolve_alias_tokens(input_tokens)
    if final_tokens is None:
        return 1

    final_cmd = " ".join(final_tokens)
    final_cmd = normalize_windows_set_chain(final_cmd)
    if is_complex_shell_command(final_cmd) or (len(final_tokens) == 1 and (final_tokens[0] == "__WSHA_NOOP__" or re.search(r"\s", final_tokens[0]))):
        print(final_cmd)
    else:
        normalized = normalize_runtime_tokens(final_tokens)
        print(join_plain_tokens(normalized))
    return 0


if __name__ == "__main__":
    sys.exit(main())
