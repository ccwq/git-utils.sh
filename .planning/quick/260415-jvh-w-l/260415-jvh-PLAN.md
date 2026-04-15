---
phase: quick-260415-jvh
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - py/wsha/parser.py
  - py/wsha/config.py
  - py/wsha/cli.py
  - sh/wsha.sh
autonomous: true
requirements:
  - jvh-01
must_haves:
  truths:
    - "`w -l` 最终按每个具体配置文件分组；同一来源下允许出现多个分组"
    - "Python 目录来源的 alias 必须保留真实 txt 文件路径，不能继续只保留目录路径"
    - "Python 与 Shell 两端标签统一为 [内置]、[用户]、[项目]"
    - "每个分组结束后输出单独一行 ============，最后一组不输出分隔线"
  artifacts:
    - path: "py/wsha/parser.py"
      provides: "目录解析阶段保留文件级 provenance"
      min_lines: 130
    - path: "py/wsha/config.py"
      provides: "AliasEntry.config_path 对目录来源写入具体文件路径"
      min_lines: 150
    - path: "py/wsha/cli.py"
      provides: "Python list 输出按文件分组并使用正确中文标签与分隔符"
      min_lines: 140
    - path: "sh/wsha.sh"
      provides: "Shell list 输出使用正确中文标签与分隔符，并保持文件级分组"
      min_lines: 100
  key_links:
    - from: "py/wsha/parser.py::parse_dir()"
      to: "py/wsha/config.py::load_config()"
      via: "parse_dir 返回结果中包含 file_path"
      pattern: "for file_path in files"
    - from: "py/wsha/config.py::load_config()"
      to: "py/wsha/cli.py::print_list()"
      via: "AliasEntry.config_path 使用 file_path 进入展示层"
      pattern: "config_path=file_path"
    - from: "py/wsha/cli.py::print_list()"
      to: "grouped[config_path]"
      via: "按文件路径分组渲染标题与表格"
      pattern: "group_key = os.path.normpath(alias.config_path or \"\")"
    - from: "sh/wsha.sh::show_list_table()"
      to: "ALIAS_CONFIG_PATHS"
      via: "Shell 侧继续按文件路径分组，仅修正标签与分隔符"
      pattern: "for config_path in"
---

<objective>
修改 `w -l` 的输出格式，使其按**每个具体配置文件**分组展示别名；同一来源下可以出现多个分组。每个分组显示 `[来源] 路径`、空行、别名表格，并在组与组之间输出单独一行 `============`。

目的：让 Python 与 Shell 两个实现都符合 `q.md` 的预期格式，同时不改变 alias 解析优先级、匹配和执行语义。
</objective>

<execution_context>
@E:/project/self.project/git-utils.sh/.claude/get-shit-done/workflows/execute-plan.md
@E:/project/self.project/git-utils.sh/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@py/wsha/parser.py
@py/wsha/config.py
@py/wsha/cli.py
@sh/wsha.sh
@.planning/quick/260415-jvh-w-l/260415-jvh-CONTEXT.md
@.planning/quick/260415-jvh-w-l/260415-jvh-RESEARCH.md
@q.md

已确认事实：
- 用户已明确要求：**每个配置文件一组**，不是“每个来源一组”。
- Shell 当前已保留文件级 provenance：`ALIAS_CONFIG_PATHS` 存的是具体文件路径。
- Python 当前没有：`parse_dir()` 读取目录内多个 txt，但 `load_config()` 给 `AliasEntry.config_path` 写入的是目录路径，导致 `print_list()` 无法按文件分组。
- 现有 Python 标签是 `[用户级]` / `[项目级]`，需改为 `[用户]` / `[项目]`。
</context>

<tasks>

<task type="auto">
  <name>Task 1: 为 Python 目录来源补齐文件级 provenance</name>
  <files>py/wsha/parser.py, py/wsha/config.py</files>
  <action>
修改 `py/wsha/parser.py:131` 附近的 `parse_dir()`，让它在遍历每个 `.txt` 文件时，返回值里携带该 alias 的真实 `file_path`，而不是只返回 `(name, template, prefix_type, line_no)`。随后修改 `py/wsha/config.py:215` 附近的 `load_config()` 目录分支，适配新的返回值结构，并在构造 `AliasEntry` 时把 `config_path` 设置为具体文件路径 `file_path`。

要求：
- 单文件模式 (`parse_file`) 的行为不变。
- alias 覆盖语义保持 first-wins，不改变执行结果。
- 缓存结构无需额外扩展字段，只需确保最终写入缓存的 `config_path` 已经是文件路径。
  </action>
  <verify><automated>python -m py_compile E:/project/self.project/git-utils.sh/py/wsha/parser.py E:/project/self.project/git-utils.sh/py/wsha/config.py</automated></verify>
  <done>Python 侧目录来源的每条 alias 都能携带真实 txt 文件路径进入 AliasEntry.config_path</done>
</task>

<task type="auto">
  <name>Task 2: 修正 Python 与 Shell 的 list 渲染格式</name>
  <files>py/wsha/cli.py, sh/wsha.sh</files>
  <action>
在 `py/wsha/cli.py:18-23` 更新 `SOURCE_LABEL_MAP`，将 `user`/`project` 分别改为 `[用户]`/`[项目]`。保留 `print_list()` 现有按 `alias.config_path` 分组的结构，因为 Task 1 完成后这里的 `config_path` 已经变成真实文件路径。调整标题渲染，使其输出为单行 `[来源] 完整显示路径`，不再拆成目录行 + 文件名行；然后在每组表格输出结束后的空行之后、最后一组之外插入 `click.echo("============")`。

在 `sh/wsha.sh:661` 附近保留现有按 `ALIAS_CONFIG_PATHS` 的文件级分组逻辑，只修正分组标题：把 `builtin/user/project` 映射为 `[内置]/[用户]/[项目]`，标题同样输出为单行 `[来源] 完整显示路径`；在每组输出结束后、最后一组之外插入 `echo "============"`。

要求：
- 环境变量头部、表头、列宽和颜色行为保持现有风格。
- 分隔符所在行只包含 `============`，不追加任何文本。
  </action>
  <verify><automated>python -m py_compile E:/project/self.project/git-utils.sh/py/wsha/cli.py && bash -n E:/project/self.project/git-utils.sh/sh/wsha.sh</automated></verify>
  <done>Python 与 Shell 的 `w -l` 都按具体配置文件分组显示，标签与分隔符格式一致</done>
</task>

<task type="auto">
  <name>Task 3: 验证文件级分组、标签和分隔符</name>
  <files>py/wsha/parser.py, py/wsha/config.py, py/wsha/cli.py, sh/wsha.sh</files>
  <action>
完成实现后进行静态与最小功能验证：
1. 检查 Python 侧是否已经把文件路径贯通到 `AliasEntry.config_path`；
2. 检查 `SOURCE_LABEL_MAP` 是否只输出 `[内置]`/`[用户]`/`[项目]`；
3. 检查 Python 和 Shell 是否都包含组间分隔符逻辑，且条件是“最后一组除外”；
4. 如果当前环境可直接运行，执行 `python -m wsha -l` 与 `bash sh/wsha.sh -l` 做一次结构核对，确认标题为单行、分组之间存在 `============`。
  </action>
  <verify><automated>python - <<'PY'
from pathlib import Path
parser_text = Path('E:/project/self.project/git-utils.sh/py/wsha/parser.py').read_text(encoding='utf-8')
config_text = Path('E:/project/self.project/git-utils.sh/py/wsha/config.py').read_text(encoding='utf-8')
cli_text = Path('E:/project/self.project/git-utils.sh/py/wsha/cli.py').read_text(encoding='utf-8')
sh_text = Path('E:/project/self.project/git-utils.sh/sh/wsha.sh').read_text(encoding='utf-8')
checks = [
    ('python user label', '"user": "[用户]"' in cli_text),
    ('python project label', '"project": "[项目]"' in cli_text),
    ('python config_path=file_path', 'config_path=file_path' in config_text),
    ('python separator', 'click.echo("============")' in cli_text),
    ('shell separator', 'echo "============"' in sh_text),
    ('shell builtin label', '[内置]' in sh_text),
    ('shell user label', '[用户]' in sh_text),
    ('shell project label', '[项目]' in sh_text),
]
failed = [name for name, ok in checks if not ok]
print('PASS' if not failed else 'FAIL: ' + ', '.join(failed))
raise SystemExit(0 if not failed else 1)
PY</automated></verify>
  <done>实现满足“每个配置文件一组”、正确中文标签和组间分隔符三项核心要求</done>
</task>

</tasks>

<verification>
- `python -m py_compile py/wsha/parser.py py/wsha/config.py py/wsha/cli.py` 无报错
- `bash -n sh/wsha.sh` 无语法错误
- 静态检查确认 `config_path=file_path`、标签映射与分隔符逻辑存在
</verification>

<success_criteria>
1. Python 目录来源下的 alias 能拿到真实 txt 文件路径
2. Python `print_list()` 按文件路径分组，而不是按目录或来源粗粒度分组
3. Shell `show_list_table()` 继续按文件路径分组
4. Python 与 Shell 标签统一为 `[内置]`、`[用户]`、`[项目]`
5. Python 与 Shell 在组间输出单独一行 `============`，最后一组不输出
6. 未改变 alias 匹配和执行语义，只修正 list 展示格式
</success_criteria>

<output>
After completion, create `.planning/quick/260415-jvh-w-l/260415-jvh-SUMMARY.md`
</output>
