# `w` / `wsha` 使用手册：alias 与临时环境

> **一句话结论：** `w` / `wsha` 会先把 alias 展开为完整命令，再执行；通过 `-e/--env` 可以按调用顺序叠加 `KEY=VALUE` 或 UTF-8 `.env` 文件，变量只对本次子命令生效。

## 核心要点

- `w` 是日常简写入口，`wsha` 是完整入口；`w` 最终转发到 `wsha`。
- alias 支持精确匹配、单段 `*`、剩余参数 `**`、默认参数和递归 alias。
- `-e/--env` 兼容现有 `KEY=VALUE`，也支持每次加载一个 `.env` 文件；来源从左到右覆盖。
- `.env` 只作为数据文件解析，不会被 `source`、`eval` 或其他 shell 方式执行。
- 文件、格式或变量错误会在目标命令启动前失败；临时环境不会写回当前终端。

## 速览结论

### 基本用法

```bash
w <alias> [args...]
w --list
w -l
w --list-view
w -lv
```

```bash
w pcodex
w px http-server
w -e ./foo.env start-server
w -e ./foo.env -e ./foo.local.env -e PORT=3000 start-server
```

来源优先级从低到高为：

```text
当前进程环境 < ./foo.env < ./foo.local.env < PORT=3000
```

`.env` 文件按 UTF-8 读取，支持 BOM、空行、整行注释、`export`、空值和单/双引号值：

```dotenv
# comment
export NAME=ccwq
MESSAGE="hello world"
EMPTY=
```

相对路径以调用命令时的当前工作目录为基准；文件变量可以引用当前环境和前面已经声明的变量。不支持 shell 语句、命令替换、多行值或行尾注释。错误会在执行前返回 exit code `2`。

---

> **快速阅读到此结束。**
>
> 到这里已经可以运行 alias 和 `.env` 文件。以下内容进一步说明入口、匹配规则、环境来源、跨 shell 行为、安装方式和排障边界。

## 深度说明：入口与执行流程

### 一次调用的处理顺序

```text
命令行参数 → 识别 alias / env 来源 → 读取并解析 .env 文件
→ 按顺序物化临时环境 → 展开 alias 和运行时参数
→ 按目标 shell 渲染 → 启动目标子命令
```

环境变量只注入最终子命令及其子进程，不修改父 shell 的环境。`.env` 文件由 `sh/core/wsha_core.py` 读取，不由各个 shell wrapper 分别实现。

> **事实：** 本文描述的是仓库 `sh/` 运行时入口。`py/wsha/cli.py` 是另一套独立的 Click CLI，目前不与这里的 `-e/--env` 功能自动同步。

### 入口

- Windows:
  - `w`
  - `wsha`
  - `sh\w.bat`
  - `sh\wsha.bat`
  - `sh\w.ps1`
  - `sh\wsha.ps1`
- Linux / macOS:
  - `bash sh/w.sh`
  - `bash sh/wsha.sh`

其中：

- `w` 是面向日常使用的简写入口
- `wsha` 是完整入口名
- `w` 最终会转发到 `wsha`

## 配置来源

按优先级从低到高加载，后者覆盖前者同名 alias：

1. `sh/config/wsh-alias/*.txt`
2. `$HOME/.config/wsh-alias/*.txt`
3. `$PWD/.config/wsh-alias/*.txt`

说明：

- 以 `_` 开头的文件会被忽略
- 空行和 `#` 注释行会被忽略
- 同名 alias 以后加载的高优先级配置覆盖前面的配置
- `APP_CONFIG` 默认解析为 `$APP_HOME/sh/config`
- 旧版 `$APP_HOME/config` 仅作为兼容 fallback

## 配置格式

每行一个 alias：

```txt
<alias> <target...>
```

示例：

```txt
ab pnpx agent-browser
foo foobar open
bar barbar -- --name ccwq

pcodex pnpx @openai/codex
"pcodex l" pnpx @openai/codex@latest

"px*" pnpx $1
"px *" "pnpx $1"
"tool * *" echo $1::$2
"s**" wsh $$

open-config code %APP_CONFIG%
```

### 匹配规则

- alias 支持双引号包裹，用于包含空格，例如 `"pcodex l"`
- `*` 表示匹配一个 token，可在模板中通过 `$1`、`$2` 引用
- `**` 表示匹配剩余全部内容，可在模板中通过 `$$` 引用
- 匹配优先级遵循“更长 alias 优先，其次更具体的 alias 优先”
- alias 未命中时，会把原始命令直接透传执行

### 运行时参数合并

如果模板里包含单独的 `--` token，运行时参数会插入到这个位置；否则追加到命令末尾。

示例：

```txt
bar barbar -- --name ccwq
```

执行：

```bash
w bar --age 40
```

实际展开为：

```bash
barbar --age 40 --name ccwq
```

## 深度说明：`-e/--env` 环境来源

### 文件与赋值的组合

每个文件单独使用一次 `-e/--env`；命令行赋值仍可在同一调用中连续出现：

```bash
w -e ./foo.env -e ./foo.local.env -e PORT=3000 start-server
w --env=./foo.env printenv NAME
```

`KEY=VALUE` 优先按赋值处理；带 `./`、`../`、绝对路径、路径分隔符或 `.env` / `.env.*` 名称的 token 才作为文件候选。文件候选不存在、不可读或指向目录时立即报错；普通字符串不会被静默当作文件。

### 覆盖与引用顺序

```text
当前进程环境 → ./foo.env → ./foo.local.env → PORT=3000
```

后出现的值覆盖前面的同名值。文件内部也按从上到下处理：

```dotenv
HOST=example.test
URL=https://$HOST/api
```

文件变量可以参与 alias、嵌套 alias 和最终参数展开；只对本次子命令及其子进程生效。

### 语法、路径与错误

- 使用 UTF-8 读取并自动处理 BOM；忽略空行和整行注释。
- key 必须匹配 `[A-Za-z_][A-Za-z0-9_]*`；`KEY=` 表示空字符串。
- 支持未加引号、单引号和双引号值；值中的 `=` 和 `#` 默认是普通字符。
- 不支持 shell 语句、命令替换、多行值、行尾注释语义或复杂 shell 转义。
- 支持 `%VAR%`、`$VAR`、`${VAR}`、`$env:VAR`、`${env:VAR}` 和 `~`。
- 相对文件路径使用调用命令时的当前工作目录，并采用 Linux 风格示例，例如 `./config/foo.env`。
- Git Bash 使用 `/c/...`，CMD 和 PowerShell 使用 `C:\...`；URI 和歧义文本保持原样。
- 文件、格式或未定义变量错误会在目标启动前返回 exit code `2`。

## 深度说明：跨 shell 行为

### Git Bash

```bash
bash sh/wsha.sh -e ./foo.env printenv NAME
```

### CMD

```bat
sh\wsha.bat -e ./foo.env cmd /d /c "set NAME"
```

包含 CMD 元字符的复杂环境值通过运行时 helper 传递，避免 CMD 多次解析把值当成控制语法；`.env` 文件本身不会交给 CMD 读取或执行。

### PowerShell

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File sh\wsha.ps1 -e ./foo.env powershell -NoProfile -Command 'Write-Output $env:NAME'
```

wrapper 保留原始参数顺序，把重复 `-e/--env` 交给 core 统一解析；目标命令退出码会继续返回给调用方。

## 安装与删除

### 方式一：远程安装运行时

```bash
curl -fsSL https://raw.githubusercontent.com/ccwq/git-utils.sh/master/scripts/remote-install.sh | bash
```

源码仓库中的本地安装入口位于 `scripts/install.sh`。

默认安装位置：

- 运行时主体：`~/.local/share/git-utils.sh`
- launcher：`~/.local/bin/w`、`~/.local/bin/wsha`、`~/.local/bin/wsh`

安装完成后会输出 report，列出：

- 写入的文件
- 创建的 launcher
- 是否检测到旧布局
- 是否需要手动补 PATH

Windows 约束：

- 安装脚本只支持在 Git Bash 中执行
- 安装后可使用 Git Bash、CMD 或 PowerShell
- PowerShell 原生 launcher 位于 `<install_root>\bin\wsha.ps1`（`w.ps1` 为简写入口）

### 方式二：仓库内直接运行

```bash
git clone https://github.com/ccwq/git-utils.sh.git
cd git-utils.sh
bash sh/wsha.sh --list
```

Windows 下也可以：

```bat
sh\core\exec-git-bash.bat sh\wsha.sh --list

# PowerShell 原生入口
powershell -NoProfile -ExecutionPolicy Bypass -File sh\wsha.ps1 -e name=ccwq Write-Output '$env:name'
```

### 卸载

如果是远程安装的运行时：

```bash
bash ~/.local/share/git-utils.sh/sh/uninstall.sh --yes
```

默认行为：

- 删除安装目录中的运行时文件
- 删除对应 launcher
- 保留用户配置 `~/.config/wsh-alias`

如需一并删除用户配置，需要显式传参：

```bash
bash ~/.local/share/git-utils.sh/sh/uninstall.sh --yes --remove-user-config
```

## Cookbook

### 1. 给常用 CLI 建短命令

```txt
codex pnpx @openai/codex
codex-l pnpx @openai/codex@latest
gemini pnpx @google/gemini-cli
```

使用：

```bash
w codex
w codex-l
w gemini
```

### 2. 给命令补默认参数

```txt
claude-yo wsha claude-l --dangerously-skip-permissions
git.sync git pull && git push
```

使用：

```bash
w claude-yo
w git.sync
```

### 3. 使用单段通配符

```txt
"px*" pnpx $1
"px *" pnpx $1
```

使用：

```bash
w pxhttp-server
w px http-server
```

### 4. 使用剩余参数捕获

```txt
"s**" wsh $$
```

使用：

```bash
w sls -lah
```

实际会转成：

```bash
wsh ls -lah
```

### 5. 编辑内置配置目录

```txt
open-config code %APP_CONFIG%
```

使用：

```bash
w open-config
```

### 6. 查看当前实际生效的 alias

```bash
w -l
w -lv
```

适合用来确认：

- 当前命中了哪些内置 alias
- 用户目录是否覆盖了内置 alias
- 工作目录 `.config/wsh-alias` 是否覆盖了更高层配置

## 环境变量

- `WSHA_CONFIG_FILE`: 指定单个 alias 配置文件，设置后只加载该文件
- `WSHA_PRINT_EXEC`: 是否打印执行前日志，默认 `1`，设置为 `0` 时关闭
- `APP_HOME`: 运行时根目录
- `APP_SH`: 运行时 shell 目录
- `APP_CONFIG`: 运行时配置目录

## 边界与行动

### 适用边界

- `.env` 加载能力属于 `sh/` 运行时入口；不要据此推断独立的 `py/wsha/cli.py` 已具备相同参数。
- `.env` 必须是本地可读文件；不会从 URI、网络地址或 shell 命令读取。
- `.env` 适合保存本次命令需要的非交互式环境配置；敏感信息仍应按团队凭据管理规范处理。
- 每个文件使用一个 `-e`；不要写成 `-e ./a.env ./b.env`。

### 下一步验证

```bash
w -e ./foo.env printenv NAME
w -e ./foo.env -e ./foo.local.env printenv NAME
```

若返回 exit code `2`，检查错误中的文件路径、行号、key 名和变量引用；若只在某个 shell 失败，检查目标 shell 的路径、引号和特殊字符规则。

## 相关文档

- 详细安装/编译/发布说明见 [docs/INSTALL.md](./INSTALL.md)
- 其他脚本说明仍见 [README.md](../README.md)
