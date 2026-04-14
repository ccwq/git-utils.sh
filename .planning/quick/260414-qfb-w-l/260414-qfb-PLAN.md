---
phase: quick-260414-qfb
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
    - "w -l 输出先显示路径级分组，再在每组内明确突出具体文件名"
    - "每个文件下的 alias/command 以两列对齐方式展示，视觉上接近表格"
    - "Python 和 Shell 版本的 w -l 输出结构保持一致"
  artifacts:
    - path: "py/wsha/cli.py"
      provides: "print_list() with per-file header emphasis and fixed-width two-column rendering"
    - path: "sh/wsha.sh"
      provides: "show_list_table() with per-file header emphasis and fixed-width two-column rendering"
  key_links:
    - from: "py/wsha/cli.py"
      to: "AliasEntry.config_path"
      via: "directory/file split and column width calculation"
      pattern: "config_path|basename|dirname|max"
    - from: "sh/wsha.sh"
      to: "ALIAS_CONFIG_PATHS"
      via: "directory/file split and column width calculation"
      pattern: "ALIAS_CONFIG_PATHS|basename|dirname|max"
---

<objective>
修正 `w -l` 输出的结构表达：在已有按配置文件分组的基础上，把“目录上下文”和“文件名”拆开显示，并把 alias/command 区域改成真正稳定的两列对齐。

Purpose: 用户已经能看到按 config_path 分组，但当前完整路径直接做标题，文件名不够突出；同时命令列只是跟在别名后面，不像清晰的双列表格。此次 quick fix 只调整 `py/wsha/cli.py` 和 `sh/wsha.sh` 的展示层，不引入新依赖、不改配置加载逻辑。
Output: 一份结构更清晰的 `w -l` 输出：目录/文件层次明确，别名列与命令列稳定对齐，Python 与 Shell 保持一致。
</objective>

<execution_context>
@E:/project/self.project/git-utils.sh/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@E:/project/self.project/git-utils.sh/.planning/STATE.md
@E:/project/self.project/git-utils.sh/.planning/quick/260414-ovx-w-l-sh-py-python/260414-ovx-SUMMARY.md
@E:/project/self.project/git-utils.sh/py/wsha/cli.py
@E:/project/self.project/git-utils.sh/sh/wsha.sh

<interfaces>
From `py/wsha/config.py` / `py/wsha/cli.py` usage:
```python
AliasEntry.name: str
AliasEntry.template: str
AliasEntry.config_path: str
AliasEntry.source_name: str
```

From `sh/wsha.sh` parallel arrays:
```bash
ALIAS_KEYS[i]         # alias name
ALIAS_TEMPLATES[i]    # template text
ALIAS_CONFIG_PATHS[i] # concrete config file path
ALIAS_SOURCE_NAMES[i] # source label
```

Current rendering behavior to replace:
- Python prints full config path in one title line, then `alias + template` with only alias width constrained.
- Shell prints full config path in one title line, then `alias + template` with only alias width constrained.

Target output shape for both implementations:
```text
[内置] /path/to/config/wsh-alias
  default.txt

  别名                命令
  ----                ----
  gc                  git commit
  gs                  git status
```

Notes:
- Keep existing color semantics from quick task 260414-ovx.
- Keep env block output in Python unchanged.
- Do not add Rich/tabulate/column or other dependencies.
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Python 输出重排为目录标题 + 文件标题 + 真正双列对齐</name>
  <files>py/wsha/cli.py</files>
  <action>
重写 `print_list()` 的展示逻辑，但仅限列表渲染层：

1. 继续以 `AliasEntry.config_path` 为数据来源，不回退到 `source_name` 粗粒度分组。
2. 从每个 `config_path` 中拆出目录部分和文件名部分，让输出层次更明确：
   - 第一行保留来源标签 + 目录路径，例如 `[内置] /.../config/wsh-alias`
   - 第二行单独显示文件名，例如 `default.txt`，让“按文件细分”肉眼可见
   - 文件名样式要比正文更醒目，但不要引入新颜色体系；可复用现有 bold/yellow/cyan 组合
3. 把 alias/command 改成真正的两列排版：
   - 计算当前文件组内 `max_alias_len` 与 `max_command_len`
   - 表头、分隔线、数据行都按同样列宽输出
   - 不要继续使用固定 16/18 宽度硬编码作为主布局，避免长别名导致错位
4. 保持命令内容原样输出，不截断、不换行重排，避免改变用户看到的真实模板。
5. 保留已有环境变量输出块与 `_resolve_display_path()` / `get_source_label()` 语义，避免影响其它行为。
6. 在代码中用简短中文注释说明“目录上下文”和“文件名强调”的原因，提升可维护性。
  </action>
  <verify>
    <automated>cd /e/project/self.project/git-utils.sh && python -m py_compile py/wsha/cli.py && APP_HOME="/e/project/self.project/git-utils.sh" PYTHONPATH=py python -c "from wsha.cli import main; main.main(args=['-l'], standalone_mode=False)" 2>&1 | head -80</automated>
  </verify>
  <done>
    Python 版 `w -l` 输出中，同一目录上下文下的具体文件名被单独突出显示，且 alias/命令两列在每个文件组内稳定对齐。
  </done>
</task>

<task type="auto">
  <name>Task 2: Shell 输出同步为同结构文件标题和双列对齐</name>
  <files>sh/wsha.sh</files>
  <action>
调整 `show_list_table()`，让 Shell 版输出和 Python 版在结构上完全对齐：

1. 保持当前按 `ALIAS_CONFIG_PATHS` 分组，不改变配置加载、缓存、匹配等逻辑。
2. 对每个分组路径拆出目录与文件名：
   - 第一行输出 `[来源] 目录路径`
   - 下一行单独缩进显示文件名
   - 不再只把完整文件路径塞进单行标题里
3. 重新计算列宽：
   - 当前组内扫描 `group_aliases` 与 `group_templates`
   - 使用 `printf` 让“别名列”和“命令列”都按宽度对齐，表头/分隔线/数据行一致
   - 仍然兼容 Git Bash bash 4.x，不使用高版本专属格式能力
4. 保留现有 ANSI 颜色体系和 `FORCE_COLOR` 判定，不新增依赖、不改其它命令路径。
5. 增加简短中文注释，说明为何拆分“目录 + 文件名”以及为何按组计算双列宽度。
  </action>
  <verify>
    <automated>cd /e/project/self.project/git-utils.sh && bash -n sh/wsha.sh && APP_HOME="/e/project/self.project/git-utils.sh" FORCE_COLOR=1 bash sh/wsha.sh -l 2>&1 | head -80</automated>
  </verify>
  <done>
    Shell 版 `wsha -l` / `w -l` 输出中，目录标题与文件名层次清晰，alias/命令两列对齐方式与 Python 版保持一致。
  </done>
</task>

<task type="auto">
  <name>Task 3: 交叉验证两实现输出结构一致且仅为展示层变更</name>
  <files>py/wsha/cli.py, sh/wsha.sh</files>
  <action>
执行一次交叉验证，确认这次 quick fix 没有偏离范围：

1. 分别运行 Python 与 Shell 的 `-l` 输出，检查是否都呈现“来源+目录 / 文件名 / 双列表格”的相同层次。
2. 确认本次修改仅影响列表渲染，不触碰 alias 加载、匹配、执行逻辑。
3. 如果发现两边结构不一致，优先收敛到同一输出形状，而不是让两边各自优化成不同格式。
4. 不新增测试框架；使用现有语法检查 + 命令输出检查即可，保持 quick task 原子性。
  </action>
  <verify>
    <automated>cd /e/project/self.project/git-utils.sh && python -m py_compile py/wsha/cli.py && bash -n sh/wsha.sh && APP_HOME="/e/project/self.project/git-utils.sh" PYTHONPATH=py python -c "from wsha.cli import main; main.main(args=['-l'], standalone_mode=False)" 2>&1 | head -40 && printf '\n---- shell ----\n' && APP_HOME="/e/project/self.project/git-utils.sh" FORCE_COLOR=1 bash sh/wsha.sh -l 2>&1 | head -40</automated>
  </verify>
  <done>
    两个实现的 `w -l` 输出在结构和对齐策略上保持一致，并且修改范围仍然局限于 `py/wsha/cli.py` 与 `sh/wsha.sh` 的列表展示层。
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| config file -> list renderer | 用户可编辑的 alias/template 文本会直接进入终端输出，属于不可信显示数据 |
| terminal renderer -> user | ANSI 样式与文本布局仅用于展示，不能改变命令执行语义 |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-quick-260414-qfb-01 | T | `py/wsha/cli.py::print_list` | mitigate | 仅重排展示层，命令模板按原值输出，不在列表渲染阶段做额外求值或执行 |
| T-quick-260414-qfb-02 | T | `sh/wsha.sh::show_list_table` | mitigate | 继续使用 `printf` 输出已加载文本，不通过 `eval`/命令替换生成列表内容 |
| T-quick-260414-qfb-03 | I | console output | accept | 配置文件路径与 alias 模板本就是 `w -l` 预期展示内容，无新增敏感数据暴露 |
| T-quick-260414-qfb-04 | D | list rendering | mitigate | 按单个文件组计算列宽，不引入外部依赖或复杂布局逻辑，降低不同终端下渲染失败概率 |
</threat_model>

<verification>
1. `py/wsha/cli.py` 通过 `python -m py_compile`
2. `sh/wsha.sh` 通过 `bash -n`
3. Python 与 Shell 的 `-l` 输出都体现：
   - 目录路径与文件名分层显示
   - alias/命令双列对齐
   - 颜色语义保留
4. 无新依赖、无配置加载行为变更
</verification>

<success_criteria>
- `w -l` 不再只把完整 config_path 当作唯一标题，而是明确显示“目录上下文 + 具体文件名”。
- 每个文件下的 alias 与 command 形成稳定双列，长短不一时仍然对齐。
- Python 与 Shell 两个实现输出结构一致。
- 改动仅发生在 `E:\project\self.project\git-utils.sh\py\wsha\cli.py` 和 `E:\project\self.project\git-utils.sh\sh\wsha.sh`。
</success_criteria>

<output>
After completion, create `.planning/quick/260414-qfb-w-l/260414-qfb-SUMMARY.md`
</output>
