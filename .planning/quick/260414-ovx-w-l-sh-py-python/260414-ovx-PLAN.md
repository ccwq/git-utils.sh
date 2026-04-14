---
phase: quick-260414-ovx
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - py/wsha/cli.py
  - sh/wsha.sh
autonomous: true
requirements: []
must_haves:
  truths:
    - "w -l 输出按具体配置文件分组，而非仅按来源名称"
    - "w -l 输出包含 ANSI 颜色（表头青色、别名绿色、来源路径黄色）"
    - "Python 和 Shell 版本输出视觉一致"
  artifacts:
    - path: "py/wsha/cli.py"
      provides: "print_list() with click.style colors + per-file grouping"
    - path: "sh/wsha.sh"
      provides: "show_list_table() with ANSI colors + per-file grouping"
  key_links:
    - from: "py/wsha/cli.py"
      to: "AliasEntry.config_path"
      via: "grouping logic"
      pattern: "config_path.*group"
    - from: "sh/wsha.sh"
      to: "ALIAS_CONFIG_PATHS"
      via: "grouping logic"
      pattern: "ALIAS_CONFIG_PATHS.*group"
---

<objective>
美化 `w -l` 输出：按具体配置文件分组 + 添加 ANSI 颜色

Purpose: 让 `w -l` 输出更易读，清晰展示每个别名的来源文件
Output: 升级后的 py/wsha/cli.py::print_list() 和 sh/wsha.sh::show_list_table()
</objective>

<execution_context>
@E:/project/self.project/git-utils.sh/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<interfaces>
<!-- Python: AliasEntry 结构（cli.py 使用的核心数据结构） -->
<!-- 从 py/wsha/parser.py 定义的 AliasEntry:
@dataclass
class AliasEntry:
    name: str
    template: str
    config_path: str   # <-- 用于按文件分组的关键字段
    source_name: str
    token_data: str
    token_count: int
    ...
-->

<!-- Shell: 关键并行数组（sh/wsha.sh） -->
<!-- ALIAS_KEYS[i]        = alias 名称 -->
<!-- ALIAS_TEMPLATES[i]   = 模板 -->
<!-- ALIAS_CONFIG_PATHS[i] = 配置文件路径（用于按文件分组） -->
<!-- ALIAS_SOURCE_NAMES[i] = 来源名称（builtin/user/project） -->
</interfaces>

<tasks>

<task type="auto">
  <name>Task 1: Python 美化 — print_list() 颜色 + 按文件分组</name>
  <files>py/wsha/cli.py</files>
  <action>
修改 `py/wsha/cli.py` 中的 `print_list()` 函数：

1. **分组逻辑变更**：从按 `source_name` 分组改为按 `config_path` 分组
   ```python
   from collections import defaultdict
   import os

   # 按 config_path 分组，而非 source_name
   by_file: Dict[str, List[AliasEntry]] = defaultdict(list)
   for alias in aliases:
       norm_path = os.path.normpath(alias.config_path)
       by_file[norm_path].append(alias)
   ```

2. **添加 `click.style` 颜色**（使用现有 click>=8.0 依赖，不引入 Rich）：
   - 表头 "别名" "命令"：青色粗体 `fg="cyan", bold=True`
   - 别名字段：绿色 `fg="green", bold=True`
   - 来源路径标签：黄色粗体 `fg="yellow", bold=True`
   - 分隔线使用_DIM `fg="bright_black"`

3. **输出格式**（每组一个文件）：
   ```
   [来源 相对路径]
     别名       命令
   ```
   使用 `textwrap` 或直接截断确保对齐

4. **保留 `get_source_label()`** 用于显示来源类型（builtin/user/project）

5. **保持 `app_env` 环境变量输出** 格式不变
  </action>
  <verify>
    <automated>cd /e/project/self.project/git-utils.sh && PYTHONPATH=py python -c "from wsha.cli import print_list; from wsha.parser import load_aliases; aliases, sources = load_aliases(); print_list(aliases, sources)" 2>&1 | head -80</automated>
  </verify>
  <done>
    `w -l` Python 输出：按文件分组 + 颜色显示（青/绿/黄），无 Rich 依赖
  </done>
</task>

<task type="auto">
  <name>Task 2: Shell 美化 — ANSI 颜色 + 按文件分组</name>
  <files>sh/wsha.sh</files>
  <action>
修改 `sh/wsha.sh` 中的 `show_list_table()` 函数：

1. **在文件顶部（第 30-50 行附近）添加 ANSI 颜色定义**：
   ```bash
   # ANSI 颜色码（支持 Git Bash / Linux / macOS）
   if [[ -t 1 || -n "$FORCE_COLOR" ]]; then
       C_RESET='\033[0m'
       C_BOLD='\033[1m'
       C_GREEN='\033[32m'     # 别名
       C_CYAN='\033[36m'      # 表头
       C_YELLOW='\033[33m'    # 来源路径
       C_DIM='\033[2m'        # 分隔线
   else
       C_RESET='' C_BOLD='' C_GREEN='' C_CYAN='' C_YELLOW='' C_DIM=''
   fi
   ```

2. **修改 `show_list_table()` 分组逻辑**：
   - 从按 `SOURCE_NAMES` 匹配 `ALIAS_SOURCE_NAMES` 改为按 `SOURCE_PATHS` 匹配 `ALIAS_CONFIG_PATHS`
   - 使用关联数组（如果 bash 版本支持）或嵌套循环实现按文件分组
   - 输出格式：`[source_name] 相对路径` 作为分组标题

3. **添加 ANSI 颜色到输出**：
   ```bash
   # 表头
   printf "%s%-${max_alias_len}s  %s%s\n" "$C_CYAN$C_BOLD" "别名" "命令" "$C_RESET"
   # 分隔线
   printf "%s%-${max_alias_len}s  %s%s\n" "$C_DIM" "----" "----" "$C_RESET"
   # 别名行
   printf "%s%-${max_alias_len}s  %s%s\n" "$C_GREEN" "$alias" "$template" "$C_RESET"
   # 来源标题
   echo -e "${C_YELLOW}${C_BOLD}[${src_name}] ${src_relpath}${C_RESET}"
   ```

4. **保持 `SOURCE_NAMES` / `SOURCE_PATHS` 结构不变**，仅修改 `show_list_table()` 内的分组逻辑
  </action>
  <verify>
    <automated>cd /e/project/self.project/git-utils.sh && bash sh/wsha.sh -l 2>&1 | head -50</automated>
  </verify>
  <done>
    `wsha -l` Shell 输出：按文件分组 + 颜色显示（青/绿/黄），与 Python 版本视觉一致
  </done>
</task>

</tasks>

<verification>
两个实现的输出对比验证（视觉一致性）：
1. Python: `python -m wsha -l` 输出应有青/绿/黄色
2. Shell: `bash sh/wsha.sh -l` 输出应有青/绿/黄色
3. 两者均应按具体配置文件分组，而非仅按来源名称
</verification>

<success_criteria>
- `w -l` (Python) 和 `bash sh/wsha.sh -l` (Shell) 均显示：
  - 按具体配置文件分组（不再是简单的 builtin/user/project 分组）
  - 表头青色、别名字段绿色、来源路径黄色
  - 两版本视觉一致
- 不引入 Rich 等新依赖
- 通过现有 `__test__/wsha.test.sh` 测试
</success_criteria>

<output>
After completion, create `.planning/quick/260414-ovx-w-l-sh-py-python/260414-ovx-SUMMARY.md`
</output>
