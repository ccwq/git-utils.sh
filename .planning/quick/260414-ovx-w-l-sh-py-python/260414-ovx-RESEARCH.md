# Quick Task: w -l 输出美化 — 研究

**Researched:** 2026-04-14
**Domain:** 终端美化输出（颜色 + 表格），Python/Shell 双实现
**Confidence:** MEDIUM

## Summary

`w -l` 当前实现为简单文本表格（Python `click.echo` + Shell `printf`），无颜色、无对齐视觉优化。需要升级为带颜色的格式化表格，并按具体文件分组显示（而非仅按来源层级）。

**核心约束：**
- Python: `click>=8.0` 已作为依赖，不可引入重型新依赖（如 Rich）
- 兼容性: Windows Git Bash / Linux / macOS 均需支持
- Python 3.8+ 兼容

---

## 当前实现分析

### Python (`py/wsha/cli.py`)

```python
# 当前 print_list() 输出格式:
click.echo(f"{'别名':<18} 命令")
for entry in by_source[source_name]:
    click.echo(f"  {entry.name:<16} {entry.template}")
```

- 按 `source_name` 分组（builtin/user/project），不显示具体文件
- `AliasEntry` 包含 `config_path` 字段，但 `print_list` 未使用

### Shell (`sh/wsha.sh`)

```bash
# 当前 show_list_table() 输出格式:
printf "%-${max_alias_len}s  %s\n" "别名" "命令"
printf "%-${max_alias_len}s  %s\n" "----" "----"
printf "%-${max_alias_len}s  %s\n" "${group_aliases[$j]}" "${group_templates[$j]}"
```

- 按来源名称分组，使用 `printf` 做左对齐填充
- 无 ANSI 颜色

---

## Python 美化方案

### 推荐方案: `click.style` + `textwrap`（零依赖增量）

```python
import click
from click import styled_text as St

# 使用 click 自带的样式功能（无额外依赖）
click.echo(click.style("别名", bold=True, fg="cyan") + "  " + click.style("命令", bold=True, fg="cyan"))
click.echo(click.style(f"  {entry.name:<16}", fg="green") + "  " + entry.template)
```

**优点:** 零新依赖，与现有 `click` 完全兼容
**缺点:** 功能有限，无原生表格支持

### 备选方案: `rich` 库

```python
from rich.console import Console
from rich.table import Table

console = Console()
table = Table(show_header=True, header_style="bold cyan")
table.add_column("别名", style="green", width=16)
table.add_column("命令")
for entry in aliases:
    table.add_row(entry.name, entry.template)
console.print(table)
```

**优点:** 表格、颜色、进度条开箱即用
**缺点:** 新增大型依赖（Rich 约 2000+ 行），与项目"轻量"哲学相悖
**建议:** 仅当功能需要远超 `click.style` 时考虑

### 推荐决策

> 使用 `click.style` 进行颜色输出，使用 `textwrap` 进行对齐控制。**不引入 Rich**。

---

## Shell ANSI 配色方案

### 配色定义（在 wsha.sh 顶部添加）

```bash
# ANSI 颜色码（支持 Git Bash / Linux / macOS）
if [[ -t 1 || -n "$FORCE_COLOR" ]]; then
    # 终端支持颜色
    C_RESET='\033[0m'
    C_BOLD='\033[1m'
    C_DIM='\033[2m'
    C_GREEN='\033[32m'    # 别名列
    C_CYAN='\033[36m'     # 表头
    C_YELLOW='\033[33m'   # 来源路径
    C_MAGENTA='\033[35m' # 注释/分隔
    C_RED='\033[31m'      # 错误
else
    C_RESET='' C_BOLD='' C_DIM='' C_GREEN='' C_CYAN='' C_YELLOW='' C_MAGENTA='' C_RED=''
fi
```

### 染色使用示例

```bash
echo -e "${C_CYAN}${C_BOLD}别名${C_RESET}  ${C_CYAN}${C_BOLD}命令${C_RESET}"
printf "%s%-${max_alias_len}s  %s${C_RESET}\n" "$C_GREEN" "$alias" "$template"
```

---

## Per-File 分组实现

### Python 变更点

1. **`AliasEntry` 无需变更** — 已有 `config_path` 字段
2. **修改 `print_list()` 分组逻辑:**

```python
from collections import defaultdict
import os

# 按 config_path 分组，而非 source_name
by_file: Dict[str, List[AliasEntry]] = defaultdict(list)
for alias in aliases:
    # 归一化路径用于分组
    norm_path = os.path.normpath(alias.config_path)
    by_file[norm_path].append(alias)

# 同时保留 source_name 用于显示标签
source_of: Dict[str, str] = {}  # path -> source_label
for src_name, src_path in sources.items():
    norm_path = os.path.normpath(src_path)
    source_of[norm_path] = get_source_label(src_name)

for file_path, entries in sorted(by_file.items()):
    source_label = source_of.get(file_path, "[未知]")
    rel_path = os.path.relpath(file_path)  # 转为相对路径显示
    click.echo(click.style(f"{source_label} {rel_path}", fg="yellow", bold=True))
    click.echo(click.style(f"  {'别名':<16}  {'命令'}", fg="cyan", bold=True))
    for entry in entries:
        click.echo(f"  {click.style(entry.name, fg='green', bold=True):<16}  {entry.template}")
```

### Shell 变更点

Shell 脚本需扩展 `load_single_config_file()` / `load_config_dir()` 以传递具体文件路径到 `show_list_table()`，当前仅传递 source name。

**方案:** 在 `ALIAS_SOURCE_NAMES` 旁增加 `ALIAS_FILE_PATHS` 数组：

```bash
declare -a ALIAS_FILE_PATHS=()
# 加载时:
ALIAS_FILE_PATHS+=("$config_path")  # 每个 alias 对应的文件路径
```

---

## 关键约束

| 约束 | 说明 |
|------|------|
| 无 Rich | click 已足够满足颜色 + 对齐需求 |
| Python 3.8+ | `click.style` 在 3.8 完全支持 |
| Windows Git Bash | ANSI 颜色码在 Git Bash 中正常工作 |
| 不破坏兼容 | 修改仅影响 `w -l` 输出格式，不改变匹配逻辑 |

---

## 实施路径建议

1. **Python**: 修改 `py/wsha/cli.py::print_list()`，使用 `click.style` + 按文件分组
2. **Shell**: 在 `sh/wsha.sh` 顶部添加颜色定义，修改 `show_list_table()` 使用 ANSI 色码 + 传递文件路径
3. **测试**: `w -l` 和 `wsha -l` 输出在 sh/py 两种实现下视觉一致

---

## Assumptions Log

| # | Claim | Confidence |
|---|-------|------------|
| A1 | `click.style` 在 Windows Git Bash 中正确渲染 ANSI 颜色 | MEDIUM — [ASSUMED] 需实测 |
| A2 | Shell `printf "%s"` 与 ANSI escape code 组合在 bash 4.x 中正常工作 | MEDIUM — [ASSUMED] bash 4.x 支持已知，但Git Bash 环境需验证 |
| A3 | 按 `config_path` 分组不会在 glob 目录场景下产生过多细小分组 | LOW — [ASSUMED] 取决于用户配置目录结构 |

---

## Open Questions

1. **Rich vs click.style?** 是否确实不需要 Rich 的表格边框功能？
2. **文件路径显示** — 目录 glob 场景下显示相对路径还是绝对路径？建议统一显示相对路径（相对于对应 source root）
3. **Shell 颜色开关** — 是否需要 `NO_COLOR` 环境变量支持或 `--no-color` flag？
