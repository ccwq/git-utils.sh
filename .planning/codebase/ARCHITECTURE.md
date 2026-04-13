# 架构

**分析日期:** 2026-04-13

## 模式概述

**整体架构:** 跨平台 Windows Git Bash 抽象的实用工具脚本集合

**关键特征:**
- Shell 脚本 (.sh) 配合 Windows batch 文件 (.bat) 包装器实现跨平台支持
- 主要目的: 增强 Windows Git Bash 体验并提供 Git 相关实用工具
- 入口点模式: Windows 使用 batch 文件调用 `exec-git-bash.bat` 或 `win-helper.exe`，类 Unix 系统直接执行 shell 脚本
- 配置驱动的别名展开，支持通配符

## 层次结构

**Shell 脚本（核心逻辑）:**
- 用途: 跨平台实用工具实现
- 位置: `sh/`
- 内容: Git 辅助函数、别名展开、文件处理
- 依赖: 标准 Unix 工具 (sed, git, grep, awk)

**Windows 启动器（平台抽象）:**
- 用途: 解析 Git Bash 并调用 shell 脚本的 Windows 专用入口点
- 位置: `sh/*.bat`
- 内容: 包装 shell 脚本调用的 batch 文件
- 依赖: `bin/win-helper/win-helper.exe`（如果有）, `exec-git-bash.bat`

**二进制实用工具:**
- 用途: 提供 Windows 原生功能（TCP ping、Git Bash 辅助工具）
- 位置: `bin/`
- 内容: `tcping.exe`, `win-helper/` 目录

**配置层:**
- 用途: 用户可自定义的别名和预设配置
- 位置: `config/`, `$HOME/.config/`, `$PWD/.config/`

## 数据流

**wsha（别名展开）流程:**

1. 用户通过 Windows batch 或 Unix 上的 `bash sh/wsha.sh` 调用 `w <alias> [args...]`
2. 脚本从三个来源加载别名配置并合并优先级
3. 配置缓存到 `~/.cache/wsha/*.cache.sh`，使用文件时间戳验证
4. 输入被分词并与别名模式匹配，使用桶索引
5. 通过评分选择最佳匹配: `alias_count * 10000 + literal_chars * 100 - wildcard_weight`
6. 模板变量 (`$1`, `$2`, `$$`) 替换为捕获的值
7. 应用 `--` 占位符或追加逻辑处理运行时参数
8. 通过 `eval` 或规范化令牌数组执行命令

**wsh（Git Bash 启动器）流程:**

1. 用户通过 `sh/wsh.bat` 调用 `wsh [args...]`
2. Batch 文件检查 `bin/win-helper/win-helper.exe`（首选）
3. 回退到 `exec-git-bash.bat` 路径解析逻辑
4. Git Bash 解析方式: 继承环境变量 -> HKCU 注册表缓存 -> `where git` 相对路径 -> 默认安装路径
5. Git Bash 路径缓存在注册表中供后续调用
6. 命令传递给 Git Bash 执行

**wsh-fpatch（补丁提取）流程:**

1. 解析提交参数和过滤选项 (`-i`, `-e`)
2. 验证在 Git 仓库中运行
3. 确定 diff 模式: 单次提交 vs 当前工作树，或两次提交
4. 通过 `git diff --name-only` 和 `git ls-files` 收集更改的文件
5. 基于 glob 模式应用包含/排除过滤器
6. 将更改文件的当前工作树版本复制到输出目录，保持结构

## 关键抽象

**win-helper（Windows 运行时桥接）:**
- 用途: 启动 Git Bash 并正确处理路径的 Windows 原生可执行文件
- 示例: `bin/win-helper/win-helper.exe`
- 模式: 包装 Git Bash 调用的二进制文件，当 batch 不足时的回退方案

**exec-git-bash（Git Bash 解析器）:**
- 用途: 在 Windows 上定位和调用 Git Bash 的 batch 脚本
- 示例: `sh/exec-git-bash.bat`
- 模式: 多策略 Git Bash 发现，带注册表缓存

**wsha（别名启动器）:**
- 用途: 配置驱动的命令展开，带通配符匹配
- 示例: `sh/wsha.sh`（核心）, `sh/w.bat`（Windows 入口）, `sh/w.sh`（Unix 入口）
- 模式: 配置解析 -> 分词 -> 模式匹配 -> 模板展开 -> 执行

**wsh-real-ignore（Git 取消跟踪辅助）:**
- 用途: 从 Git 跟踪中移除文件，同时保留本地内容
- 示例: `sh/wsh-real-ignore.sh`
- 模式: `git rm --cached` + `.gitignore` 追加

## 入口点

**Windows Git Bash 执行:**
- 位置: `sh/exec-git-bash.bat`
- 触发: 直接命令或通过 `wsh.bat`、`wsha.bat`、`w.bat` 间接调用
- 职责: 解析 Git Bash 路径，设置环境，调用命令

**WSHA 别名启动器:**
- 位置: `sh/wsha.sh`（核心）, `sh/w.bat`（Windows）, `sh/w.sh`（Unix 符号链接）
- 触发: 用户调用 `w <alias>` 或 `wsha <alias>`
- 职责: 加载配置，匹配别名，展开模板，执行命令

**wsh Git Bash 启动器:**
- 位置: `sh/wsh.bat`
- 触发: 用户调用 `wsh [command]`
- 职责: 启动交互式 Git Bash 或执行单个命令

**wsh-ping TCP 检查器:**
- 位置: `sh/wsh-ping.bat`
- 触发: 用户调用 `wsh-ping` 或 `wsh-ping <host> <port> [options]`
- 职责: 读取预设，调用 `bin/tcping.exe`

## 错误处理

**策略:** 退出码配合 stderr 描述性消息

**模式:**
- `git rm --cached --ignore-unmatch` - 静默处理未跟踪的文件
- `if [ $? -eq 0 ]` - 在后续操作前检查命令成功
- `2>/dev/null` - 在适当的地方抑制不需要的错误输出
- 优雅降级: `win-helper.exe` 缺失 -> 回退到 batch 路径解析

## 横切关注点

**日志:** 通过 stdout/stderr 的 echo 语句，无结构化日志框架

**验证:**
- 通过 `git rev-parse --show-toplevel` 检查 Git 仓库
- 处理前检查文件存在性
- Windows 回车符移除 (`tr -d '\r'`)

**认证:** 不适用（此代码库无认证）

---

*架构分析: 2026-04-13*
