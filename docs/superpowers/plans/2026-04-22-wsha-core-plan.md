# wsha-core.py Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 创建 `sh/wsha-core.py`，将 wsha.sh 的核心逻辑移植到 Python 实现，支持配置加载、别名匹配、模板展开、缓存管理。

**Architecture:** 独立 Python CLI 模块，不依赖 py/wsha。通过 CLI 调用返回展开后的命令字符串供 shell 执行。支持 Windows Git Bash 特殊路径转换。

**Tech Stack:** Python 3.8+, 标准库（os, glob, hashlib, time, re）

---

## File Structure

```
sh/
├── wsha-core.py    # 新增：Python 核心实现（~800行）
├── wsha.sh         # 修改：调用 wsha-core.py
├── w.sh            # 修改：调用 wsha-core.py
└── w.bat           # 修改：调用 wsha-core.py

docs/superpowers/
├── specs/2026-04-22-wsha-core-design.md  # 已创建
└── plans/2026-04-22-wsha-core-plan.md    # 本计划
```

---

## Task 1: 创建 wsha-core.py CLI 入口和帮助系统

**Files:**
- Create: `sh/wsha-core.py`

- [ ] **Step 1: 创建 wsha-core.py 基础框架**

```python
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

def main():
    parser = argparse.ArgumentParser(
        prog="wsha-core",
        description="wsha alias command launcher core"
    )
    parser.add_argument("alias", nargs="?", help="alias name")
    parser.add_argument("args", nargs="*", help="additional arguments")
    parser.add_argument("--help", action="store_true", help="show help")
    parser.add_argument("-l", "--list", action="store_true", help="list all aliases")
    parser.add_argument("--clear", action="store_true", help="clear cache")
    parser.add_argument("-e", "--entry", default=WSHA_ENTRY, help="entry name")

    parsed = parser.parse_args()

    if parsed.help:
        print_help()
        return 0

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
```

- [ ] **Step 2: 添加 print_help 函数**

```python
def print_help():
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
```

- [ ] **Step 3: 添加 clear_cache 函数**

```python
def clear_cache():
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
```

- [ ] **Step 4: 添加 list_aliases 函数（空实现）**

```python
def list_aliases():
    print("[wsha-core] listing aliases...")
    return 0
```

- [ ] **Step 5: 测试帮助命令**

Run: `python sh/wsha-core.py --help`
Expected: 显示帮助信息

- [ ] **Step 6: 测试 clear 命令**

Run: `python sh/wsha-core.py --clear`
Expected: 清理缓存消息

- [ ] **Step 7: 提交**

```bash
git add sh/wsha-core.py
git commit -m "feat: add wsha-core.py CLI framework with help and clear commands"
```

---

## Task 2: 实现配置加载系统

**Files:**
- Modify: `sh/wsha-core.py`

- [ ] **Step 1: 添加配置加载相关的常量和数据结构**

```python
import re
from typing import List, Dict, Optional, Tuple

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
```

- [ ] **Step 2: 添加 tokenize 函数**

```python
def tokenize(text: str) -> List[str]:
    """将文本按空白分割为 token 数组"""
    if not text:
        return []
    # 禁用 glob 展开
    words = text.split()
    return [w for w in words if w]
```

- [ ] **Step 3: 添加配置解析函数**

```python
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
```

- [ ] **Step 4: 添加 load_config_dir 函数**

```python
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
                else:
                    _aliases.append(alias)
                    existing_idx = len(_aliases) - 1

                # 更新分桶
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
```

- [ ] **Step 5: 添加 load_config 主函数**

```python
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
```

- [ ] **Step 6: 测试配置加载**

Run: `python sh/wsha-core.py --list`
Expected: 应显示已加载的别名列表（目前为空实现）

- [ ] **Step 7: 实现 list_aliases 函数**

```python
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
```

- [ ] **Step 8: 再次测试 list 命令**

Run: `python sh/wsha-core.py --list`
Expected: 显示所有加载的别名

- [ ] **Step 9: 提交**

```bash
git add sh/wsha-core.py
git commit -m "feat: implement config loading system with alias metadata"
```

---

## Task 3: 实现别名匹配和模板展开

**Files:**
- Modify: `sh/wsha-core.py`

- [ ] **Step 1: 添加通配符匹配函数**

```python
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
    # 将 * 转换为 (.*?) 进行贪婪匹配
    regex = "^"
    remaining = pattern
    wildcard_count = 0

    while '*' in remaining:
        idx = remaining.index('*')
        before = remaining[:idx]
        # 转义正则特殊字符
        escaped_before = re.escape(before)
        regex += escaped_before
        if escaped_before:
            regex += ".*"  # 非通配符部分需要匹配任意字符
        remaining = remaining[idx + 1:]
        wildcard_count += 1

    # 追加剩余部分
    regex += re.escape(remaining) + "$"

    # 贪婪匹配
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

    # 构建正则：head 匹配前缀，tail 匹配后缀，捕获中间部分
    head_regex = re.escape(head).replace('\\*', '.*')
    tail_regex = re.escape(tail).replace('\\*', '.*')

    full_regex = f"^{head_regex}(.*?){tail_regex}$"
    full_regex = full_regex.replace('.*.*', '.*')

    match = re.match(full_regex, input_text, re.IGNORECASE)
    if match:
        return (True, list(match.groups()[:-1]), match.group(len(match.groups())))
    return (False, [], "")
```

- [ ] **Step 2: 添加 find_best_match 函数**

```python
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
                # ** 在最后
                if input_count < alias.token_count:
                    continue
            else:
                # ** 不在最后
                if input_count < alias.token_count:
                    continue
        else:
            # 无 **
            if input_count < alias.token_count:
                continue

        # 跳过多个 ** 的情况
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
                # ** 处理
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
                # 普通 token
                matched, mc, wc = match_token_pattern(alias.tokens[ti], input_tokens[ti])
                if not matched:
                    ok = False
                    break
                captures.extend(mc)
                wildcard_count += wc
                input_consumed = ti + 1

        if not ok:
            continue

        # 计算评分
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
```

- [ ] **Step 3: 添加 expand_template 函数**

```python
def expand_template(template: str, captures: List[str], rest_capture: str, runtime_args: List[str]) -> str:
    """展开模板中的变量"""
    result = template

    # 替换 $1..$N
    for i in range(len(captures) - 1, -1, -1):
        result = result.replace(f"${i + 1}", captures[i])

    # 替换 $$
    result = result.replace("$$", rest_capture)

    # 处理 -- 占位符
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
```

- [ ] **Step 4: 修改 main 函数实现完整逻辑**

```python
def main():
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
```

- [ ] **Step 5: 测试基本匹配**

Run: `python sh/wsha-core.py fox`
Expected: `firefox`

- [ ] **Step 6: 测试通配符匹配**

Run: `python sh/wsha-core.py "bu test arg"`
Expected: `uvx browser-use test arg`

- [ ] **Step 7: 测试透传**

Run: `python sh/wsha-core.py not-exist`
Expected: `not-exist`

- [ ] **Step 8: 提交**

```bash
git add sh/wsha-core.py
git commit -m "feat: implement alias matching and template expansion"
```

---

## Task 4: 实现缓存机制

**Files:**
- Modify: `sh/wsha-core.py`

- [ ] **Step 1: 添加缓存相关函数**

```python
import hashlib
import time

def get_cache_file_path() -> str:
    """获取缓存文件路径"""
    os.makedirs(CACHE_DIR, exist_ok=True)
    return os.path.join(CACHE_DIR, "wsha.cache")

def get_config_mtime_size() -> str:
    """获取配置目录的 mtime+size 用于缓存验证"""
    app_home, _, _ = get_app_env()
    builtin_dir = os.path.join(app_home, 'config', 'wsh-alias')

    mtimes = []
    if os.path.isdir(builtin_dir):
        for f in os.listdir(builtin_dir):
            if f.endswith('.txt') and not f.startswith('_'):
                path = os.path.join(builtin_dir, f)
                try:
                    stat = os.stat(path)
                    mtimes.append(f"{path}:{stat.st_mtime}:{stat.st_size}")
                except OSError:
                    pass

    mtimes.sort()
    content = ";".join(mtimes)
    return hashlib.md5(content.encode()).hexdigest()

def load_alias_cache() -> bool:
    """从缓存加载别名配置"""
    cache_file = get_cache_file_path()
    if not os.path.exists(cache_file):
        return False

    try:
        stat = os.stat(cache_file)
        if time.time() - stat.st_mtime > CACHE_MAX_AGE:
            return False

        with open(cache_file, 'r', encoding='utf-8') as f:
            lines = f.readlines()

        global _aliases, _alias_buckets, _alias_wildcard_first
        _aliases = []

        for line in lines:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            parts = line.split('\t')
            if len(parts) < 5:
                continue

            alias = Alias(parts[0], parts[1], parts[2], parts[3])
            alias.prefix_type = parts[4] if len(parts) > 4 else "normal"
            alias.build_metadata()

            _aliases.append(alias)
            update_buckets(len(_aliases) - 1, alias)

        return True

    except (IOError, OSError):
        return False

def save_alias_cache():
    """保存别名配置到缓存"""
    cache_file = get_cache_file_path()

    try:
        with open(cache_file, 'w', encoding='utf-8') as f:
            f.write("# wsha cache\n")
            for alias in _aliases:
                f.write(f"{alias.key}\t{alias.template}\t{alias.config_path}\t{alias.source_name}\t{alias.prefix_type}\n")
    except IOError:
        pass
```

- [ ] **Step 2: 修改 load_config 函数使用缓存**

```python
def load_config() -> bool:
    """加载所有配置（使用缓存）"""
    global _aliases, _alias_buckets, _alias_wildcard_first

    # 尝试从缓存加载
    if load_alias_cache():
        return True

    # 缓存不存在或过期，重新加载
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

    # 保存缓存
    save_alias_cache()

    return True
```

- [ ] **Step 3: 测试缓存过期**

Run: `python sh/wsha-core.py --list`
Expected: 正常加载配置

Run: `cat ~/.cache/wsha/wsha.cache`
Expected: 显示缓存内容

- [ ] **Step 4: 测试 --clear**

Run: `python sh/wsha-core.py --clear`
Expected: 清理缓存文件

- [ ] **Step 5: 提交**

```bash
git add sh/wsha-core.py
git commit -m "feat: add cache mechanism with 5-minute expiry and clear command"
```

---

## Task 5: 实现 token 规范化（Windows Git Bash 处理）

**Files:**
- Modify: `sh/wsha-core.py`

- [ ] **Step 1: 添加 token 规范化函数**

```python
def token_basename_lower(token: str) -> str:
    """获取 token 的 basename（忽略大小写）"""
    basename = token.replace('\\', '/').split('/')[-1]
    return basename.lower()

def is_complex_shell_command(text: str) -> bool:
    """判断是否为复杂 shell 命令"""
    complex_chars = ['&&', '||', '|', ';', '>', '<', '$(']
    for c in complex_chars:
        if c in text:
            return True
    return False

def normalize_runtime_tokens(tokens: List[str]) -> List[str]:
    """规范化运行时 token，处理 Windows Git Bash 特殊调用"""
    if not tokens:
        return tokens

    result = list(tokens)
    first_lower = token_basename_lower(tokens[0])

    # 处理 w.bat, wsha.bat, wsh.bat 等
    if first_lower in ['wsha.bat', 'w.bat', 'wsh.bat']:
        if first_lower == 'wsha.bat':
            result = ['bash', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'wsha.sh')] + result[1:]
        elif first_lower == 'w.bat':
            result = ['env', f'WSHA_ENTRY=w', 'bash', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'wsha.sh')] + result[1:]
        elif first_lower == 'wsh.bat':
            if len(result) >= 2 and result[1] == '.':
                result = ['/usr/bin/bash', '-i']
            else:
                result = result[1:]

    # 处理 Docker/Podman
    first_lower = token_basename_lower(result[0])
    if first_lower in ['docker', 'podman']:
        result = ['env', 'MSYS_NO_PATHCONV=1', 'MSYS2_ARG_CONV_EXCL=*'] + result

    return result
```

- [ ] **Step 2: 修改 main 函数在执行前调用 normalize**

```python
def main():
    # ... 保持现有逻辑 ...

    # 展开模板
    final_cmd = expand_template(template, captures, rest_capture, runtime_args)

    # 如果是复杂命令，不做 token 规范化
    if is_complex_shell_command(final_cmd):
        print(final_cmd)
    else:
        # token 规范化
        tokens = tokenize(final_cmd)
        normalized = normalize_runtime_tokens(tokens)
        print(" ".join(normalized))

    return 0
```

- [ ] **Step 3: 测试 token 规范化**

Run: `python sh/wsha-core.py tping`
Expected: 输出规范化后的命令

- [ ] **Step 4: 提交**

```bash
git add sh/wsha-core.py
git commit -m "feat: add token normalization for Windows Git Bash"
```

---

## Task 6: 实现 %VAR% 环境变量展开

**Files:**
- Modify: `sh/wsha-core.py`

- [ ] **Step 1: 添加环境变量展开函数**

```python
import os
import re

def expand_env_vars(text: str) -> str:
    """展开 %VAR% 风格的环境变量"""
    result = text

    # 匹配 %VAR_NAME%（字母数字下划线）
    pattern = re.compile(r'%([A-Za-z_][A-Za-z0-9_]*)%')

    while True:
        match = pattern.search(result)
        if not match:
            break

        var_name = match.group(1)
        var_value = os.environ.get(var_name, '')
        result = result.replace(match.group(0), var_value)

    return result
```

- [ ] **Step 2: 修改 expand_template 调用前展开环境变量**

```python
def main():
    # ... 保持现有逻辑 ...

    # 展开模板
    final_cmd = expand_template(template, captures, rest_capture, runtime_args)

    # 展开环境变量
    final_cmd = expand_env_vars(final_cmd)

    # 如果是复杂命令，不做 token 规范化
    # ...
```

- [ ] **Step 3: 测试环境变量展开**

Run: `python sh/wsha-core.py ev`
Expected: 输出 %EDITOR% 的值（如果设置了 EDITOR 环境变量则为实际值）

- [ ] **Step 4: 提交**

```bash
git add sh/wsha-core.py
git commit -m "feat: add %VAR% environment variable expansion"
```

---

## Task 7: 修改 wsha.sh 调用 wsha-core.py

**Files:**
- Modify: `sh/wsha.sh`

- [ ] **Step 1: 添加调用 wsha-core.py 的函数**

```bash
# 调用 wsha-core.py 获取展开后的命令
invoke_via_core() {
    local entry="$1"
    shift
    python "$APP_SH/wsha-core.py" -e "$entry" "$@"
}
```

- [ ] **Step 2: 修改 main 函数**

在 wsha.sh 的 main 函数中，将"查找最佳匹配→展开模板→执行"替换为调用 wsha-core.py。

```bash
# 原来的匹配和展开逻辑保持，但优先调用 wsha-core.py
# 如果 wsha-core.py 可用，使用它的结果

# 在 main 函数中添加：
# 调用 wsha-core.py
result=$(invoke_via_core "${WSHA_ENTRY:-wsha}" "$@")
if [[ -n "$result" ]]; then
    # 判断是否为透传（原样返回）还是展开结果
    if [[ "$result" == "$*" ]]; then
        # 透传，直接执行原始命令
        if is_complex_shell_command "$result"; then
            eval -- "$result"
        else
            invoke_cmd "$result"
        fi
    else
        # 展开后的命令，执行它
        invoke_cmd "$result"
    fi
fi
```

- [ ] **Step 3: 测试 wsha.sh 调用**

Run: `bash sh/wsha.sh fox`
Expected: 输出 `firefox`

- [ ] **Step 4: 提交**

```bash
git add sh/wsha.sh
git commit -m "refactor: wsha.sh calls wsha-core.py for alias expansion"
```

---

## Task 8: 修改 w.sh 和 w.bat

**Files:**
- Modify: `sh/w.sh`, `sh/w.bat`

- [ ] **Step 1: 修改 w.sh 调用 wsha-core.py**

```bash
#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export WSHA_ENTRY="w"
exec python "$SCRIPT_DIR/wsha-core.py" -e w "$@"
```

- [ ] **Step 2: 修改 w.bat 调用 wsha-core.py**

```batch
@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
set "WSHA_ENTRY=w"
python "%SCRIPT_DIR%wsha-core.py" -e w %*
exit /b %errorlevel%
```

- [ ] **Step 3: 测试 w 和 wsha 命令**

Run: `bash sh/w.sh fox`
Expected: `firefox`

- [ ] **Step 4: 提交**

```bash
git add sh/w.sh sh/w.bat
git commit -m "refactor: w.sh and w.bat call wsha-core.py directly"
```

---

## Task 9: 完整集成测试

**Files:**
- 测试配置文件和调用链

- [ ] **Step 1: 测试别名列表**

Run: `bash sh/w.sh --list`
Expected: 显示所有加载的别名

- [ ] **Step 2: 测试通配符展开**

Run: `bash sh/w.sh "bu test"`
Expected: `uvx browser-use test`

Run: `bash sh/w.sh codex`
Expected: `pnpx @openai/codex@0.115.0`

- [ ] **Step 3: 测试透传**

Run: `bash sh/w.sh ls`
Expected: `ls`（透传）

- [ ] **Step 4: 测试 --clear**

Run: `bash sh/w.sh --clear`
Expected: 清理缓存

- [ ] **Step 5: 提交**

```bash
git add -A
git commit -m "test: add integration tests for wsha-core.py"
```

---

## 验收标准

1. `python sh/wsha-core.py` 显示帮助信息
2. `python sh/wsha-core.py --list` 列出所有别名
3. `python sh/wsha-core.py --clear` 清理缓存
4. `python sh/wsha-core.py pcodex` 返回 `pnpx @openai/codex`
5. `python sh/wsha-core.py "bu test"` 返回 `uvx browser-use test`
6. `python sh/wsha-core.py not-exist` 返回 `not-exist`（透传）
7. w.sh、w.bat、wsha.sh 正常工作

---

## 后续计划

- 删除 py/wsha 模块（如设计文档所述）