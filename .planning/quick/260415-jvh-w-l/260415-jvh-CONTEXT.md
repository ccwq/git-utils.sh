# Quick Task 260415-jvh: 修改 w -l 命令的输出格式，按配置文件分组展示别名 - Context

**Gathered:** 2026-04-15
**Status:** Ready for planning

<domain>
## Task Boundary

修改 `w -l` 命令的输出格式：当前所有别名被汇总到单个表格中，目标是按每个具体配置文件分组展示；同一来源下可以出现多个分组。每个分组单独输出标题、配置文件路径和别名表格，组与组之间使用 `============` 分隔。缺失的内容留空，整体结构参考 `q.md` 中的“预期格式”。

</domain>

<decisions>
## Implementation Decisions

### 分组标签命名
- 使用 `[内置]`、`[用户]`、`[项目]` 作为分组标签。
- 含义分别对应内置配置、用户配置、项目配置来源。

### 分隔符内容
- 组与组之间仅输出 `============`。
- 不在分隔符所在行追加路径或其他文本。

### Claude's Discretion
- 如果某个来源当前没有配置文件或没有别名，按现有数据结构决定是否省略该组；不要凭空构造内容。
- 路径展示格式应尽量与现有 `w -l` 输出风格保持一致。
- 表格列宽、对齐方式延续现有实现，优先保证可读性与兼容已有测试。

</decisions>

<specifics>
## Specific Ideas

- 当前输出会先打印环境变量，然后仅展示一个 `[内置]` 分组和单张别名表。
- 目标输出需要为每个具体配置文件重复以下结构：
  1. `[来源] 路径`
  2. 空行
  3. `别名 / 命令` 表格
  4. 空行
  5. 若后续还有分组，则输出 `============`
- 同一来源下允许出现多个分组，例如多个 `[内置]` 组分别对应不同的 `.txt` 文件。
- 参考样例来自 `q.md` 中“当前list是这样的 / 预期格式”的对比。

</specifics>

<canonical_refs>
## Canonical References

- `q.md`：任务输入与预期输出样例。
- No external specs — requirements fully captured in decisions above.

</canonical_refs>
