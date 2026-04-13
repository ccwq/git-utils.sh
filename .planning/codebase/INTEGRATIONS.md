# 外部集成

**分析日期:** 2026-04-13

## Shell 环境

**Git Bash (Windows):**
- 用作 Windows 上的主要 shell
- 通过 `bin/win-helper/win-helper.exe` 或 `sh/exec-git-bash.bat` 启动
- 路径解析优先级: 环境变量 `GIT_BASH` > 注册表缓存 > `where git` > 默认安装

## 命令别名（外部工具）

项目使用别名配置（`config/wsh-alias.txt`）调用外部工具:

**AI/Agent 工具:**
- `agent-browser` - 浏览器自动化（npm 包）
- `@openai/codex` - Codex CLI
- `@google/gemini-cli` - Gemini CLI
- `@anthropic-ai/claude-code` - Claude Code
- `opencode-ai` - OpenCode AI
- `browser-use` - 浏览器使用工具（通过 `uvx`）
- `gsd-pi` - GSD 工具

**开发工具:**
- `lazygit` - Git 终端 UI
- `docker` / `podman` - 容器工具
- `code` - VS Code 编辑器

**Node.js 包执行:**
- 使用 `pnpx` 执行包而不永久安装
- 示例: `pnpx agent-browser`, `pnpx @openai/codex`

## 文件存储

**本地配置:**
- `config/wsh-alias.txt` - 用户别名定义
- `config/wsh-ping.txt` - TCP ping 预设
- 用户配置: `$HOME/.config/wsh-alias.txt` (Linux) / `%USERPROFILE%\.config\wsh-alias.txt` (Windows)
- 项目配置: `$PWD/.config/wsh-alias.txt` (Linux) / `%CD%\.config\wsh-alias.txt` (Windows)

## 终端增强

**Clink (Windows):**
- `clink-lua-scripts/` 中的 Lua 脚本提供自动补全
- 覆盖: `w`/`wsha`, `wsh`, `wsh-ping`, `wsh-fpatch`, `wsh-real-ignore`, `wsh-replace-cn-punc`
- 用法: `dofile("path/to/git-utils.lua")` 或设置 `CLINK_PATH` 环境变量

## Windows 专用集成

**win-helper (Rust 二进制):**
- 位于 `bin/win-helper/win-helper.exe`
- 解析 Git Bash 路径并启动 bash 进程
- 无外部 Rust crate 依赖
- 使用 Windows 原生 API 进行进程创建

**tcping.exe:**
- TCP 连接测试工具
- 位于 `bin/tcping.exe`
- 由 `sh/wsh-ping.bat` 包装

## 使用的环境变量

**内置:**
- `APP_HOME` - 项目根目录绝对路径
- `APP_SH` - sh 目录绝对路径
- `APP_CONFIG` - config 目录绝对路径

**外部:**
- `GIT_BASH` - 覆盖 Git Bash 路径发现
- `WSHA_CONFIG_FILE` - 自定义别名配置文件路径
- `CLINK_PATH` - Clink 脚本目录
- `CDPORT` - 浏览器自动化的 CDP 端口

## CI/CD 与测试

**测试基础设施:**
- `__test__/` - 基于 Shell 的测试脚本
- `test-all.sh` - 测试运行器
- 在 `__test__/report/` 生成 Markdown 报告

**未检测到外部 CI 服务** - 测试通过 `npm test` 或 `./test-all.sh` 本地运行

## 依赖

**通过别名引用的直接 npm 包:**
- `agent-browser`
- `@openai/codex`
- `@google/gemini-cli`
- `@anthropic-ai/claude-code`
- `opencode-ai`
- `gsd-pi`
- `browser-use`

---

*集成审计: 2026-04-13*
