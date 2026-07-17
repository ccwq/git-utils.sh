# `w` / `wsha` 使用手册

`w` / `wsha` 用于把简短 alias 展开成完整命令再执行，适合把常用 CLI、带默认参数的命令、带通配符模板的命令统一收敛到配置文件里管理。

## 功能介绍

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

### 核心能力

- 通过 alias 将短命令展开为完整命令
- 支持 `*` 单段通配符和 `**` 剩余参数捕获
- 支持默认参数与运行时参数合并
- 支持 `--list` / `-l` 查看当前融合后的 alias 列表
- 支持 `--list-view` / `-lv` 查看更详细的视图
- 默认在执行前打印 `alias hit` / `exec` 预览日志
- 支持 `-e` / `--env` 为单次命令注入临时环境变量

### 基本用法

```bash
w <alias> [args...]
w --list
w -l
w --list-view
w -lv
```

示例：

```bash
w pcodex
w pcodex l
w px http-server
w sls -l
w "echo foo | findstr foo"
```

### 单次环境变量注入

`-e` 与 `--env` 后连续读取 `KEY=VALUE`；第一个非赋值 token 起是要执行的 alias 或命令。变量仅对本次子命令生效。

```bash
wsha -e name=ccwq tag="env plan" ping t.cn
wsha --env ROOT=%USERPROFILE%\workspace printenv ROOT
```

- 当前环境变量可写成 `%VAR%`、`$VAR`、`${VAR}`、`$env:VAR` 或 `${env:VAR}`；本次 `-e` 赋值优先于当前环境，且可从左到右互相引用。
- 未定义变量会在执行前报错，exit code 为 `2`。
- 只转换本地绝对路径、带 `./` / `../` / `\` 证据的相对路径以及 `~`；`https://`、`file://`、`socks5://`、`feature/foo` 等 URI 或歧义文本保持原样。
- Git Bash 使用 `/c/...`，CMD 与 PowerShell 使用 `C:\...`；CMD/PowerShell 中的 `~` 也会展开为用户目录。
- Bash/Git Bash、CMD、PowerShell 会分别生成对应的临时环境变量设置语法。

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

## 相关文档

- 详细安装/编译/发布说明见 [docs/INSTALL.md](./INSTALL.md)
- 其他脚本说明仍见 [README.md](../README.md)
