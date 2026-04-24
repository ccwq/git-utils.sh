"""
安装 hook 用于 normal 安装时预热配置缓存。

当执行 `pip install .` (非 -e) 时：
1. 复制项目 sh/config/wsh-alias/*.txt 到 ~/.cache/wsha/
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
    src_config = project_root / "sh" / "config" / "wsh-alias"
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
