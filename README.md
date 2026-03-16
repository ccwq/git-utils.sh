# Git Utils (git-utils.sh)

[![GitHub](https://img.shields.io/github/license/ccwq/git-utils.sh)](https://github.com/ccwq/git-utils.sh)

一系列实用的 Git 脚本工具集合，支持跨平台使用（Windows/Linux/macOS）。

项目地址: [https://github.com/ccwq/git-utils.sh](https://github.com/ccwq/git-utils.sh)

## 简介

本项目旨在提供一些便捷的 Shell 脚本，帮助开发者更高效地处理日常的 Git 操作。特别优化了在 Windows 环境下使用 Git Bash 的体验。

## 环境要求

- **Git**: 必须安装 Git。
- **Bash**: 
  - Linux / macOS: 默认支持。
  - Windows: 推荐使用 [Git Bash](https://gitforwindows.org/) (通常随 Git 一起安装)。

## 安装

```bash
git clone https://github.com/ccwq/git-utils.sh.git
cd git-utils.sh
```

## 可用脚本

所有脚本均位于 `sh/` 目录下。

### 1. Windows Git Bash 运行器 (`sh/wsh.bat`)

用于在 Windows 上快速调用 Git Bash 执行命令，或进入交互式 Bash。

#### 用法

```bash
# 显示帮助
wsh --help

# 进入当前目录的 Git Bash
wsh .

# 执行命令（无管道时自动追加 --color）
wsh ls -l

# 带管道的命令原样执行
wsh "ls -l | grep foo"
```

### 2. TCP 连通性检测包装器 (`sh/wsh-ping.bat`)

用于在 Windows 下调用 `bin/tcping.exe`，支持两种模式：

- 无参数：读取 `config/wsh-ping.txt` 并显示候选菜单（回车默认选第 1 项）。
- 有参数：将参数原样透传给 `tcping.exe`。

#### 预设配置文件

预设地址从 `config/wsh-ping.txt` 读取，格式为每行一条：

```txt
<name> <host> <port>
```

示例：

```txt
qq.com 123.150.76.218 443
t.cn 123.56.139.83 443
```

说明：

- 支持空行。
- 支持注释行（以 `#` 开头）。
- 菜单按配置文件顺序自动编号。

#### 用法

```bash
# 进入候选菜单（回车默认选 1）
wsh-ping

# 查看帮助（包含过滤后的 tcping --help）
wsh-ping --help
# 或
wsh-ping -h

# 原样透传给 tcping
wsh-ping 1.1.1.1 443 -c 4 -D
wsh-ping qq.com 443 -t 2
```

#### Windows (CMD / PowerShell) 调用示例

```bat
sh\wsh-ping.bat
sh\wsh-ping.bat --help
sh\wsh-ping.bat 1.1.1.1 443 -c 4 -D
```

### 3. 复杂命令别名展开 (`sh/w.bat` / `sh/wsha.bat`)

用于在 Windows 下通过配置文件将简短别名展开为完整命令，支持默认参数与运行时参数合并。

#### 配置文件

支持按优先级读取并融合多个配置文件（同名 alias 高优先级覆盖低优先级）：

1. 内置配置：`config/wsh-alias.txt`
2. 用户配置：`%USERPROFILE%\.config\wsh-alias.txt`
3. 工作目录配置：`%CD%\.config\wsh-alias.txt`

若某个配置文件不存在则自动忽略。配置内容格式为每行一条：

```txt
<alias> <target...>
```

其中：

- `<alias>` 支持英文双引号包裹，用于包含空格（如 `"pcodex l"`）。
- `<alias>` 支持 `*` 通配符，且按**单段匹配**（不跨空格）。
- `<alias>` 支持 `**` 通配符，按“匹配剩余全部内容（可含空格）”处理；可在模板中通过 `$$` 取值。
- 通配符捕获结果可在模板中用 `$1`、`$2`、`$3`... 引用。
- `<target...>` 也支持整体双引号包裹，`"pnpx $1"` 与 `pnpx $1` 等价。
- `<target...>` 执行时可直接使用 `%APP_HOME%`、`%APP_SH%`、`%APP_CONFIG%` 三个内置环境变量。

示例：

```txt
ab agent-browser
foo foobar open

# 注释行，加载时忽略
bar barbar -- --name ccwq

pcodex pnpx @openai/codex
"pcodex l" pnpx @openai/codex@latest

"px*" pnpx $1
"px *" "pnpx $1"
"tool * *" echo $1::$2

# 为 wsh 增加缩写: sls -l -> wsh ls -l
"s**" wsh $$

# 使用内置路径变量
open-config code %APP_CONFIG%
``` 

规则说明：

- 支持空行和 `#` 注释行。
- 如果模板命令包含 `--`，运行时参数会插入到 `--` 位置。
- 如果模板命令不包含 `--`，运行时参数会追加到末尾。
- alias 匹配采用“更长 alias 优先；同长度下更具体（通配符更少）优先”。
- `**` 规则要求必须捕获到非空内容（例如 `s` 不命中，`sls -l` 命中）。
- 如果别名未命中，将直接按原始命令执行（兼容普通命令调用）。
- 支持使用引号包裹复杂命令（如包含管道的命令）并直接执行。
- 使用 `--list` 或 `-l` 可在控制台查看融合后的 alias 列表。
- 使用 `--list-view` 或 `-lv` 可在独立弹窗中查看 alias 列表。
- 列表会按来源分组展示，来源信息单独显示在表格外部。
- 配置文件路径会先做 normalize，再用于展示与比较。

#### 用法

```bash
w <alias> [args...]
w --list
w -l
w --list-view
w -lv
```

#### Windows (CMD / PowerShell) 调用示例

```bat
sh\w.bat ab open
sh\w.bat foo --ping
sh\w.bat bar --age 40
sh\w.bat pcodex
sh\w.bat pcodex l
sh\w.bat pxhttp-server
sh\w.bat px http-server
sh\w.bat tool alpha beta
sh\w.bat sls -l
sh\w.bat echo hello
sh\w.bat "echo foo | findstr foo"
sh\w.bat --list
sh\w.bat -l
sh\w.bat --list-view
sh\w.bat -lv
```

可选环境变量：

- `WSHA_CONFIG_FILE`：自定义别名配置文件路径（设置后仅加载该文件）。

#### Clink 自动补全

仓库根目录下的 `clink-lua-scripts/` 提供了配套的 Clink Lua 补全脚本，当前覆盖：

- `w` / `wsha`
- `wsh`
- `wsh-ping`
- `wsh-fpatch`
- `wsh-real-ignore`
- `wsh-replace-cn-punc`

其中：

- `w` / `wsha` 会从 `config/wsh-alias.txt`、`%USERPROFILE%\.config\wsh-alias.txt`、`%CD%\.config\wsh-alias.txt` 读取 alias 候选。
- `wsh-ping` 会从 `config/wsh-ping.txt` 读取预设主机与端口候选。
- `wsh-fpatch` 会补全常见选项以及本仓库当前可见的 Git branch/tag。

Clink 使用方式示例：

```lua
-- 推荐直接引入聚合入口
dofile("E:/project/self.project/git-utils.sh/clink-lua-scripts/git-utils.lua")
```

可以直接增加以下环境变量来增加补全
```bash
set CLINK_PATH path\to\dir\git-utils.sh\clink-lua-scripts
# 直接在系统环境变量中增加
```

### 4. 忽略工作区文件 (`sh/wsh-real-ignore.sh`)

用于停止 Git 对指定文件或文件夹的追踪（从 Git 索引中移除），并自动将其添加到 `.gitignore` 中，**同时保留本地文件内容不被删除**。

这在处理如 IDE 配置文件（`.vscode`, `.idea`）、临时日志文件或误提交的敏感配置文件时非常有用。

#### 用法

```bash
# 基本用法
./sh/wsh-real-ignore.sh [选项] <文件路径或Glob模式>
```

#### Windows (Git Bash) 调用示例

```bash
# 忽略单个文件
git bash -c "./sh/wsh-real-ignore.sh .obsidian/workspace.json"

# 忽略文件夹
git bash -c "./sh/wsh-real-ignore.sh .vscode"

# 使用通配符 (注意需要加引号以避免Shell展开)
git bash -c "./sh/wsh-real-ignore.sh \"*.log\""
```

### 5. 中文标点替换 (`sh/wsh-replace-cn-punc.sh`)

用于批量将文件中的中文标点符号（如 `，` `。` `：`）替换为对应的英文标点符号（`，` `.` `:`）。这对于修复代码注释或 Markdown 文档中的标点误用非常有帮助。

支持的替换包括：逗号、句号、感叹号、问号、冒号、分号、引号、括号等。

#### 用法

```bash
# 基本用法
./sh/wsh-replace-cn-punc.sh <文件1> [文件2 ...]
```

#### Windows (Git Bash) 调用示例

```bash
# 替换单个文件
git bash -c "./sh/wsh-replace-cn-punc.sh README.md"

# 使用通配符批量替换
git bash -c "./sh/wsh-replace-cn-punc.sh \"docs/*.md\""
```

### 6. 基于提交提取变更文件 (`sh/wsh-fpatch.sh`)

根据 Git 提交记录（commit hash）提取变更的文件，并将**当前工作区中的最新版本**复制到指定目录。支持保持原有目录结构。

适用于需要将某次提交涉及的文件（包括新增和修改）打包导出的场景。

#### 用法

```bash
# 基本用法
./sh/wsh-fpatch.sh [选项] [commit1] [commit2]
```

参数说明：
- `commit1` (可选): 
    - 若仅指定 `commit1`: 对比该提交与当前工作区.
    - 若指定 `commit1` 和 `commit2`: 对比这两个提交.
- `commit2` (可选): 第二个提交哈希。
- `-o, --output <dir>`: 指定输出目录 (默认: `./path-files/YYYY-MM-DD_HH-MM-SS/`)。
- `-i, --input <dir>`: 仅包含指定目录下的文件，支持多个目录逗号分割与 glob（基于 repo 根目录，大小写敏感）。
- `-e, --exclude <dir>`: 排除指定目录下的文件，支持多个目录逗号分割与 glob（基于 repo 根目录，大小写敏感）。

#### Windows (Git Bash) 调用示例

```bash
# 对比最近一次提交与当前工作区，导出变更文件
git bash -c "./sh/wsh-fpatch.sh HEAD~1"

# 仅导出 notes 与 src 目录，排除 notes/tmp
git bash -c "./sh/wsh-fpatch.sh HEAD~1 -i ./notes,src -e ./notes/tmp"

# 对比两个提交，导出变更文件到指定目录
git bash -c "./sh/wsh-fpatch.sh <commit_hash_A> <commit_hash_B> -o ./my-patch"
```

---

## 开发与测试

本项目包含自动化测试脚本，确保代码质量。

### 运行所有测试

根目录下提供了便捷的测试运行脚本：

```bash
# 运行所有测试
./test-all.sh
# 或者在 Windows 下
git bash -c "./test-all.sh"
```

### 运行单个测试

测试脚本位于 `__test__` 目录下：

```bash
# 运行 ignore_workspace 的测试
git bash -c "./__test__/wsh-real-ignore.test.sh"

# 运行 replace_cn_punc_ 的测试
git bash -c "./__test__/wsh-replace-cn-punc.test.sh"

# 运行 wsha 的测试
git bash -c "./__test__/wsha.test.sh"
```

### 测试报告

每次运行测试后，会在 `__test__/report/` 目录下生成 Markdown 格式的测试报告，包含：
- 测试执行时间
- 每个用例的执行结果 (PASS/FAIL)
- 耗时统计

## 贡献

欢迎提交 Issue 或 Pull Request 来丰富这个脚本集合！

## 许可证

MIT License
