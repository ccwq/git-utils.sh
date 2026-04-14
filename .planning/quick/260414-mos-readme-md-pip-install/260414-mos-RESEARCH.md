# Quick Task 260414-mos: pip install 配置复制 - Research

**Researched:** 2026-04-14
**Domain:** Python package distribution / pip install 行为
**Confidence:** HIGH

## Summary

pip **不支持** post-install 钩子（有意设计决策）。无法在 `pip install` 时自动复制配置文件到用户目录。推荐方案：**运行时检测 + CLI 初始化命令**。

**Primary recommendation:** 将 default.txt 打包到 wheel 中（通过 hatchling 配置），首次运行时自动检测或提供 `wsha --init` 命令。

## User Constraints (from CONTEXT.md)

### Locked Decisions
- README 更新：将旧路径改为新目录结构
- 用户目录路径：`$HOME/.config/wsh-alias/default.txt`（跨平台）
- 仅首次安装时复制，不覆盖已存在的用户配置

### Claude's Discretion
- hatchling 构建钩子实现方式
- 跨平台路径处理

## 核心发现

### 1. pip install 不支持 post-install 脚本 [VERIFIED: PyPA 设计文档]

pip 团队**故意不实现** post-install 钩子，原因：
- 安全风险（任意代码执行）
- 跨平台兼容性问题
- 可重复构建原则

**无法**通过以下方式实现自动复制：
- `setup.py` post-install 脚本 ❌
- hatchling build hooks ❌ (只运行于构建时，不是安装后)
- pip 自定义钩子 ❌

### 2. 推荐方案：运行时检测 + CLI 初始化

| 方案 | 实现方式 | 优点 | 缺点 |
|------|----------|------|------|
| **运行时检测** | 首次运行检查用户目录，不存在则从包内复制 | 零配置，自动化 | 首次运行稍慢 |
| **CLI 命令** | `wsha --init` 显式复制 | 用户可控，可重置 | 需要额外步骤 |
| **纯文档** | README 说明如何创建配置 | 最简单 | 用户体验差 |
| **混合方案** | 运行时检测 + CLI 命令 | 最佳体验 | 实现稍复杂 |

### 3. Package Data 打包配置文件

**现有代码已支持：**
```python
# py/wsha/config.py 第 101-102 行
user_dir = home / ".config" / "wsh-alias"
```

**需要添加：** 将 `config/wsh-alias/default.txt` 打包到 wheel

**pyproject.toml 配置：**
```toml
[tool.hatch.build.targets.wheel]
packages = ["py/wsha"]
# 添加共享数据
shared-data = [
    { source = "config/wsh-alias/default.txt", target = "config/wsh-alias/default.txt" },
]
```

**或使用 package data（更简单）：**
```toml
[tool.hatch.build.targets.wheel]
packages = ["py/wsha"]
# 在 py/wsha/ 下创建 data/ 目录，放入 default.txt
```

### 4. 跨平台路径处理

**现有代码已正确实现：**
```python
# py/wsha/config.py 第 78-82 行
home_override = os.environ.get('WSHA_OVERRIDE_HOME') or os.environ.get('HOME')
if home_override:
    home = Path(home_override)
else:
    home = Path.home()  # 跨平台：Windows -> C:\Users\xxx, Linux -> /home/xxx
```

**路径对应关系：**
| 平台 | 用户配置目录 |
|------|-------------|
| Windows | `C:\Users\<user>\.config\wsh-alias\` |
| Linux/macOS | `/home/<user>/.config/wsh-alias/` |

### 5. importlib.resources 访问打包数据

**Python 3.9+ 推荐：**
```python
from importlib.resources import files

# 读取包内默认配置
default_config = files('wsha.data').joinpath('default.txt').read_text()
```

**需要修改项目结构：**
```
py/wsha/
├── __init__.py
├── cli.py
├── config.py
├── data/              # 新增
│   └── default.txt    # 从 config/wsh-alias/ 复制
└── ...
```

## 实现方案

### 方案 A：运行时检测（推荐）

**修改 config.py：**
```python
def ensure_user_config() -> Path:
    """确保用户配置目录存在，首次运行时复制默认配置。"""
    user_dir = Path.home() / ".config" / "wsh-alias"
    user_file = user_dir / "default.txt"

    if not user_file.exists():
        user_dir.mkdir(parents=True, exist_ok=True)
        # 从包内数据复制
        default_content = files('wsha.data').joinpath('default.txt').read_text()
        user_file.write_text(default_content, encoding='utf-8')

    return user_dir
```

**优点：**
- 零用户干预
- 首次运行自动配置

### 方案 B：CLI 初始化命令

**添加到 cli.py：**
```python
@wsha.command()
def init():
    """初始化用户配置目录和默认配置文件。"""
    from .config import ensure_user_config
    user_dir = ensure_user_config()
    click.echo(f"Created config at: {user_dir}")
```

**优点：**
- 用户可控
- 可重复执行（重置配置）

### 方案 C：混合（最佳体验）

结合 A + B：
- 首次运行自动检测
- 提供 `wsha --init` 显式重置

## Common Pitfalls

### Pitfall 1: 误用 shared-data
**问题：** `shared-data` 安装到 sys.prefix/share/，不是用户 home
**解决：** 使用 package data + 运行时复制，不依赖 shared-data

### Pitfall 2: 路径分隔符
**问题：** 硬编码 `/` 或 `\`
**解决：** 始终使用 `pathlib.Path`，已正确实现

### Pitfall 3: 编码问题
**问题：** Windows 默认编码可能不是 UTF-8
**解决：** 显式指定 `encoding='utf-8'`

## Don't Hand-Roll

| 问题 | 不要自己实现 | 使用 |
|------|------------|------|
| 跨平台 home 目录 | `os.environ['HOME']` | `Path.home()` |
| 包内数据访问 | `__file__` 路径拼接 | `importlib.resources.files()` |
| 目录创建 | 手动递归创建 | `Path.mkdir(parents=True, exist_ok=True)` |

## Open Questions

1. **是否需要保留 config/wsh-alias/default.txt？**
   - 推荐：保留（开发时使用），同时在 py/wsha/data/ 打包副本

2. **如何同步两份 default.txt？**
   - 方案 A：构建时自动复制（build hook）
   - 方案 B：开发时手动同步
   - 方案 C：只保留包内版本，config/ 目录用符号链接

## Recommended Implementation

1. **创建 `py/wsha/data/default.txt`** — 复制自 config/wsh-alias/default.txt
2. **修改 pyproject.toml** — 确保 data 目录被打包
3. **修改 config.py** — 添加 `ensure_user_config()` 函数
4. **修改 cli.py** — 在 `run_with_fallback` 或 `main` 开始时调用检测
5. **添加 `wsha --init` 命令** — 显式初始化选项
6. **更新 README.md** — 说明新的配置加载优先级

## Sources

### Primary (HIGH confidence)
- pip 文档: https://pip.pypa.io/en/stable/user_guide/ (无 post-install 钩子)
- hatchling 文档: https://hatch.pypa.io/latest/config/build/ (shared-data 用法)
- Python pathlib 文档: https://docs.python.org/3/library/pathlib.html

### Secondary (MEDIUM confidence)
- importlib.resources PEP 602: https://peps.python.org/pep-0602/

### Tertiary (Code Verification)
- py/wsha/config.py: verified cross-platform home detection
- pyproject.toml: current hatchling config