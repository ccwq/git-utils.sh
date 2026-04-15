# Quick Task 260415-jvh: w -l 按配置分组输出 - Research

**Researched:** 2026-04-15  
**Domain:** Python CLI 输出格式 / 配置来源分组  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- 使用 `[内置]`、`[用户]`、`[项目]` 作为分组标签。
- 组与组之间仅输出 `============`。
- 不在分隔符所在行追加路径或其他文本。

### Claude's Discretion
- 如果某个来源当前没有配置文件或没有别名，按现有数据结构决定是否省略该组；不要凭空构造内容。
- 路径展示格式应尽量与现有 `w -l` 输出风格保持一致。
- 表格列宽、对齐方式延续现有实现，优先保证可读性与兼容已有测试。

### Deferred Ideas (OUT OF SCOPE)
- （CONTEXT.md 未提供）
</user_constraints>

## Summary

`w -l` 的现实现已在 `py/wsha/cli.py::print_list()` 中按 `config_path` 聚合输出，但它只会生成“一个分组 + 一张表”，并且分组标题由 `source_name` 映射而来。[VERIFIED: codebase] 这意味着本次修改的核心不是“重新解析配置”，而是“改变 list 渲染层的分组与分隔策略”，同时保留现有的环境变量头部、列宽计算、颜色样式和输出对齐方式。[VERIFIED: codebase]

真正的约束在数据来源层：`load_config()` 已经把每条别名记录成 `AliasEntry(name, template, config_path, source_name, line_no, prefix_type)`，但默认是 first-wins 合并，低优先级来源中的同名 alias 会在进入 `print_list()` 前被折叠掉。[VERIFIED: codebase] 因此，如果目标是“按来源分组展示”，最稳妥的修改点是利用现有的 `source_name` / `config_path` 进行分组渲染；如果目标进一步要求“按单个配置文件逐文件分组”，则现有数据模型不足以完整还原文件级 provenance，需要额外传递更细粒度的文件路径。[VERIFIED: codebase]

**Primary recommendation:** 先把分组逻辑放在 `print_list()`，按 `AliasEntry.source_name + config_path` 组织输出，再决定是否需要扩展 `load_config()` 以保留文件级来源信息。[ASSUMED]

## Standard Stack

### Core
| Component | Version | Purpose | Why Standard |
|---|---:|---|---|
| Python | 3.8+ | CLI runtime | 项目约束已明确要求 Python 3.8+。[VERIFIED: CLAUDE.md] |
| click | >=8.0 | CLI 参数与输出 | 项目约束已明确依赖 click>=8.0，且 `py/wsha/cli.py` 已直接使用 click。[VERIFIED: CLAUDE.md][VERIFIED: codebase] |

### Supporting
| Component | Version | Purpose | When to Use |
|---|---:|---|---|
| `py/wsha/config.py` | local | 配置发现、合并、来源信息 | 需要知道 alias 来自 builtin/user/project 哪个来源时使用。[VERIFIED: codebase] |
| `py/wsha/parser.py` | local | 解析单文件 / 目录 glob 配置 | 需要保持当前 `*.txt`、忽略 `_` 前缀文件的规则时使用。[VERIFIED: codebase] |
| `SOURCE_LABEL_MAP` / `get_source_label()` | local | 来源名到展示标签映射 | 需要稳定输出 `[内置]` / `[用户级]` / `[项目级]` 时使用。[VERIFIED: codebase] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|---|---|---|
| 在 `print_list()` 里直接重扫文件系统 | 继续用 `load_config()` 返回的数据 | 直接重扫会绕开缓存、合并与 provenance 逻辑；当前已有来源字段可直接复用。[VERIFIED: codebase] |
| 仅按 `config_path` 分组 | 按 `source_name` 分组 | `config_path` 当前对目录型来源通常只是目录，不一定能表达更细的文件级边界；`source_name` 更适合和 `[内置]/[用户]/[项目]` 对齐。[VERIFIED: codebase][VERIFIED: CONTEXT.md] |

**Installation:**
```bash
# 本次任务不需要新增依赖；仅修改现有 Python CLI 输出逻辑
```

## Architecture Patterns

### Recommended Project Structure
```text
py/wsha/
├── cli.py      # list / find / execute 的展示与命令入口
├── config.py   # 配置发现、合并、来源信息
└── parser.py   # 单文件与目录配置解析
```

### Pattern 1: 保留 provenance，再做展示分组
**What:** `load_config()` 负责把来源、路径、行号装进 `AliasEntry`，`print_list()` 只负责按这些字段重排输出。[VERIFIED: codebase]  
**When to use:** 任何“输出格式变化，但底层配置读取规则不变”的场景。[VERIFIED: codebase]  
**Example:**
```python
# Source: py/wsha/config.py, py/wsha/cli.py [VERIFIED: codebase]
AliasEntry(
    name=name,
    template=template,
    config_path=path,
    source_name=source_name,
    line_no=line_no,
)
```

### Pattern 2: 渲染层按组单独计算列宽
**What:** 当前 `print_list()` 对每个组分别计算 `max_alias_len` / `max_command_len`，因此组内对齐独立、互不影响。[VERIFIED: codebase]  
**When to use:** 输出需要在组之间插入分隔线或不同标题时。[VERIFIED: codebase]  
**Example:**
```python
max_alias_len = max([len("别名")] + [len(entry.name) for entry in entries])
max_command_len = max([len("命令")] + [len(entry.template) for entry in entries])
```

### Anti-Patterns to Avoid
- **把分组键建立在渲染后的标题文本上：** 容易把 `[内置]`、`[用户]`、`[项目]` 这些展示层概念和真实来源混淆，后续改 label 会影响分组逻辑。[VERIFIED: codebase]
- **在 list 命令里重新解析配置文件：** 会绕开 `load_config()` 的缓存、优先级和错误处理路径，容易和 `find` / `execute` 行为分叉。[VERIFIED: codebase]
- **用全局最大宽度强行对齐所有分组：** 会让短表格被长命令撑宽，破坏“按配置文件分组浏览”的可读性。[ASSUMED]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| 来源标签展示 | 手写字符串拼接 | `SOURCE_LABEL_MAP` + `get_source_label()` | 已有稳定映射，避免在多处重复维护标签文本。[VERIFIED: codebase] |
| 路径格式化 | 直接打印原始 Windows 路径 | `to_display_path()` / `_resolve_display_path()` | 现有实现已经兼容 `cygpath`，并在缺失时回退到斜杠替换。[VERIFIED: codebase] |
| 组内列宽计算 | 固定列宽常量 | 按当前组动态计算 | 现有表格输出已经依赖动态宽度，继续复用可保持兼容已有测试。[VERIFIED: codebase] |
| 配置来源收集 | 在 CLI 层自己找文件 | `load_config()` 返回的 `aliases` / `sources` | `load_config()` 已经提供来源名、路径和错误列表。[VERIFIED: codebase] |

**Key insight:** 这个任务的价值不在于“多写一个排序”，而在于“不要丢 provenance”。只要别名已经在 `load_config()` 中被合并或折叠，`print_list()` 就只能展示它拿到的那些记录；所以分组策略必须建立在现有来源字段上，不能靠输出文本反推。[VERIFIED: codebase]

## Common Pitfalls

### Pitfall 1: 把“来源分组”误做成“单表重排”
**What goes wrong:** 只改表头或排序，仍然输出一整张表，用户视觉上还是无法区分来源。[VERIFIED: CONTEXT.md]
**Why it happens:** 容易忽略当前实现里 `print_list()` 是一次性把全部 aliases 画成一个表。[VERIFIED: codebase]
**How to avoid:** 在 `print_list()` 里按组循环输出：标题、路径、表格、空行、分隔符。[VERIFIED: CONTEXT.md][VERIFIED: codebase]
**Warning signs:** 代码里仍然只有一次 `click.echo()` 表头和一次 `for entry in entries`，没有外层分组循环。[VERIFIED: codebase]

### Pitfall 2: 以为 `config_path` 总是文件路径
**What goes wrong:** 输出标题可能显示成目录，和“配置文件”直觉不一致。[VERIFIED: codebase]
**Why it happens:** `parse_dir()` 解析目录时返回的是目录内所有 `*.txt` 的内容，但 `load_config()` 给 `AliasEntry.config_path` 记录的是 source path，而不是逐文件 path。[VERIFIED: codebase]
**How to avoid:** 先确认目标是“按来源目录分组”还是“按单个 txt 文件分组”；如果是后者，需要先补足文件级 provenance。[VERIFIED: codebase]
**Warning signs:** 只改 `print_list()`，但没有任何地方携带单个文件的真实路径。[VERIFIED: codebase]

### Pitfall 3: 改分组后破坏列宽或颜色输出
**What goes wrong:** 新的分组标题、分隔线、空行把原有对齐弄乱，回归测试很容易变脆。[VERIFIED: codebase]
**Why it happens:** 当前输出依赖 `click.style()`、组内动态宽度和固定的空行节奏。[VERIFIED: codebase]
**How to avoid:** 保留现有的头部环境变量块、颜色样式、组内宽度计算，只替换“组循环”和“组间分隔”的部分。[VERIFIED: CONTEXT.md][VERIFIED: codebase]
**Warning signs:** 新实现开始在多个地方手写宽度常量或重复格式化字符串。[ASSUMED]

## Code Examples

Verified patterns from the current codebase:

### 当前 list 的核心分组入口
```python
# Source: py/wsha/cli.py [VERIFIED: codebase]
grouped: Dict[str, List[AliasEntry]] = defaultdict(list)
for alias in aliases:
    group_key = os.path.normpath(alias.config_path or "")
    grouped[group_key].append(alias)
```

### 当前来源信息已经在加载阶段保留
```python
# Source: py/wsha/config.py [VERIFIED: codebase]
all_aliases[name] = AliasEntry(
    name=name,
    template=template,
    config_path=path,
    source_name=source_name,
    line_no=line_no,
    prefix_type=prefix_type
)
```

## Open Questions

1. **这里到底要”按来源”还是”按文件”分组？(RESOLVED)**  
   - 用户已确认：**按每个配置文件分组**，每个 `.txt` 文件单独成组。  
   - What's the implication: Python 侧需要改造 `parse_dir` / `load_config`，让每条 alias 携带真实文件路径，而不是目录路径。Shell 侧已有文件级 provenance（`ALIAS_CONFIG_PATHS`），可以直接用。  
   - Action: 见 PLAN.md Task 1 (Python) 和 Task 2 (Shell)。

2. **重复 alias 在分组输出中要不要按来源都显示？(RESOLVED)**  
   - Decision: 遵循现有 first-wins 合并语义，**不改变执行行为**，只修正展示层。分组输出里每条 alias 只出现一次（来自高优先级来源），不按来源重复展示。
   - Why: 与 `q.md` 的预期格式一致——预期只展示最终生效的别名，而非罗列所有来源定义。[VERIFIED: q.md]

## Sources

### Primary (HIGH confidence)
- `.planning/quick/260415-jvh-w-l/260415-jvh-CONTEXT.md` - 任务边界、锁定决策、展示分隔符要求
- `py/wsha/cli.py` - 当前 `w -l` 输出实现、来源标签、路径渲染、列宽计算
- `py/wsha/config.py` - 配置发现、来源合并、`AliasEntry` provenance 字段
- `py/wsha/parser.py` - 目录 glob 解析、`*.txt` 规则、忽略 `_` 前缀文件
- `q.md` - 当前输出与预期输出对比样例
- `CLAUDE.md` - Python 3.8+、click>=8.0 等项目约束

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - 项目约束与代码中已直接确认 Python/click/本地模块职责。[VERIFIED: CLAUDE.md][VERIFIED: codebase]
- Architecture: HIGH - `cli.py` / `config.py` / `parser.py` 的职责边界清晰，且 `print_list()` 的当前分组方式已明确。[VERIFIED: codebase]
- Pitfalls: HIGH - 主要风险来自 provenance 丢失、分组键选择和列宽/样式回归，均可从现有实现直接推导。[VERIFIED: codebase]

**Research date:** 2026-04-15  
**Valid until:** 2026-05-15
