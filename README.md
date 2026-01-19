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

### 1. 忽略工作区文件 (`sh/ignore_workspace.sh`)

用于停止 Git 对指定文件或文件夹的追踪（从 Git 索引中移除），并自动将其添加到 `.gitignore` 中，**同时保留本地文件内容不被删除**。

这在处理如 IDE 配置文件（`.vscode`, `.idea`）、临时日志文件或误提交的敏感配置文件时非常有用。

#### 用法

```bash
# 基本用法
./sh/ignore_workspace.sh [选项] <文件路径或Glob模式>
```

#### Windows (Git Bash) 调用示例

```bash
# 忽略单个文件
git bash -c "./sh/ignore_workspace.sh .obsidian/workspace.json"

# 忽略文件夹
git bash -c "./sh/ignore_workspace.sh .vscode"

# 使用通配符 (注意需要加引号以避免Shell展开)
git bash -c "./sh/ignore_workspace.sh \"*.log\""
```

### 2. 中文标点替换 (`sh/replace_cn_punc_.sh`)

用于批量将文件中的中文标点符号（如 `，` `。` `：`）替换为对应的英文标点符号（`，` `.` `:`）。这对于修复代码注释或 Markdown 文档中的标点误用非常有帮助。

支持的替换包括：逗号、句号、感叹号、问号、冒号、分号、引号、括号等。

#### 用法

```bash
# 基本用法
./sh/replace_cn_punc_.sh <文件1> [文件2 ...]
```

#### Windows (Git Bash) 调用示例

```bash
# 替换单个文件
git bash -c "./sh/replace_cn_punc_.sh README.md"

# 使用通配符批量替换
git bash -c "./sh/replace_cn_punc_.sh \"docs/*.md\""
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
git bash -c "./__test__/ignore_workspace.test.sh"

# 运行 replace_cn_punc_ 的测试
git bash -c "./__test__/replace_cn_punc_.test.sh"
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
