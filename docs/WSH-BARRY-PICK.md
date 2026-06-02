# `wsh-barry-pick.sh` 使用说明

`wsh-barry-pick.sh` 用于对目标分支执行 `git merge --squash`，并根据来源分支中的 `.squash-exclude` 配置排除指定路径。

产品语义上，`.squash-exclude` 应优先影响“来源分支中哪些内容可以参与 squash merge”：命中排除规则的文件或目录，应保持当前分支 `HEAD` 状态；未命中的内容继续按正常 squash merge 处理。

适合场景：

- 希望把某个功能分支整理为一笔 squash 变更再手动提交
- 希望在 squash 过程中排除敏感文件、临时文件或仅用于来源分支的配置文件
- 希望保留主要业务变更，但不把 `.squash-exclude` 本身一起带入当前分支

## 前置条件

执行脚本前，请确认：

1. 当前目录位于 Git 仓库中
2. 当前工作区与暂存区是干净的
3. 目标分支已经存在，并且可以被当前分支执行 `git merge --squash`
4. 如果需要排除路径，请在**目标分支**根目录中准备 `.squash-exclude`

如果工作区或暂存区不干净，脚本会直接退出并提示：

```txt
Error: working tree or index is not clean.
```

## 基本命令格式

```bash
./sh/wsh-barry-pick.sh --help
./sh/wsh-barry-pick.sh <target-branch>
```

当前脚本支持的参数与选项包括：

- `target-branch`：要执行 squash merge 的来源分支
- `-h, --help`：显示完整帮助信息并退出

当未传入任何参数时，脚本会直接显示完整帮助信息，帮助内容至少会说明：

- 脚本能力与适用场景
- `target-branch` 的参数含义
- `-h, --help` 的选项含义
- 常见执行示例

## `.squash-exclude` 机制说明

脚本会在执行 merge 前，尝试从目标分支读取：

```txt
.squash-exclude
```

读取方式等价于：

```bash
git show "<target-branch>:.squash-exclude"
```

如果找到该文件，脚本应基于这些规则排除来源分支中不应参与 squash merge 的路径。核心规则是：

```txt
命中 .squash-exclude = 不采纳来源分支对该路径的任何影响，保持当前分支 HEAD 状态
```

这意味着：

- `.squash-exclude` 中列出的路径不会进入当前 squash 结果
- 被排除路径会保持或恢复为当前分支 `HEAD` 的状态
- 如果排除的是新文件，恢复后这些文件通常不会出现在工作区和暂存区中
- 如果排除的是当前分支已存在文件或目录，来源分支对它的修改、删除、重命名都不应被采纳
- `.squash-exclude` 自身默认也不应进入最终 squash 结果

如果目标分支中没有 `.squash-exclude`，脚本会继续执行 squash，只是不做排除。

## 冲突场景下的排除语义

`.squash-exclude` 不是“只在成功 merge 后做清理”的弱规则。新的产品语义要求它在 squash merge 前优先生效：命中排除规则的路径，不应因为来源分支改动而制造需要用户处理的冲突。

行为矩阵如下：

| 路径是否命中 `.squash-exclude` | 是否发生冲突 | 期望行为 |
|---|---|---|
| 命中 | 不冲突 | 不采纳来源分支改动，保持当前分支 `HEAD` 状态 |
| 命中 | 冲突 | 不暴露给用户处理，保持当前分支 `HEAD` 状态 |
| 未命中 | 不冲突 | 正常进入 squash merge 结果 |
| 未命中 | 冲突 | 保留冲突状态，交给用户手动解决 |

如果一次 squash merge 中同时存在两类冲突：

- 命中 `.squash-exclude` 的冲突：脚本应自动保持当前分支状态
- 未命中 `.squash-exclude` 的冲突：脚本应以非零状态退出，并保留当前仓库的冲突状态，等待用户手动解决

如果所有冲突都被 `.squash-exclude` 覆盖，则脚本应继续完成 squash merge；若最终没有可提交内容，则提示 `Nothing to commit after applying excludes.` 并以成功状态退出。

## `.squash-exclude` 示例

### 基础示例

```txt
secret.env
.squash-exclude
```

含义：

- `secret.env` 不进入当前 squash 结果
- `.squash-exclude` 自身也不进入当前 squash 结果

### 覆盖常见支持语法的示例

```txt
# 1. 排除根目录下的单个文件
secret.env

# 2. 排除根目录下的配置文件本身
.squash-exclude

# 3. 排除子目录中的具体文件
config/local/dev.env

# 4. 排除子目录中的文档或产物
build/output.log
docs/internal-note.md

# 5. 同时排除多个离散路径
keep/private.key
tmp/debug.txt
```

说明：

- `.squash-exclude` 中一行写一个路径
- 路径会按 `git restore --pathspec-from-file` 逐行读取
- 最稳妥的写法是使用**仓库相对路径**
- 当前已验证稳定的场景包括：排除单个文件，以及把 `.squash-exclude` 自身一起排除
- 如果你准备写更复杂的 pathspec 语法，建议先在仓库里做一次小范围验证，再用于正式流程

## 常见用法

### 1. 无排除配置，保留全部 squash 结果

```bash
./sh/wsh-barry-pick.sh feature-no-exclude
```

预期行为：

- 执行 `git merge --squash feature-no-exclude`
- 若来源分支没有 `.squash-exclude`，保留全部 squash 结果
- 变更进入暂存区，等待你手动检查与提交

### 2. 使用 `.squash-exclude` 排除指定文件

目标分支中存在：

```txt
secret.env
.squash-exclude
```

执行：

```bash
./sh/wsh-barry-pick.sh feature-with-exclude
```

预期行为：

- `keep.txt` 等未排除文件仍保留在暂存区
- `secret.env` 会被恢复为当前分支 `HEAD` 状态
- `.squash-exclude` 本身不会进入最终 squash 结果

### 3. 全部变更都被排除

如果目标分支的新增内容全部出现在 `.squash-exclude` 中，执行后脚本会提示：

```txt
Nothing to commit after applying excludes.
```

这表示：

- squash merge 已经执行过
- 但经过排除恢复后，暂存区已没有可提交内容
- 脚本会以成功状态退出，方便你在外层流程里继续判断

## 输出说明

脚本在执行过程中可能输出以下关键信息：

### 找到排除配置

```txt
Found exclude config in <target-branch>:.squash-exclude
```

说明目标分支存在 `.squash-exclude`，后续会应用排除规则。

### 未找到排除配置

```txt
No exclude config found in source branch, proceeding without exclusions.
```

说明脚本会直接保留全部 squash 结果。

### 应用排除规则

```txt
Applying exclusions...
```

说明脚本正在根据 `.squash-exclude` 恢复指定路径。

### 打印当前状态

```txt
Current status:
```

后面会跟随 `git status --short` 输出，用于帮助你快速判断：

- 哪些文件仍在暂存区
- 哪些排除规则已经生效
- 当前是否还有待提交内容

## 推荐操作流程

建议把这个脚本放进如下工作流中：

1. 切到接收 squash 结果的目标分支
2. 确认工作区与暂存区干净
3. 执行 `./sh/wsh-barry-pick.sh <target-branch>`
4. 查看脚本输出的 `git status --short`
5. 手动检查暂存区内容
6. 使用你自己的提交命令完成 commit

示例：

```bash
git checkout master
./sh/wsh-barry-pick.sh feature-with-exclude
git status --short
git commit -m "feat: merge feature-with-exclude without excluded files"
```

## 注意事项

### 1. 脚本不会自动提交

如果你需要提交，必须自行执行：

```bash
git commit -m "your message"
```

### 2. 脚本要求干净工作区

这是为了避免你本地未提交的改动与 squash 结果混在一起，导致无法区分来源。

### 3. `.squash-exclude` 来自目标分支

排除规则不是读取当前分支工作区文件，而是直接从：

```bash
<target-branch>:.squash-exclude
```

读取。

也就是说，你应该在**来源分支**维护这份排除配置。

### 4. 该脚本更适合“先整理，再手动提交”

它的职责是：

- 生成 squash 结果
- 清理不想带入的路径
- 把最终可提交内容保留在暂存区

它不负责：

- 自动写 commit message
- 自动提交
- 自动推送

## 已验证行为

根据仓库中的自动化测试 `__test__/wsh-barry-pick.test.sh`，当前已验证或已固化为产品验收的行为包括：

- 缺少目标分支参数时给出 usage
- 工作区不干净时拒绝执行
- 无 `.squash-exclude` 时保留全部 squash 结果
- 有 `.squash-exclude` 时移除指定路径
- 全部变更被排除后提示无可提交内容
- 支持接近 `.gitignore` 的常见写法，例如 `/docs`、普通目录名、注释行、空白行和 CRLF
- 排除当前分支已存在文件时，应恢复为当前分支 `HEAD` 内容
- 排除当前分支已存在目录时，应整体恢复为当前分支 `HEAD` 状态
- 命中 `.squash-exclude` 的冲突文件或目录不应阻塞 squash merge
- 命中和未命中 `.squash-exclude` 的冲突同时存在时，只应把未命中的冲突留给用户处理
- 命中 `.squash-exclude` 的删除和重命名不应被采纳，应保持当前分支状态

如需查看项目中的其他脚本说明，请回到 [README.md](../README.md)。
