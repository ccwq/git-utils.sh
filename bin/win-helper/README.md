# win-helper

`win-helper` 是项目内置的 Windows 专用 Git Bash 运行时。

它的职责很单一：

- 解析本机 Git Bash 的 `bash.exe` 路径
- 缓存解析结果，减少重复查找
- 将收到的参数原样转发给 `bash.exe`
- 作为 `sh\exec-git-bash.bat` 的优先底层实现

## 适用范围

仅用于 Windows。

在 Linux / macOS 下，不需要这个运行时，项目仍然直接使用 shell 脚本。

## 解决的问题

这个运行时主要用于替代脆弱的 batch 参数桥接层，减少以下问题：

- `git bash -c ...` 这类不稳定调用方式
- `%*` 拼接导致的空格路径、引号边界问题
- Windows `cmd` / `.bat` 对参数的二次解析污染
- Git Bash 启动路径发现逻辑分散在多个入口脚本中

## 技术实现

技术栈：

- Rust 2021
- Windows 原生进程启动
- 不依赖第三方 Rust crate

核心流程：

1. 读取命令行参数
2. 解析 Git Bash 路径，优先级如下：
   - 环境变量 `GIT_BASH`
   - 注册表缓存 `HKCU\Environment\GIT_BASH`
   - `where git` 反推 Git 安装目录下的 `bash.exe`
   - 默认安装目录 `%ProgramFiles%\Git\...`
3. 将成功解析出的路径写回：
   - 当前进程环境变量 `GIT_BASH`
   - 用户级缓存 `setx GIT_BASH ...`
4. 用解析出的 `bash.exe` 原样转发 argv，并透传退出码

当前实现刻意保持精简：

- 不负责 alias 展开
- 不负责业务命令拼接
- 不做额外 shell 语义判断
- 只做“找 Git Bash + 启动 Git Bash + 透传参数”

这些业务逻辑仍然在项目的批处理和 shell 脚本层处理，例如：

- `sh\exec-git-bash.bat`
- `sh\w.bat`
- `sh\wsha.bat`
- `sh\wsha.sh`

## 构建

在 Windows 下执行：

```bat
pnpm run build:win-helper
```

或直接执行：

```bat
bin\win-helper\build.bat
```

构建产物固定输出到：

```bat
bin\win-helper\win-helper.exe
```

## 用法

查看当前解析到的 Git Bash 路径：

```bat
bin\win-helper\win-helper.exe --print-path
```

执行单条 Git Bash 命令：

```bat
bin\win-helper\win-helper.exe -lc "printf hello"
```

执行脚本文件：

```bat
bin\win-helper\win-helper.exe .\sh\wsha.sh --list
```

## 设计取舍

这个运行时的目标是“小而稳”，不是功能越多越好。

因此它不试图替代项目已有脚本，而是作为 Windows 下最薄的一层启动器：

- batch 负责入口兼容
- shell 脚本负责业务语义
- `win-helper` 负责稳定地启动 Git Bash
