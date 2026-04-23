# `w` / `wsha` 命令说明

`w` / `wsha` 用于把简短 alias 展开成完整命令再执行，适合把常用 CLI、带默认参数的命令、带通配符模板的命令统一收敛到配置文件里管理。

## 入口

- Windows:
  - `w`
  - `wsha`
  - `sh\w.bat`
  - `sh\wsha.bat`
- Linux / macOS:
  - `bash sh/w.sh`
  - `bash sh/wsha.sh`

其中：

- `w` 是面向日常使用的简写入口
- `wsha` 是完整入口名
- Windows 下统一通过 `sh\exec-git-bash.bat` 进入 Git Bash，再执行 `wsha.sh`

## 基本用法

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

## 配置来源

按优先级从低到高加载，后者覆盖前者同名 alias：

1. `config/wsh-alias/*.txt`
2. `$HOME/.config/wsh-alias/*.txt`
3. `$PWD/.config/wsh-alias/*.txt`

说明：

- 以 `_` 开头的文件会被忽略
- 空行和 `#` 注释行会被忽略
- 同名 alias 以后加载的高优先级配置覆盖前面的配置

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

## 匹配规则

- alias 支持双引号包裹，用于包含空格，例如 `"pcodex l"`
- `*` 表示匹配一个 token，可在模板中通过 `$1`、`$2` 引用
- `**` 表示匹配剩余全部内容，可在模板中通过 `$$` 引用
- 匹配优先级遵循“更长 alias 优先，其次更具体的 alias 优先”
- alias 未命中时，会把原始命令直接透传执行

## 运行时参数合并

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

## 执行前日志

默认会在真正执行最终命令前打印日志到 `stderr`。

alias 命中时：

```text
[wsha] alias hit: w codex-l -> pnpx @openai/codex@latest
[wsha] exec: pnpx @openai/codex@latest
```

alias 未命中、直接透传时：

```text
[wsha] exec: echo hello
```

可以通过环境变量关闭：

```bash
set WSHA_PRINT_EXEC=0
```

或：

```bash
export WSHA_PRINT_EXEC=0
```

## 可选环境变量

- `WSHA_CONFIG_FILE`: 指定单个 alias 配置文件，设置后只加载该文件
- `WSHA_PRINT_EXEC`: 是否打印执行前日志，默认 `1`，设置为 `0` 时关闭

## Clink 自动补全

仓库提供了 `clink-lua-scripts/` 下的补全脚本，可用于：

- `w`
- `wsha`
- `wsh`
- `wsh-ping`
- `wsh-fpatch`
- `wsh-real-ignore`
- `wsh-replace-cn-punc`

推荐入口：

```lua
dofile("E:/project/self.project/git-utils.sh/clink-lua-scripts/git-utils.lua")
```
