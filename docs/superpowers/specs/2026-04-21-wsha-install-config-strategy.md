# wsha 安装模式与配置策略设计

## 背景

当前 `wsha` Python 版本存在缓存不一致问题：
- `pip install -e .` 安装后，缓存可能过期/损坏导致配置丢失
- Python 版本和 bash 版本使用不同缓存，造成行为不一致

## 目标

在 wsha pip install 时，根据安装方式决定配置策略：
- **Editable 安装 (`pip install -e .`)**：直接读取项目源码配置，无需额外操作
- **Normal 安装 (`pip install .`)**：安装时将项目配置复制到 `~/.cache/wsha/` 作为预热缓存

## 实现方案

### A. 运行时检测：检测安装模式

通过 `pip show wsha` 检查 `Editable project location` 字段：
- 有该字段 → editable 安装，配置源为项目源码
- 无该字段 → normal 安装，使用 `~/.cache/wsha/` 中的缓存

**实现位置**：`py/wsha/config.py`

```python
def is_editable_install() -> bool:
    """检测 wsha 是否为 editable 安装。"""
    try:
        result = subprocess.run(
            ["pip", "show", "wsha"],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            return "Editable project location:" in result.stdout
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    return False
```

### B. 安装时复制：Normal 安装复制配置到缓存

在 `pyproject.toml` 中添加 install hook，normal 安装时复制配置到缓存。

**实现位置**：`pyproject.toml` + `py/setup_tools.py`

```python
# py/setup_tools.py
from pathlib import Path
import shutil

def on_install(concrete=True):
    """pip install 时调用，复制配置到缓存目录。"""
    if not concrete:
        return  # editable 安装不执行

    # 找到项目源码根目录
    import wsha as pkg
    pkg_dir = Path(pkg.__file__).parent  # py/wsha/
    project_root = pkg_dir.parent.parent  # 项目根

    src_config = project_root / "config" / "wsh-alias"
    if not src_config.exists():
        return

    cache_dir = Path.home() / ".cache" / "wsha"
    cache_dir.mkdir(parents=True, exist_ok=True)

    # 复制所有 *.txt 文件（跳过 _ 前缀）
    for txt_file in src_config.glob("*.txt"):
        if txt_file.name.startswith("_"):
            continue
        shutil.copy2(txt_file, cache_dir / txt_file.name)

    # 清除旧缓存，触发重新生成
    from wsha.cache import CacheManager
    CacheManager().clear()
```

**pyproject.toml hook 配置**：
```toml
[tool.hatch.build.targets.wheel.hooks.custom]
# 安装时执行的 hook
```

### C. 配置加载决策

修改 `get_default_config_paths()` 和 `load_config()`：

```python
def get_default_config_paths():
    """根据安装模式决定配置源。"""
    if is_editable_install():
        # Editable 安装：使用项目源码配置
        detected = _detect_package_root()
        if detected:
            builtin_dir = detected / "config" / "wsh-alias"
            if builtin_dir.is_dir():
                return {"builtin": str(builtin_dir)}
    else:
        # Normal 安装：使用缓存预热配置
        cache_dir = Path.home() / ".cache" / "wsha"
        if cache_dir.exists():
            return {"cache": str(cache_dir)}

    # 回退：检测项目源码
    ...

def load_config(...):
    # 如果是 editable 安装，禁用缓存读取
    # 如果是 normal 安装但缓存不存在，执行预热复制
    ...
```

## 数据流

```
pip install . (normal)
  → [install hook] 复制 config/wsh-alias/*.txt → ~/.cache/wsha/
  → 清除缓存文件

wsha 启动
  → is_editable_install() → False
  → 使用 ~/.cache/wsha/ 作为配置源
  → 缓存命中 → 直接返回

pip install -e . (editable)
  → 无需操作（源码即配置源）

wsha 启动
  → is_editable_install() → True
  → 使用项目源码 config/wsh-alias/
  → 每次重新解析（与 bash 版本一致）
```

## 兼容性

- **已有缓存**：normal 安装时直接覆盖，行为一致
- **无缓存**：触发复制逻辑
- **切换安装模式**：下次启动时自动检测新模式