# 技术栈

**分析日期:** 2026-04-13

## 编程语言

**主要语言:**
- Shell (Bash) - Linux/macOS/Windows Git Bash 的核心脚本
- Batch (.bat) - Windows 专用入口点和包装器

**次要语言:**
- Rust 2021 - Windows Git Bash 运行时 (`bin/win-helper/`)
- Lua - Clink 自动补全脚本 (`clink-lua-scripts/`)

## 运行时环境

**环境:**
- Git Bash (Windows) - Windows 用户的主要 shell 环境
- 标准 Bash (Linux/macOS)

**包管理器:**
- pnpm 10.21.0 - Node.js 包管理
- Lockfile: 不提交到仓库

## 框架

**核心:**
- Shell 脚本 (bash) - 主要实现语言
- Batch 脚本 - Windows 专用入口点

**构建/开发:**
- Cargo (Rust) - `win-helper` 的构建系统
- npm/pnpm - 任务运行和脚本编排

## 关键依赖

**关键依赖:**
- Git - 必需依赖（必须已安装）
- Git Bash - Windows 推荐使用

**基础设施:**
- `bin/tcping.exe` - TCP 连接测试工具 (Windows)
- `bin/win-helper/win-helper.exe` - 用于 Windows Git Bash 路径解析的 Rust 二进制文件

## 项目结构

**入口点:**
- `sh/exec-git-bash.bat` - Windows Git Bash 启动器
- `sh/w.bat` / `sh/wsha.bat` - Windows 别名包装器入口点
- `sh/w.sh` / `sh/wsha.sh` - Linux/macOS 别名包装器入口点

**配置:**
- `config/wsh-alias.txt` - 别名定义
- `config/wsh-ping.txt` - TCP ping 预设目标

**脚本位置:**
- `sh/` - 主要 shell/batch 脚本目录
- `scripts/init.bat` - 初始化脚本

**测试:**
- `__test__/` - 测试脚本目录
- `test-all.sh` - 测试运行脚本

## 平台要求

**开发环境:**
- 已安装 Git
- Bash shell (Linux/macOS) 或 Git Bash (Windows)

**生产环境:**
- 跨平台: Windows, Linux, macOS
- Windows 专用: Git Bash, 可选的 Clink 自动补全

---

*技术栈分析: 2026-04-13*
