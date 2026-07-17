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
from dataclasses import dataclass, asdict, field
from typing import Dict, List, Mapping, Optional, Tuple

PY_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "py"))
if PY_DIR not in sys.path:
    sys.path.insert(0, PY_DIR)

try:
    from wsha.list_table import AliasListEntry, classify_alias, render_alias_table
except ModuleNotFoundError:
    # 安装运行时仅复制 sh/；缺少仓库开发包时保留可用的纯文本列表能力。
    @dataclass
    class AliasListEntry:
        name: str
        template: str
        kind: str


    def classify_alias(name: str, is_block: bool) -> str:
        return "block" if is_block else "alias"


    def render_alias_table(entries: List[AliasListEntry], width: Optional[int] = None) -> str:
        del width
        name_width = max([len("别名")] + [len(entry.name) for entry in entries])
        lines = [f"{'别名':<{name_width}}  命令", f"{'-' * name_width}  ----"]
        lines.extend(f"{entry.name:<{name_width}}  {entry.template}" for entry in entries)
        return "\n".join(lines)

WSHA_ENTRY = os.environ.get("WSHA_ENTRY", "wsha")
CACHE_MAX_AGE = 300  # 5 minutes
CACHE_VERSION = "v5"
CMDLINE_OUTPUT = os.environ.get("WSHA_CMDLINE_OUTPUT", "")
VALID_BLOCK_RUNNERS = {"bash", "sh", "cmd", "bat", "pwsh", "powershell"}
RECURSIVE_ALIAS_COMMANDS = {"wsha", "wsha.bat", "w", "w.bat"}
MAX_ALIAS_DEPTH = 16
ENV_ASSIGNMENT_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)=(.*)$", re.DOTALL)
ENV_REFERENCE_RE = re.compile(
    r"%([A-Za-z_][A-Za-z0-9_]*)%"
    r"|\$\{env:([A-Za-z_][A-Za-z0-9_]*)\}"
    r"|\$env:([A-Za-z_][A-Za-z0-9_]*)"
    r"|\$\{([A-Za-z_][A-Za-z0-9_]*)\}"
    r"|\$([A-Za-z_][A-Za-z0-9_]*)",
    re.IGNORECASE,
)
URI_RE = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*://")


class EnvResolutionError(ValueError):
    """Raised when strict environment expansion cannot resolve a variable."""


@dataclass
class CliRequest:
    """Top-level wsha request after management options and env prefixes are parsed."""

    show_help: bool = False
    list_aliases: bool = False
    clear_cache: bool = False
    entry: str = WSHA_ENTRY
    alias: Optional[str] = None
    args: List[str] = field(default_factory=list)
    env_assignments: List[Tuple[str, str]] = field(default_factory=list)
    valid: bool = True
    error_message: str = ""


@dataclass
class ResolvedCommand:
    """Final command tokens plus whether a block runner already owns env setup."""

    tokens: List[str]
    env_handled_by_runner: bool = False
    env_assignments: List[Tuple[str, str]] = field(default_factory=list)


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
    """将文本解析为 token 数组，保留配置中引号包裹的整体参数。"""
    if not text:
        return []
    try:
        return shlex.split(text, posix=True)
    except ValueError:
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
  wsha-core -e|--env KEY=VALUE... <alias> [args...]
  wsha-core --list | -l | --list-view | -lv
  wsha-core --clear | --cache-clear

Rules:
  - Single-line aliases keep $1..$N / $$ placeholders and %VAR% expansion
  - Block aliases use triple-quoted runner blocks and [[1]] / [[...]] placeholders
  - Block runners: bash, sh, cmd, bat, pwsh, powershell
  - --env variables apply only to the invoked command
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


def parse_env_assignment(token: str) -> Optional[Tuple[str, str]]:
    """Parse one KEY=VALUE token without stripping spaces from VALUE."""
    match = ENV_ASSIGNMENT_RE.match(token)
    if not match:
        return None
    return match.group(1), match.group(2)


def parse_cli_args(argv: List[str]) -> CliRequest:
    """Parse top-level options while preserving alias runtime arguments verbatim."""
    request = CliRequest()

    i = 0
    while i < len(argv):
        token = argv[i]
        if request.alias is not None:
            request.args = argv[i:]
            break

        if token == "--entry":
            if i + 1 >= len(argv):
                request.valid = False
                request.error_message = "missing value for --entry"
                return request
            request.entry = argv[i + 1]
            i += 2
            continue
        if token.startswith("--entry="):
            request.entry = token.split("=", 1)[1]
            i += 1
            continue
        if token in ("-e", "--env") or token.startswith("--env="):
            parsed_count = 0
            if token.startswith("--env="):
                parsed = parse_env_assignment(token.split("=", 1)[1])
                if parsed is None:
                    request.valid = False
                    request.error_message = "--env requires KEY=VALUE"
                    return request
                request.env_assignments.append(parsed)
                parsed_count = 1
                i += 1
            else:
                i += 1

            while i < len(argv):
                parsed = parse_env_assignment(argv[i])
                if parsed is None:
                    break
                request.env_assignments.append(parsed)
                parsed_count += 1
                i += 1

            if parsed_count == 0:
                request.valid = False
                request.error_message = "-e/--env requires at least one KEY=VALUE assignment"
                return request
            if i >= len(argv):
                request.valid = False
                request.error_message = "-e/--env requires a command after assignments"
                return request
            request.alias = argv[i]
            request.args = argv[i + 1 :]
            break
        if token in ("-h", "--help"):
            request.show_help = True
            i += 1
            continue
        if token in ("-l", "--list", "-lv", "--list-view"):
            request.list_aliases = True
            i += 1
            continue
        if token in ("--clear", "--cache-clear"):
            request.clear_cache = True
            i += 1
            continue

        request.alias = token
        request.args = argv[i + 1 :]
        break

    return request


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
        if var_name in {"APP_HOME", "APP_SH", "APP_CONFIG"}:
            var_value = to_display_path(var_value)
        result = result.replace(match.group(0), var_value)
    return result


def lookup_env_value(env: Mapping[str, str], name: str) -> Optional[str]:
    """Read an environment variable, including Windows-style case-insensitive lookup."""
    if name in env:
        return env[name]
    wanted = name.lower()
    for key, value in env.items():
        if key.lower() == wanted:
            return value
    return None


def expand_environment_references(text: str, env: Mapping[str, str], strict: bool) -> str:
    """Expand %VAR%, $VAR, ${VAR} and PowerShell env references in one token."""
    def replace(match: re.Match[str]) -> str:
        name = next(group for group in match.groups() if group is not None)
        value = lookup_env_value(env, name)
        if value is None:
            if strict:
                raise EnvResolutionError(f"undefined environment variable: {name}")
            return match.group(0)
        return value

    return ENV_REFERENCE_RE.sub(replace, text)


def home_dir_from_env(env: Mapping[str, str]) -> str:
    """Resolve the user home from the supplied environment without mutating it."""
    return (
        lookup_env_value(env, "USERPROFILE")
        or lookup_env_value(env, "HOME")
        or (lookup_env_value(env, "HOMEDRIVE") or "") + (lookup_env_value(env, "HOMEPATH") or "")
        or os.path.expanduser("~")
    )


def expand_home_path(value: str, env: Mapping[str, str]) -> str:
    """Expand only a leading user-home marker; keep embedded tildes literal."""
    if value == "~":
        return home_dir_from_env(env)
    if value.startswith("~/") or value.startswith("~\\"):
        return home_dir_from_env(env) + value[1:]
    return value


def is_local_path_candidate(value: str, cwd: Optional[str] = None) -> bool:
    """Conservatively identify local paths while preserving refs, package names and URIs."""
    if not value or URI_RE.match(value):
        return False
    if re.match(r"^[A-Za-z]:[\\/]", value):
        return True
    if value.startswith("\\\\") or value.startswith("//"):
        return True
    if value.startswith(("./", ".\\", "../", "..\\")) or "\\" in value:
        return True
    candidate = value if cwd is None else os.path.join(cwd, value)
    return os.path.exists(candidate)


def adapt_local_path(value: str, target_shell: str, cwd: Optional[str] = None) -> str:
    """Adapt confirmed local paths for Git Bash, CMD or PowerShell without touching URIs."""
    if not is_local_path_candidate(value, cwd):
        return value

    if target_shell == "git-bash":
        if re.match(r"^[A-Za-z]:[\\/]", value):
            tail = value[2:].replace("\\", "/")
            return f"/{value[0].lower()}{tail}"
        if value.startswith("\\\\"):
            return "//" + value[2:].replace("\\", "/")
        return value.replace("\\", "/")

    if target_shell in {"cmd", "powershell"}:
        git_bash_drive = re.match(r"^/([A-Za-z])/(.*)$", value)
        if git_bash_drive:
            tail = git_bash_drive.group(2).replace("/", "\\")
            return f"{git_bash_drive.group(1).upper()}:\\{tail}"
        if value.startswith("//"):
            return "\\\\" + value[2:].replace("/", "\\")
        return value.replace("/", "\\")

    return value.replace("\\", "/") if "\\" in value else value


def resolve_env_assignments(
    assignments: List[Tuple[str, str]],
    current_env: Mapping[str, str],
    target_shell: str,
    cwd: Optional[str] = None,
) -> Tuple[List[Tuple[str, str]], Dict[str, str]]:
    """Resolve assignments left-to-right, so later values may reference earlier ones."""
    effective_env = dict(current_env)
    rendered: List[Tuple[str, str]] = []
    for name, raw_value in assignments:
        resolved_value = expand_environment_references(raw_value, effective_env, strict=True)
        resolved_value = expand_home_path(resolved_value, effective_env)
        effective_env[name] = resolved_value
        rendered.append((name, adapt_local_path(resolved_value, target_shell, cwd)))
    return rendered, effective_env


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


def output_shell() -> str:
    """Return the shell syntax expected by the active public wrapper."""
    mode = CMDLINE_OUTPUT.lower()
    if mode in {"powershell", "pwsh", "ps"}:
        return "powershell"
    if mode == "cmd":
        return "cmd"
    if mode in {"sh", "bash", "git-bash"} and is_git_bash_runtime():
        return "git-bash"
    return "bash"


def render_env_command(assignments: List[Tuple[str, str]], command: str, target_shell: str) -> str:
    """Prefix one command with temporary environment assignments for its shell."""
    if not assignments:
        return command
    if target_shell == "cmd":
        prefixes = [f'set "{name}={value.replace(chr(34), chr(34) * 2)}"' for name, value in assignments]
        return " && ".join(prefixes + [command])
    if target_shell == "powershell":
        prefixes = [f"$env:{name}='{value.replace(chr(39), chr(39) * 2)}'" for name, value in assignments]
        return "; ".join(prefixes + [command])
    prefixes = [f"{name}={shlex.quote(value)}" for name, value in assignments]
    return " ".join(prefixes + [command])


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


def target_shell_for_runner(runner: str) -> str:
    if runner in ("cmd", "bat"):
        return "cmd"
    if runner in ("pwsh", "powershell"):
        return "powershell"
    return "git-bash" if is_git_bash_runtime() else "bash"


def block_env_prelude(assignments: List[Tuple[str, str]], target_shell: str) -> str:
    """Render setup lines inside the script owned by an explicit block runner."""
    if target_shell == "cmd":
        return "\n".join(f'set "{name}={value.replace(chr(34), chr(34) * 2)}"' for name, value in assignments)
    if target_shell == "powershell":
        return "\n".join(f"$env:{name}='{value.replace(chr(39), chr(39) * 2)}'" for name, value in assignments)
    return "\n".join(f"export {name}={shlex.quote(value)}" for name, value in assignments)


def block_command(
    alias: Alias,
    body: str,
    env_assignments: Optional[List[Tuple[str, str]]] = None,
    current_env: Optional[Mapping[str, str]] = None,
) -> Optional[str]:
    runner = alias.block_runner
    if body.strip() == "":
        warning(f'block alias "{alias.key}" is empty; nothing to execute')
        return "__WSHA_NOOP__"

    runner_cmd = resolve_runner_command(runner)
    if not runner_cmd:
        error(f'runner "{runner}" not found or unsupported on this platform')
        return None

    if env_assignments:
        rendered, _effective = resolve_env_assignments(
            env_assignments,
            current_env or os.environ,
            target_shell_for_runner(runner),
            os.getcwd(),
        )
        body = block_env_prelude(rendered, target_shell_for_runner(runner)) + "\n" + body

    script_path = write_block_script(alias, runner, body)
    if runner in ("bash", "sh"):
        tokens = [to_shell_path(runner_cmd), to_shell_path(script_path)]
    elif runner in ("cmd", "bat"):
        if CMDLINE_OUTPUT == "sh":
            command_text = f"call {script_path}"
            tokens = [to_shell_path(runner_cmd), "/d", "/s", "/c", command_text]
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
        drive = path[0].lower()
        rest = path[2:].replace("\\", "/")
        return f"/{drive}{rest}"
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


def resolve_alias_tokens(
    input_tokens: List[str],
    env_assignments: Optional[List[Tuple[str, str]]] = None,
) -> Optional[ResolvedCommand]:
    """在 Python core 内递归展开 wsha/w alias，避免 Windows batch 多层重入破坏 argv 引号。"""
    current_tokens = list(input_tokens)
    collected_env_assignments = list(env_assignments or [])
    for _depth in range(MAX_ALIAS_DEPTH):
        alias_key, template, captures, rest_capture, args_start, alias = find_best_match(current_tokens)
        if not alias_key or alias is None:
            dstar_warning = find_empty_dstar_warning(current_tokens)
            if dstar_warning:
                warning(dstar_warning)
            return ResolvedCommand(current_tokens, env_assignments=collected_env_assignments)

        runtime_args = current_tokens[args_start:] if args_start < len(current_tokens) else []
        if alias.is_block:
            if runtime_args:
                warning(f'block alias "{alias.key}" ignores extra args: {" ".join(runtime_args)}')
            body = expand_block_body(template, captures, rest_capture)
            cmd = block_command(alias, body, collected_env_assignments)
            if cmd is None:
                return None
            return ResolvedCommand([cmd], bool(collected_env_assignments), collected_env_assignments)

        final_tokens = expand_template_tokens(template, captures, rest_capture, runtime_args)
        if final_tokens and template_starts_recursive_alias(template):
            recursive_tokens = final_tokens[1:]
            if recursive_tokens and (
                recursive_tokens[0] in ("-e", "--env")
                or recursive_tokens[0].startswith("--env=")
            ):
                nested_request = parse_cli_args(recursive_tokens)
                if not nested_request.valid:
                    error(nested_request.error_message)
                    return None
                collected_env_assignments.extend(nested_request.env_assignments)
                if not nested_request.alias:
                    error("recursive wsha --env requires a command")
                    return None
                current_tokens = [nested_request.alias] + nested_request.args
            else:
                current_tokens = recursive_tokens
            continue
        return ResolvedCommand(final_tokens, env_assignments=collected_env_assignments)

    error(f"alias recursion exceeded {MAX_ALIAS_DEPTH} levels")
    return None


def main() -> int:
    request = parse_cli_args(sys.argv[1:])
    if not request.valid:
        error(request.error_message)
        return 2

    if request.show_help:
        print_help()
        return 0
    if request.clear_cache:
        return clear_cache()

    single_config = os.environ.get("WSHA_CONFIG_FILE", "")
    if single_config:
        if not load_config_single(single_config):
            return 1
    else:
        if not load_config():
            return 1

    if request.list_aliases:
        return list_aliases()

    if not request.alias:
        print("[wsha] missing alias.", file=sys.stderr)
        return 1

    input_tokens = [request.alias] + request.args
    if len(input_tokens) == 1 and " " in input_tokens[0]:
        input_tokens = input_tokens[0].split()

    resolved_command = resolve_alias_tokens(input_tokens, request.env_assignments)
    if resolved_command is None:
        return 1
    final_tokens = resolved_command.tokens

    effective_assignments = resolved_command.env_assignments
    rendered_assignments = [] if resolved_command.env_handled_by_runner else effective_assignments
    if effective_assignments and not resolved_command.env_handled_by_runner:
        try:
            rendered_assignments, effective_env = resolve_env_assignments(
                effective_assignments,
                os.environ,
                output_shell(),
                os.getcwd(),
            )
        except EnvResolutionError as exc:
            error(str(exc))
            return 2
        try:
            final_tokens = [
                adapt_local_path(
                    expand_home_path(
                        expand_environment_references(token, effective_env, strict=True),
                        effective_env,
                    ),
                    output_shell(),
                    os.getcwd(),
                )
                for token in final_tokens
            ]
        except EnvResolutionError as exc:
            error(str(exc))
            return 2

    final_cmd = " ".join(final_tokens)
    final_cmd = normalize_windows_set_chain(final_cmd)
    if is_complex_shell_command(final_cmd) or (len(final_tokens) == 1 and (final_tokens[0] == "__WSHA_NOOP__" or re.search(r"\s", final_tokens[0]))):
        print(render_env_command(rendered_assignments, final_cmd, output_shell()))
    else:
        normalized = normalize_runtime_tokens(final_tokens)
        command = join_plain_tokens(normalized)
        print(render_env_command(rendered_assignments, command, output_shell()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
