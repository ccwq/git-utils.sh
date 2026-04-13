# Phase 1: Config System & Core Architecture - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-13
**Phase:** 01-config-system-core-architecture
**Areas discussed:** Package Structure, Config Parsing, Cache Strategy, Error Handling

---

## Area: Package Structure

| Option | Description | Selected |
|--------|-------------|----------|
| py/ 作为顶级包 (推荐) | py/wsha/__init__.py 等 — 简单直观，与现有 sh/ 并列 | ✓ |
| src/wsha/ (src layout) | 符合现代 Python 项目布局，src 隔离 import | |
| wsha/ 作为包名 | 与 CLI 命令名一致，但可能与 shell 脚本目录混淆 | |

**User's choice:** py/ 作为顶级包 (推荐)
**Notes:** None

---

## Area: Entry Point Routing

| Option | Description | Selected |
|--------|-------------|----------|
| Click CLI 入口点 (推荐) | pyproject.toml console_scripts entry point，pip 安装后 w 命令直接路由 Python | ✓ |
| wsha.bat 改用 Python 优先 | 修改 wsha.bat，先尝试 Python，失败再调用 wsha.sh | |
| 独立 wsha Python CLI | wsha 命令走 Python，w 命令保持 shell — 两个独立入口 | |

**User's choice:** Click CLI 入口点 (推荐)
**Notes:** None

---

## Area: Project Config Format

| Option | Description | Selected |
|--------|-------------|----------|
| pyproject.toml only (推荐) | 现代 Python 标准，定义 build system 和 entry points | ✓ |
| pyproject.toml + setup.py 混合 | pyproject.toml + setup.py 分开定义 — 过度复杂 | |
| setup.py + setup.cfg | 旧式方式，不推荐新项目 | |

**User's choice:** pyproject.toml only (推荐)
**Notes:** None

---

## Area: Config Parser

| Option | Description | Selected |
|--------|-------------|----------|
| 纯 Python 手写 parser (推荐) | 按行读取，处理引号转义、注释、空白 — 简单可控，与 shell 行为一致 | ✓ |
| shlex.split() + 后处理 | Python 标准库，但处理双引号内含空格等边界情况需要额外逻辑 | |

**User's choice:** 纯 Python 手写 parser (推荐)
**Notes:** None

---

## Area: Quoted Aliases

| Option | Description | Selected |
|--------|-------------|----------|
| 支持双引号别名 (推荐) | "pcodex l" 定义为 alias_name，模板为 echo codex-last — 完整支持 | ✓ |
| 不支持引号别名 | 别名本身不含空格，CLI 可用多个别名匹配组合 | |

**User's choice:** 支持双引号别名 (推荐)
**Notes:** None

---

## Area: Shell Cache Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Phase 1 只做 Python 缓存 (推荐) | Shell 版本暂无缓存，Python 先实现。兼容性是 Phase 5 的关注点 | ✓ |
| Phase 1 同时实现两边缓存 | Python 和 shell 版本都用相同缓存格式 — 工作量更大 | |

**User's choice:** Phase 1 只做 Python 缓存 (推荐)
**Notes:** 用户确认 shell 版本缓存不是 Phase 1 范围

---

## Area: Cache Format

| Option | Description | Selected |
|--------|-------------|----------|
| JSON (推荐) | 可读性好，Python 原生支持，调试方便 | ✓ |
| 纯文本 (shell 兼容) | 与 shell 版本配置格式一致，但解析复杂 | |
| Pickle | Python 原生，但不可读，其他工具无法检查 | |

**User's choice:** JSON (推荐)
**Notes:** None

---

## Area: Cache Location

| Option | Description | Selected |
|--------|-------------|----------|
| ~/.cache/wsha/ (推荐) | 符合 XDG 标准，Linux/macOS/Windows Git Bash 都支持 | ✓ |
| ~/.wsha/cache/ | Dotfile 内嵌缓存，Windows Git Bash 上路径处理可能复杂 | |

**User's choice:** ~/.cache/wsha/ (推荐)
**Notes:** None

---

## Area: Cache Validation

| Option | Description | Selected |
|--------|-------------|----------|
| 文件时间戳 mtime (推荐) | 配置 mtime 早于缓存 mtime = 缓存有效。简单高效 | ✓ |
| 内容 hash (MD5/SHA) | 基于文件内容计算 hash，更可靠但每次都要读文件 | |
| 时间戳 + hash 双重 | 时间戳快速判断，怀疑时再 hash — 过度工程 | |

**User's choice:** 文件时间戳 mtime (推荐)
**Notes:** None

---

## Area: Cache Corruption

| Option | Description | Selected |
|--------|-------------|----------|
| 自动清除 + 友好警告 (推荐) | 检测到损坏，删除缓存文件，显示警告信息，程序继续运行 | ✓ |
| 报错退出 | 缓存损坏时程序退出，需要用户手动清除 — 不友好 | |

**User's choice:** 自动清除 + 友好警告 (推荐)
**Notes:** None

---

## Area: Config Error Lines

| Option | Description | Selected |
|--------|-------------|----------|
| 显示行号 (推荐) | config/wsh-alias.txt:12: 无效语法 — 方便用户定位问题 | ✓ |
| 只显示错误类型 | 简单但不指出位置 — 用户需要自己找 | |

**User's choice:** 显示行号 (推荐)
**Notes:** None

---

## Area: Python Fallback

| Option | Description | Selected |
|--------|-------------|----------|
| Python 失败自动 fallback shell (推荐) | Python 运行时错误、ImportError 等情况下，调用 wsha.sh 作为 fallback | ✓ |
| Python 失败直接报错 | 不 fallback，让用户知道 Python 实现有问题 | |

**User's choice:** Python 失败自动 fallback shell (推荐)
**Notes:** None

---

## Claude's Discretion

- CLI 输出格式（颜色、TABLE 布局）— 细节 planner 决定
- 缓存 JSON 具体字段结构 — planner 决定

## Deferred Ideas

- **Shell Version Cache (Phase 5):** STATE.md 提到"Cache format must be compatible with shell version"，但 shell 版本当前无缓存实现。此兼容性工作放在 Phase 5 验证阶段处理。
