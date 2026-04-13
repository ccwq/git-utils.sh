# 代码库结构

**分析日期:** 2026-04-13

## 目录布局

```
git-utils.sh/
├── bin/                    # 二进制实用工具
│   ├── win-helper/         # Windows Git Bash 运行时辅助工具
│   └── tcping.exe          # TCP 连接检查器
├── clink-lua-scripts/      # Clink 自动补全脚本
├── config/                 # 配置文件
│   ├── wsh-alias.txt       # 内置别名定义
│   └── wsh-ping.txt        # TCP ping 预设
├── docs/                   # 文档
├── openspec/               # OpenSpec 相关文件
├── patch-files/            # wsh-fpatch 默认输出
├── prompts/                # 提示模板
├── scripts/                # 构建/实用工具脚本
│   └── init.bat            # 安装脚本
├── sh/                     # Shell 脚本（核心实用工具）
│   ├── exec-git-bash.bat   # Git Bash 启动器（Windows 入口）
│   ├── w.bat              # Windows 别名启动器包装器
│   ├── w.sh               # Unix 别名启动器包装器
│   ├── wsha.bat           # Windows wsha 启动器
│   ├── wsha.sh            # 核心别名展开脚本（33KB）
│   ├── wsh.bat            # Windows Git Bash 启动器包装器
│   ├── wsh-fpatch.sh      # Git 补丁提取实用工具
│   ├── wsh-ping.bat       # TCP ping 启动器
│   ├── wsh-real-ignore.sh # Git 取消跟踪实用工具
│   └── wsh-replace-cn-punc.sh # 中文标点替换器
├── __test__/               # 测试套件
│   ├── report/             # 测试执行报告
│   ├── wsha.test.sh        # wsha 别名展开测试
│   ├── wsh-fpatch.test.sh  # wsh-fpatch 测试
│   ├── wsh-real-ignore.test.sh
│   ├── wsh-replace-cn-punc.test.sh
│   └── init.test.sh
├── .agent/                 # Agent 技能（openspec）
├── .claude/                # GSD agent 配置
│   ├── agents/             # GSD agent 定义
│   ├── commands/           # GSD 命令定义
│   └── skills/             # GSD 技能定义
├── .codex/                 # Codex 配置
├── .history/               # 命令历史
├── .iflow/                 # Flow 状态
├── .qwen/                  # Qwen 配置
├── .trae/                  # Trae 配置
└── test-all.sh             # 测试运行脚本
```

## 目录用途

**sh/:**
- 用途: 核心 shell 脚本和 Windows 启动器
- 内容: 所有可执行脚本（.sh 和 .bat）
- 关键文件: `wsha.sh`（最大最复杂）, `wsh-fpatch.sh`, `wsh-real-ignore.sh`, `wsh-replace-cn-punc.sh`, `exec-git-bash.bat`

**bin/:**
- 用途: 原生 Windows 可执行文件
- 内容: `tcping.exe`（TCP 连接检查器）, `win-helper/` 子目录
- 关键文件: `win-helper/win-helper.exe`（Git Bash 运行时桥接）

**bin/win-helper/:**
- 用途: Windows Git Bash 辅助工具（Go 二进制）
- 内容: 构建脚本和编译后的可执行文件
- 关键文件: `win-helper.exe`（构建的二进制）

**config/:**
- 用途: 内置配置文件
- 内容: 别名定义和 TCP ping 预设
- 关键文件: `wsh-alias.txt`（主要别名配置）, `wsh-ping.txt`（TCP 主机）

**__test__/:**
- 用途: 自动化测试套件
- 内容: 基于 Shell 的测试脚本
- 关键文件: `wsha.test.sh`（33KB 测试套件）, `wsh-fpatch.test.sh`, `test_utils.sh`

**scripts/:**
- 用途: 构建和安装脚本
- 内容: 用于 PATH 设置的 `init.bat`

**clink-lua-scripts/:**
- 用途: Windows Clink shell 自动补全
- 内容: 命令补全的 Lua 脚本

**.claude/, .agent/, .codex/:**
- 用途: Agent/AI 助手配置（GSD 框架、Codex 等）
- 这些是 AI agent 的基础设施，不是核心功能

## 关键文件位置

**入口点:**
- `sh/exec-git-bash.bat`: Windows Git Bash 调用入口
- `sh/wsha.sh`: 核心别名展开逻辑
- `sh/w.bat`: Windows 别名命令入口
- `sh/w.sh`: Unix 别名命令入口
- `sh/wsh.bat`: Windows Git Bash 启动器入口

**配置:**
- `config/wsh-alias.txt`: 内置别名定义
- `config/wsh-ping.txt`: TCP ping 主机预设

**核心逻辑:**
- `sh/wsha.sh`: 1064 行 - 带通配符匹配的别名展开，配置缓存
- `sh/wsh-fpatch.sh`: 286 行 - Git 补丁文件提取
- `sh/wsh-real-ignore.sh`: 67 行 - Git 取消跟踪实用工具
- `sh/wsh-replace-cn-punc.sh`: 101 行 - 中文标点替换

**测试:**
- `__test__/wsha.test.sh`: 33KB 综合测试套件
- `__test__/wsh-fpatch.test.sh`: 8KB 补丁提取测试
- `test-all.sh`: 执行所有 `__test__/*.sh` 文件的测试运行器

**构建:**
- `package.json`: 用于 `init` 和 `build:win-helper` 的 npm 脚本
- `bin/win-helper/build.bat`: Windows 辅助工具构建脚本

## 命名约定

**文件:**
- Shell 脚本: `snake_case.sh`（如 `wsh_real_ignore.sh`）
- Windows batch: `snake_case.bat`（如 `wsh.bat`）
- 核心脚本前缀为 `wsh-` 表示 Windows Shell 实用工具
- `wsha` = Windows Shell Alias
- Windows 包装器与 Unix 对应物匹配（如 `w.bat` 包装 `w.sh`）

**目录:**
- 功能目录使用小写和连字符（`bin/`, `sh/`, `config/`）
- 特殊用途使用下划线（`__test__/`, `patch-files/`）

## 新增代码的位置

**新的 Shell 实用工具:**
- 主要实现: `sh/<utility-name>.sh`
- Windows 启动器（如需要）: `sh/<utility-name>.bat`
- 测试: `__test__/<utility-name>.test.sh`
- 配置（如需要）: `config/` 或用户级配置文档

**新的二进制实用工具:**
- Windows 可执行文件: `bin/<name>.exe` 或 `bin/<name>/`
- 源码/构建: `bin/<name>/` 子目录，带构建脚本

**新配置:**
- 内置默认值: `config/<name>.txt`
- 在 README.md 中文档化用户级覆盖选项

**新测试:**
- 测试文件: `__test__/<feature>.test.sh`
- 遵循现有模式: 在测试运行器中 `bash "$test_file"`
- 报告自动生成到 `__test__/report/`

## 特殊目录

**bin/win-helper/:**
- 用途: Windows Git Bash 运行时辅助工具（Go 二进制）
- 是否生成: 是（构建输出）
- 是否提交: 是（包括源码和构建脚本）

**patch-files/:**
- 用途: wsh-fpatch 脚本的默认输出目录
- 是否生成: 是（当 wsh-fpatch 无 -o 选项运行时）
- 是否提交: 否（在 .gitignore 中）

**__test__/report/:**
- 用途: 自动生成的测试执行报告
- 是否生成: 是（运行测试时）
- 是否提交: 是（可能提交示例报告）

**tmp-home/, tmp-work/:**
- 用途: 测试用临时目录
- 是否生成: 是
- 是否提交: 否（在 .gitignore 中）

---

*结构分析: 2026-04-13*
