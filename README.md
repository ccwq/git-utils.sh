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

### 1. 忽略工作区文件 (`ignore_workspace.sh`)

用于停止 Git 对指定文件或文件夹的追踪（从 Git 索引中移除），并自动将其添加到 `.gitignore` 中，**同时保留本地文件内容不被删除**。

这在处理如 IDE 配置文件（`.vscode`, `.idea`）、临时日志文件或误提交的敏感配置文件时非常有用。

#### 用法

```bash
./sh/ignore_workspace.sh [选项] <文件路径或Glob模式>
```

#### Windows (Git Bash) 调用示例

```bash
# 忽略单个文件
git bash -c "./sh/ignore_workspace.sh .obsidian/workspace.json"

# 忽略文件夹
git bash -c "./sh/ignore_workspace.sh .vscode"

# 使用通配符 (注意需要加引号)
git bash -c "./sh/ignore_workspace.sh \"*.log\""
```

#### 参数说明

- `文件路径或Glob`: 需要取消 Git 追踪的目标。
- `-h, --help`: 显示帮助信息。

---

## 开发与测试

本项目包含自动化测试脚本，用于验证脚本功能的正确性。

### 运行测试

测试脚本位于 `__test__` 目录下。

```bash
# 运行 ignore_workspace 的测试
git bash -c "./__test__/ignore_workspace.test.sh"
```

测试脚本会自动：
1. 创建临时的测试环境。
2. 初始化 Git 仓库并模拟文件操作。
3. 执行脚本并验证结果（文件是否保留、索引是否移除、gitignore 是否更新）。
4. 在 `__test__/report/` 目录下生成 Markdown 格式的测试报告。

## 贡献

欢迎提交 Issue 或 Pull Request 来丰富这个脚本集合！

## 许可证

MIT License
