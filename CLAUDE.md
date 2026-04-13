<!-- GSD:project-start source:PROJECT.md -->
## Project

**git-utils.sh**

跨平台 Windows Git Bash 实用工具集合，提供别名展开、Git 辅助工具和 Windows Shell 增强功能。核心工具 wsha 通过模式匹配和模板展开实现智能命令行别名。

**Core Value:** 让命令行别名真正有用 — 通配符匹配、参数捕获、模板展开，而非静态字符串替换。

### Constraints

- **兼容性**: Python 版本必须通过现有 `__test__/wsha.test.sh` 测试
- **共存策略**: wsha.sh 和 Python 版本并行存在，共享配置
- **执行路径**: 用户输入 `w <alias>` 时默认 Python，wsha.sh 作为 fallback
- **发布**: 支持 `uvx wsha` 运行和 pip 全局安装
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## 编程语言
- Shell (Bash) - Linux/macOS/Windows Git Bash 的核心脚本
- Batch (.bat) - Windows 专用入口点和包装器
- Rust 2021 - Windows Git Bash 运行时 (`bin/win-helper/`)
- Lua - Clink 自动补全脚本 (`clink-lua-scripts/`)
## 运行时环境
- Git Bash (Windows) - Windows 用户的主要 shell 环境
- 标准 Bash (Linux/macOS)
- pnpm 10.21.0 - Node.js 包管理
- Lockfile: 不提交到仓库
## 框架
- Shell 脚本 (bash) - 主要实现语言
- Batch 脚本 - Windows 专用入口点
- Cargo (Rust) - `win-helper` 的构建系统
- npm/pnpm - 任务运行和脚本编排
## 关键依赖
- Git - 必需依赖（必须已安装）
- Git Bash - Windows 推荐使用
- `bin/tcping.exe` - TCP 连接测试工具 (Windows)
- `bin/win-helper/win-helper.exe` - 用于 Windows Git Bash 路径解析的 Rust 二进制文件
## 项目结构
- `sh/exec-git-bash.bat` - Windows Git Bash 启动器
- `sh/w.bat` / `sh/wsha.bat` - Windows 别名包装器入口点
- `sh/w.sh` / `sh/wsha.sh` - Linux/macOS 别名包装器入口点
- `config/wsh-alias.txt` - 别名定义
- `config/wsh-ping.txt` - TCP ping 预设目标
- `sh/` - 主要 shell/batch 脚本目录
- `scripts/init.bat` - 初始化脚本
- `__test__/` - 测试脚本目录
- `test-all.sh` - 测试运行脚本
## 平台要求
- 已安装 Git
- Bash shell (Linux/macOS) 或 Git Bash (Windows)
- 跨平台: Windows, Linux, macOS
- Windows 专用: Git Bash, 可选的 Clink 自动补全
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## 项目概述
## Shell 脚本标准
- Bash 脚本使用 `#!/bin/bash`
- Windows batch 文件使用 `.bat` 扩展名和 CMD 语法
- Shell 脚本: `*.sh`（如 `wsh-real-ignore.sh`, `wsha.sh`）
- Windows batch: `*.bat`（如 `wsh.bat`, `wsha.bat`）
- 测试文件: `__test__/` 目录中的 `*_test.sh` 或 `*.test.sh`
## 代码风格
- 缩进: 4 个空格（不是 Tab）
- 行不应超过 120 个字符
- 使用空行分隔逻辑部分
- 命令后跟中文注释进行解释
- 常量: 大写（如 `GREEN`, `NC`）
- 常规变量: 小写加下划线（如 `target_file`, `output_dir`）
- 临时变量: 带下划线前缀或描述性名称（如 `_CMD_TOKENS`）
- 数组变量: 复数或描述性名称（如 `input_patterns`, `exclude_patterns`）
## 函数设计
#!/bin/bash
- 函数局部变量使用 `local`
- 返回码: 0 表示成功，非零表示失败
- 使用 `local var=$(...)` 模式进行命令替换
- 按位置传递参数 (`$1`, `$2` 等)
## 错误处理
## 字符串处理
- 包含路径或用户输入的变量始终加引号: `"$variable"`
- 不应展开的字符串使用单引号
- 有变量展开的字符串使用双引号
## 日志和输出
## 路径处理
## 导入和包含模式
## 模式: 参数解析
## 模式: 数组处理
## 模式: 命令输出捕获
## Shell 兼容性
- 主要: Windows Git Bash (bash 4.x)
- 也支持: Linux, macOS, WSL
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## 模式概述
- Shell 脚本 (.sh) 配合 Windows batch 文件 (.bat) 包装器实现跨平台支持
- 主要目的: 增强 Windows Git Bash 体验并提供 Git 相关实用工具
- 入口点模式: Windows 使用 batch 文件调用 `exec-git-bash.bat` 或 `win-helper.exe`，类 Unix 系统直接执行 shell 脚本
- 配置驱动的别名展开，支持通配符
## 层次结构
- 用途: 跨平台实用工具实现
- 位置: `sh/`
- 内容: Git 辅助函数、别名展开、文件处理
- 依赖: 标准 Unix 工具 (sed, git, grep, awk)
- 用途: 解析 Git Bash 并调用 shell 脚本的 Windows 专用入口点
- 位置: `sh/*.bat`
- 内容: 包装 shell 脚本调用的 batch 文件
- 依赖: `bin/win-helper/win-helper.exe`（如果有）, `exec-git-bash.bat`
- 用途: 提供 Windows 原生功能（TCP ping、Git Bash 辅助工具）
- 位置: `bin/`
- 内容: `tcping.exe`, `win-helper/` 目录
- 用途: 用户可自定义的别名和预设配置
- 位置: `config/`, `$HOME/.config/`, `$PWD/.config/`
## 数据流
## 关键抽象
- 用途: 启动 Git Bash 并正确处理路径的 Windows 原生可执行文件
- 示例: `bin/win-helper/win-helper.exe`
- 模式: 包装 Git Bash 调用的二进制文件，当 batch 不足时的回退方案
- 用途: 在 Windows 上定位和调用 Git Bash 的 batch 脚本
- 示例: `sh/exec-git-bash.bat`
- 模式: 多策略 Git Bash 发现，带注册表缓存
- 用途: 配置驱动的命令展开，带通配符匹配
- 示例: `sh/wsha.sh`（核心）, `sh/w.bat`（Windows 入口）, `sh/w.sh`（Unix 入口）
- 模式: 配置解析 -> 分词 -> 模式匹配 -> 模板展开 -> 执行
- 用途: 从 Git 跟踪中移除文件，同时保留本地内容
- 示例: `sh/wsh-real-ignore.sh`
- 模式: `git rm --cached` + `.gitignore` 追加
## 入口点
- 位置: `sh/exec-git-bash.bat`
- 触发: 直接命令或通过 `wsh.bat`、`wsha.bat`、`w.bat` 间接调用
- 职责: 解析 Git Bash 路径，设置环境，调用命令
- 位置: `sh/wsha.sh`（核心）, `sh/w.bat`（Windows）, `sh/w.sh`（Unix 符号链接）
- 触发: 用户调用 `w <alias>` 或 `wsha <alias>`
- 职责: 加载配置，匹配别名，展开模板，执行命令
- 位置: `sh/wsh.bat`
- 触发: 用户调用 `wsh [command]`
- 职责: 启动交互式 Git Bash 或执行单个命令
- 位置: `sh/wsh-ping.bat`
- 触发: 用户调用 `wsh-ping` 或 `wsh-ping <host> <port> [options]`
- 职责: 读取预设，调用 `bin/tcping.exe`
## 错误处理
- `git rm --cached --ignore-unmatch` - 静默处理未跟踪的文件
- `if [ $? -eq 0 ]` - 在后续操作前检查命令成功
- `2>/dev/null` - 在适当的地方抑制不需要的错误输出
- 优雅降级: `win-helper.exe` 缺失 -> 回退到 batch 路径解析
## 横切关注点
- 通过 `git rev-parse --show-toplevel` 检查 Git 仓库
- 处理前检查文件存在性
- Windows 回车符移除 (`tr -d '\r'`)
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

| Skill | Description | Path |
|-------|-------------|------|
| openspec-apply-change | Implement tasks from an OpenSpec change. Use when the user wants to start implementing, continue implementation, or work through tasks. | `.claude/skills/openspec-apply-change/SKILL.md` |
| openspec-archive-change | Archive a completed change in the experimental workflow. Use when the user wants to finalize and archive a change after implementation is complete. | `.claude/skills/openspec-archive-change/SKILL.md` |
| openspec-bulk-archive-change | Archive multiple completed changes at once. Use when archiving several parallel changes. | `.claude/skills/openspec-bulk-archive-change/SKILL.md` |
| openspec-continue-change | Continue working on an OpenSpec change by creating the next artifact. Use when the user wants to progress their change, create the next artifact, or continue their workflow. | `.claude/skills/openspec-continue-change/SKILL.md` |
| openspec-explore | Enter explore mode - a thinking partner for exploring ideas, investigating problems, and clarifying requirements. Use when the user wants to think through something before or during a change. | `.claude/skills/openspec-explore/SKILL.md` |
| openspec-ff-change | Fast-forward through OpenSpec artifact creation. Use when the user wants to quickly create all artifacts needed for implementation without stepping through each one individually. | `.claude/skills/openspec-ff-change/SKILL.md` |
| openspec-new-change | Start a new OpenSpec change using the experimental artifact workflow. Use when the user wants to create a new feature, fix, or modification with a structured step-by-step approach. | `.claude/skills/openspec-new-change/SKILL.md` |
| openspec-onboard | Guided onboarding for OpenSpec - walk through a complete workflow cycle with narration and real codebase work. | `.claude/skills/openspec-onboard/SKILL.md` |
| openspec-propose | Propose a new change with all artifacts generated in one step. Use when the user wants to quickly describe what they want to build and get a complete proposal with design, specs, and tasks ready for implementation. | `.claude/skills/openspec-propose/SKILL.md` |
| openspec-sync-specs | Sync delta specs from a change to main specs. Use when the user wants to update main specs with changes from a delta spec, without archiving the change. | `.claude/skills/openspec-sync-specs/SKILL.md` |
| openspec-verify-change | Verify implementation matches change artifacts. Use when the user wants to validate that implementation is complete, correct, and coherent before archiving. | `.claude/skills/openspec-verify-change/SKILL.md` |
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
