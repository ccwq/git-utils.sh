---
phase: 260414-mos
plan: "01"
type: execute
wave: "1"
subsystem: wsha-python
tags: [pip-install, config-initialization, documentation]
dependency_graph:
  requires: []
  provides:
    - id: "260414-mos-01"
      description: "pip install 后首次运行自动创建用户配置"
  affects:
    - py/wsha/cli.py
    - py/wsha/config.py
    - pyproject.toml
    - README.md
tech_stack:
  added:
    - Python: importlib.resources (打包数据文件访问)
    - Python: pathlib.Path (跨平台路径处理)
  patterns:
    - 运行时配置初始化 (runtime config initialization)
    - 包内数据打包 (package data bundling)
key_files:
  created:
    - path: py/wsha/data/__init__.py
      description: "使 wsha.data 成为合法 Python 包"
    - path: py/wsha/data/default.txt
      description: "打包到 wheel 的默认配置副本"
  modified:
    - path: py/wsha/config.py
      description: "添加 ensure_user_config() 函数"
    - path: py/wsha/cli.py
      description: "在 main() 入口调用 ensure_user_config()"
    - path: pyproject.toml
      description: "添加 [tool.hatch.build.targets.wheel.data] 打包配置"
    - path: README.md
      description: "更新配置路径文档 (wsh-alias.txt -> wsh-alias/)"
decisions:
  - id: "D1"
    description: "使用 importlib.resources.files() 访问打包的默认配置"
    rationale: "Python 3.9+ 标准库，跨平台兼容性好"
  - id: "D2"
    description: "首次运行时通过 ensure_user_config() 自动创建用户配置"
    rationale: "pip 不支持 post-install 钩子，运行时初始化是推荐方案"
  - id: "D3"
    description: "fallback 到 APP_HOME 路径用于开发时测试"
    rationale: "确保 pip install -e . 开发时也能正常工作"
metrics:
  duration: "<5 minutes"
  completed_date: "2026-04-14T16:25:00Z"
---

# Phase 260414-mos Plan 01 Summary

## One-liner

pip install 后首次运行自动从包内复制默认配置到用户目录，README 路径文档更新为目录结构。

## Completed Tasks

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 | 创建 py/wsha/data/ 包并配置打包 | 6caf1f6 | data/__init__.py, data/default.txt, config.py, cli.py, pyproject.toml |
| 2 | 更新 README.md 配置路径文档 | 396527b | README.md |

## Deviations from Plan

### Auto-fixed Issues

**None** - plan executed exactly as written.

## Task 1: 创建 py/wsha/data/ 包并配置打包

### What was built

- `py/wsha/data/__init__.py` - 空文件，使 wsha.data 成为 Python 包
- `py/wsha/data/default.txt` - 从 config/wsh-alias/default.txt 复制的默认配置
- `py/wsha/config.py` - 添加 `ensure_user_config()` 函数，使用 importlib.resources.files() 读取打包数据
- `py/wsha/cli.py` - 在 main() 入口调用 `ensure_user_config()` 确保首次运行时自动初始化
- `pyproject.toml` - 添加 `[tool.hatch.build.targets.wheel.data]` 配置，打包 data/*.txt 文件

### Key Implementation

```python
def ensure_user_config() -> Path:
    """首次运行时从包内复制默认配置到用户目录"""
    home = Path.home()
    user_dir = home / ".config" / "wsh-alias"
    user_file = user_dir / "default.txt"

    if user_file.exists():
        return user_dir

    user_dir.mkdir(parents=True, exist_ok=True)

    # 从包内数据复制 (pip install 后)
    default_content = files('wsha.data').joinpath('default.txt').read_text()
    user_file.write_text(default_content)
    return user_dir
```

## Task 2: 更新 README.md 配置路径文档

### What was updated

- 配置文件说明：从 `config/wsh-alias.txt` 改为 `config/wsh-alias/`
- 用户配置路径：从 `$HOME/.config/wsh-alias.txt` 改为 `$HOME/.config/wsh-alias/`
- Clink 自动补全路径：从 `.txt` 文件改为 `/` 目录
- 添加 glob 模式加载说明

## Verification Results

| Test | Result |
|------|--------|
| `ensure_user_config()` creates config | PASS |
| `wsha.data` package accessible via importlib.resources | PASS |
| README contains no `wsh-alias.txt` paths | PASS |
| README contains `config/wsh-alias/` paths | PASS |

## Threat Flags

None - no new security surface introduced.

## Known Stubs

None.

## Self-Check: PASSED

- py/wsha/data/__init__.py: FOUND
- py/wsha/data/default.txt: FOUND
- py/wsha/config.py exports ensure_user_config: FOUND
- py/wsha/cli.py imports ensure_user_config: FOUND
- Task 1 commit 6caf1f6: FOUND
- Task 2 commit 396527b: FOUND
- README.md wsh-alias.txt paths: NOT FOUND (correctly removed)
- README.md wsh-alias/ paths: FOUND (correctly added)
