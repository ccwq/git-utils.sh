# wsha 安装模式与配置策略实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现 wsha 安装模式检测与配置策略：editable 安装读源码，normal 安装预热缓存到 `~/.cache/wsha/`

**Architecture:** 在 config.py 中添加 `is_editable_install()` 通过 `pip show wsha` 检测安装模式；setup_tools.py 提供安装时复制配置的 hook；配置加载时根据安装模式选择配置源

**Tech Stack:** Python, pip, hatchling (pyproject.toml)

---

### Task 1: 添加 `is_editable_install()` 函数

**Files:**
- Modify: `py/wsha/config.py:44-77` (在 `ensure_user_config()` 前添加新函数)

- [ ] **Step 1: 添加 `is_editable_install()` 函数到 config.py**

在 `ensure_user_config()` 函数之前添加：

```python
def is_editable_install() -> bool:
    """
    检测 wsha 是否为 editable 安装。

    通过 pip show wsha 检查是否有 'Editable project location:' 字段。
    有该字段 → editable 安装，配置源为项目源码
    无该字段 → normal 安装，使用 ~/.cache/wsha/ 中的缓存
    """
    try:
        import subprocess as sp
        result = sp.run(
            ["pip", "show", "wsha"],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            return "Editable project location:" in result.stdout
    except (FileNotFoundError, sp.TimeoutExpired, OSError):
        pass
    return False
```

- [ ] **Step 2: 运行测试验证函数可导入**

Run: `cd /d E:\project\self.project\git-utils.sh && python -c "from wsha.config import is_editable_install; print(is_editable_install())"`
Expected: `True` (当前是 editable 安装)

- [ ] **Step 3: 提交**

```bash
git add py/wsha/config.py
git commit -m "feat(config): add is_editable_install() detection"
```

---

### Task 2: 修改 `get_default_config_paths()` 根据安装模式选择配置源

**Files:**
- Modify: `py/wsha/config.py:109-147` (替换整个函数)

- [ ] **Step 1: 替换 `get_default_config_paths()` 函数**

用以下实现替换原函数：

```python
def get_default_config_paths() -> Dict[str, str]:
    """
    Get default config directory paths with priority.
    Returns dict of source_name -> config_directory_path

    根据安装模式决定配置源：
    - Editable 安装：使用项目源码 config/wsh-alias/
    - Normal 安装：使用 ~/.cache/wsha/ 预热缓存
    """
    home_override = os.environ.get('WSHA_OVERRIDE_HOME') or os.environ.get('HOME')
    if home_override:
        home = Path(home_override)
    else:
        home = Path.home()

    app_home = os.environ.get('APP_HOME', '')
    configs = {}

    # 检测安装模式
    if is_editable_install():
        # Editable 安装：使用项目源码配置
        if app_home:
            builtin_dir = Path(app_home) / "config" / "wsh-alias"
            if builtin_dir.is_dir():
                configs['builtin'] = str(builtin_dir)
        else:
            # APP_HOME 未设置时自动检测
            detected_root = _detect_package_root()
            if detected_root:
                builtin_dir = detected_root / "config" / "wsh-alias"
                if builtin_dir.is_dir():
                    configs['builtin'] = str(builtin_dir)
    else:
        # Normal 安装：使用 ~/.cache/wsha/ 作为配置源
        cache_dir = home / ".cache" / "wsha"
        if cache_dir.is_dir():
            configs['cache'] = str(cache_dir)
        else:
            # 缓存不存在时回退到检测项目源码
            if app_home:
                builtin_dir = Path(app_home) / "config" / "wsh-alias"
                if builtin_dir.is_dir():
                    configs['builtin'] = str(builtin_dir)
            else:
                detected_root = _detect_package_root()
                if detected_root:
                    builtin_dir = detected_root / "config" / "wsh-alias"
                    if builtin_dir.is_dir():
                        configs['builtin'] = str(builtin_dir)

    # 用户级配置：$HOME/.config/wsh-alias/
    user_dir = home / ".config" / "wsh-alias"
    if user_dir.is_dir():
        configs['user'] = str(user_dir)

    # 项目级配置：$PWD/.config/wsh-alias/
    local_dir = Path.cwd() / ".config" / "wsh-alias"
    if local_dir.is_dir():
        configs['project'] = str(local_dir)

    return configs
```

- [ ] **Step 2: 运行测试验证函数正常工作**

Run: `cd /d E:\project\self.project\git-utils.sh && python -c "from wsha.config import get_default_config_paths; print(get_default_config_paths())"`
Expected: 显示当前配置路径（editable 安装应显示 `builtin` 源码路径）

- [ ] **Step 3: 提交**

```bash
git add py/wsha/config.py
git commit -m "feat(config): adapt get_default_config_paths() to installation mode"
```

---

### Task 3: 创建安装 Hook 文件

**Files:**
- Create: `py/setup_tools.py`

- [ ] **Step 1: 创建 py/setup_tools.py**

```python
"""
安装 hook 用于 normal 安装时预热配置缓存。

当执行 `pip install .` (非 -e) 时：
1. 复制项目 config/wsh-alias/*.txt 到 ~/.cache/wsha/
2. 清除旧缓存触发重新生成

Editable 安装 (`pip install -e .`) 不执行此操作。
"""

import os
import shutil
import sys
from pathlib import Path


def _get_project_root():
    """获取项目源码根目录（从 wsha 包位置推断）。"""
    try:
        import wsha as pkg
        pkg_file = Path(pkg.__file__).resolve()
        # py/wsha/__init__.py -> py/wsha -> project root
        package_dir = pkg_file.parent  # py/wsha/
        project_root = package_dir.parent.parent  # 项目根
        return project_root
    except ImportError:
        return None


def _copy_config_to_cache(project_root: Path, cache_dir: Path):
    """
    复制项目配置到缓存目录。
    """
    src_config = project_root / "config" / "wsh-alias"
    if not src_config.exists():
        return

    cache_dir.mkdir(parents=True, exist_ok=True)

    # 复制所有 *.txt 文件（跳过 _ 前缀）
    for txt_file in src_config.glob("*.txt"):
        if txt_file.name.startswith("_"):
            continue
        shutil.copy2(txt_file, cache_dir / txt_file.name)


def on_install(concrete: bool = True):
    """
    pip install 时调用的 hook。
    """
    if not concrete:
        return

    project_root = _get_project_root()
    if not project_root:
        return

    cache_dir = Path.home() / ".cache" / "wsha"
    _copy_config_to_cache(project_root, cache_dir)

    # 清除旧缓存，触发重新生成
    try:
        from wsha.cache import CacheManager
        CacheManager().clear()
    except ImportError:
        pass


if __name__ == "__main__":
    on_install()
    print("Config copied to cache.")
```

- [ ] **Step 2: 验证文件可导入**

Run: `cd /d E:\project\self.project\git-utils.sh && python py/setup_tools.py`
Expected: `Config copied to cache.` 或类似输出

- [ ] **Step 3: 提交**

```bash
git add py/setup_tools.py
git commit -m "feat(setup): add install hook for config pre-warming"
```

---

### Task 4: 首次运行时自动预热缓存（替代 Task 4）

由于 pip install hooks 实现复杂，改用运行时自动预热：Normal 安装时若缓存为空，自动从项目源码复制配置。

**Files:**
- Modify: `py/wsha/config.py` (修改 `load_config()` 函数)

- [ ] **Step 1: 在 `load_config()` 中添加预热逻辑**

找到 `load_config()` 函数（约在 150 行），在函数开头的缓存加载逻辑之后添加预热检查：

```python
# 在 "Try loading from cache first" 块之后添加：

# Normal 安装且缓存为空时，自动从项目源码预热
if mode == "multi" and config_path is None:
    cache_mgr = CacheManager()
    # 检查是否需要预热（缓存目录存在但内容为空）
    if not is_editable_install():
        cache_dir = Path.home() / ".cache" / "wsha"
        if cache_dir.exists() and not any(cache_dir.glob("*.txt")):
            # 缓存目录存在但没有配置文件，执行预热
            project_root = _detect_package_root()
            if project_root:
                src_config = project_root / "config" / "wsh-alias"
                if src_config.exists():
                    for txt_file in src_config.glob("*.txt"):
                        if not txt_file.name.startswith("_"):
                            shutil.copy2(txt_file, cache_dir / txt_file.name)
```

需要在文件顶部添加 `import shutil`。

- [ ] **Step 2: 验证预热逻辑存在**

Run: `cd /d E:\project\self.project\git-utils.sh && python -c "from wsha.config import load_config; load_config()"`
Expected: 无错误

- [ ] **Step 3: 提交**

```bash
git add py/wsha/config.py
git commit -m "feat(config): add auto warm-up for normal install cache"
```

---

### Task 5: 添加测试

**Files:**
- Modify: `__test__/wsha_python_test.py`

- [ ] **Step 1: 添加 `is_editable_install()` 测试**

在 `test_cache_corruption_recovery()` 函数之后、`main()` 函数之前添加：

```python
def test_is_editable_install_detection():
    """Test is_editable_install() returns bool."""
    from wsha.config import is_editable_install
    result = is_editable_install()
    assert isinstance(result, bool), f"Expected bool, got {type(result)}"


def test_is_editable_install_pip_show():
    """Test is_editable_install() uses pip show output."""
    import subprocess as sp
    result = is_editable_install()

    # 如果是 editable 安装，pip show 应该包含Editable project location
    if result:
        show_result = sp.run(["pip", "show", "wsha"], capture_output=True, text=True)
        assert "Editable project location:" in show_result.stdout
```

- [ ] **Step 2: 运行测试**

Run: `cd /d E:\project\self.project\git-utils.sh && python __test__/wsha_python_test.py test_is_editable_install_detection test_is_editable_install_pip_show`
Expected: PASS

- [ ] **Step 3: 提交**

```bash
git add __test__/wsha_python_test.py
git commit -m "test: add is_editable_install() tests"
```

---

### Task 6: 验证完整流程

- [ ] **Step 1: 清理缓存**

Run: `w --cache-clear`

- [ ] **Step 2: 测试 editable 安装下的行为**

Run: `w -l 2>&1 | grep -E "(t-ps|t-kill)"`
Expected: 显示 t-ps 和 t-kill 条目

- [ ] **Step 3: 测试别名执行**

Run: `w t-kill notepad 2>&1` (需要先启动 notepad)
Expected: "[wsha] alias hit: w t-kill notepad -> taskkill /f /im notepad" 或错误（进程不存在）

- [ ] **Step 4: 最终提交**

```bash
git add -A
git commit -m "feat: implement install mode detection and config strategy"
```

---

## 自检清单

1. **Spec 覆盖**：所有 spec 中的 A/B/C 三部分均有对应任务
2. **Placeholder 检查**：无 TBD/TODO
3. **类型一致性**：`is_editable_install()` 返回 `bool`，`get_default_config_paths()` 返回 `Dict[str, str]`