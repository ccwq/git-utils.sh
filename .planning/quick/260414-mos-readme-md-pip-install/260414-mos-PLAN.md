---
phase: 260414-mos
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - py/wsha/data/__init__.py
  - py/wsha/data/default.txt
  - pyproject.toml
  - py/wsha/config.py
  - py/wsha/cli.py
  - README.md
autonomous: true
requirements: []
must_haves:
  truths:
    - "wsha --list shows correct config paths (wsh-alias/ not wsh-alias.txt)"
    - "pip install 后 wsha 命令可正常使用"
    - "首次运行自动创建用户配置目录并复制默认配置"
  artifacts:
    - path: "py/wsha/data/__init__.py"
      provides: "使 wsha.data 成为合法 Python 包"
      min_lines: 0
    - path: "py/wsha/data/default.txt"
      provides: "打包到 wheel 的默认配置副本"
      min_lines: 10
    - path: "py/wsha/config.py"
      provides: "ensure_user_config() 函数，运行时检测并复制默认配置"
      exports: ["ensure_user_config"]
    - path: "README.md"
      provides: "更新的配置路径文档"
      contains: "config/wsh-alias/"
  key_links:
    - from: "py/wsha/config.py"
      to: "py/wsha/data/default.txt"
      via: "importlib.resources.files()"
      pattern: "files\\('wsha.data'\\)"
    - from: "pyproject.toml"
      to: "py/wsha/data/default.txt"
      via: "tool.hatch.build.targets.wheel 包含 data 目录"
      pattern: "include-package-data"
---

<objective>
更新 README.md 中的陈旧配置路径，并实现 pip install 后首次运行时自动复制默认配置到用户目录。
</objective>

<execution_context>
@E:/project/self.project/git-utils.sh/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@py/wsha/config.py
@py/wsha/cli.py
@pyproject.toml
@config/wsh-alias/default.txt

<!-- 从 research 提取的关键发现 -->
pip 不支持 post-install 钩子。推荐方案：运行时检测 + CLI 初始化命令。
用户目录路径：$HOME/.config/wsh-alias/default.txt
跨平台路径处理已正确实现于 config.py（使用 Path.home()）
</context>

<tasks>

<task type="auto">
  <name>Task 1: 创建 py/wsha/data/ 包并配置打包</name>
  <files>py/wsha/data/__init__.py, py/wsha/data/default.txt, pyproject.toml, py/wsha/config.py, py/wsha/cli.py</files>
  <action>
## 0. 创建 py/wsha/data/__init__.py
创建空文件使 wsha.data 成为合法 Python 包，供 importlib.resources.files('wsha.data') 使用：
```python
# wsha.data package - contains default configuration files
# This package is used by importlib.resources to access bundled data files
```

## 1. 创建 py/wsha/data/default.txt
将 config/wsh-alias/default.txt 内容复制到 py/wsha/data/default.txt

## 2. 修改 pyproject.toml
在 [project] 下添加 package data 配置：
```toml
[tool.hatch.build.targets.wheel]
packages = ["py/wsha"]

[tool.hatch.build.targets.wheel.data]
# 打包 py/wsha/data/ 目录下的所有 .txt 文件
include = ["py/wsha/data/*.txt"]
```

## 3. 修改 py/wsha/config.py
在文件顶部添加 import:
```python
from importlib.resources import files
```

添加 ensure_user_config() 函数（在 load_config 函数之前）:
```python
def ensure_user_config() -> Path:
    """
    确保用户配置目录存在，首次运行时从包内复制默认配置。
    仅在配置文件不存在时复制，不覆盖已存在的用户配置。
    """
    home_override = os.environ.get('WSHA_OVERRIDE_HOME') or os.environ.get('HOME')
    if home_override:
        home = Path(home_override)
    else:
        home = Path.home()

    user_dir = home / ".config" / "wsh-alias"
    user_file = user_dir / "default.txt"

    # 如果用户配置已存在，直接返回
    if user_file.exists():
        return user_dir

    # 创建目录
    user_dir.mkdir(parents=True, exist_ok=True)

    # 从包内数据复制
    try:
        default_content = files('wsha.data').joinpath('default.txt').read_text(encoding='utf-8')
        user_file.write_text(default_content, encoding='utf-8')
    except Exception:
        # 如果复制失败，尝试从 APP_HOME 复制（开发时）
        app_home = os.environ.get('APP_HOME', '')
        if app_home:
            src_default = Path(app_home) / "config" / "wsh-alias" / "default.txt"
            if src_default.exists():
                import shutil
                shutil.copy2(src_default, user_file)

    return user_dir
```

## 4. 在 cli.py 中调用 ensure_user_config()
在 main() 函数开始处（在 load_config 之前）添加调用：
```python
# 确保用户配置存在（首次运行时自动创建）
from .config import ensure_user_config
ensure_user_config()
```
  </action>
  <verify>
    <automated>
cd /e/project/self.project/git-utils.sh && python -c "
from py.wsha.config import ensure_user_config
from pathlib import Path
import tempfile, os

# 测试用临时 HOME
with tempfile.TemporaryDirectory() as tmpdir:
    os.environ['WSHA_OVERRIDE_HOME'] = tmpdir
    user_dir = ensure_user_config()
    user_file = Path(tmpdir) / '.config' / 'wsh-alias' / 'default.txt'
    assert user_file.exists(), f'User config not created at {user_file}'
    print(f'OK: User config created at {user_file}')
"
    </automated>
  </verify>
  <done>ensure_user_config() 在首次运行时创建 $HOME/.config/wsh-alias/default.txt</done>
</task>

<task type="auto">
  <name>Task 2: 更新 README.md 配置路径文档</name>
  <files>README.md</files>
  <action>
更新 README.md 中以下几处配置路径描述：

## 1. 更新配置文件说明（"#### 配置文件" 部分）
将旧的路径描述：
```markdown
1. 内置配置：`config/wsh-alias.txt`
2. 用户配置：`$HOME/.config/wsh-alias.txt`（Linux）或 `%USERPROFILE%\.config\wsh-alias.txt`（Windows）
3. 工作目录配置：`$PWD/.config/wsh-alias.txt`（Linux）或 `%CD%\.config\wsh-alias.txt`（Windows）
```

改为新的目录结构：
```markdown
1. 内置配置：`config/wsh-alias/`（包含 default.txt 等文件）
2. 用户配置：`$HOME/.config/wsh-alias/`（Linux）或 `%USERPROFILE%\.config\wsh-alias\`（Windows）
3. 工作目录配置：`$PWD/.config/wsh-alias/`（Linux）或 `%CD%\.config\wsh-alias\`（Windows）

配置目录支持 glob 模式加载同名 alias 高优先级覆盖低优先级。
```

## 2. 更新 Clink 自动补全说明（"其中：" 部分）
将：
```markdown
- `w` / `wsha` 会从 `config/wsh-alias.txt`、`%USERPROFILE%\.config\wsh-alias.txt`、`%CD%\.config\wsh-alias.txt` 读取 alias 候选。
```

改为：
```markdown
- `w` / `wsha` 会从 `config/wsh-alias/`、`%USERPROFILE%\.config\wsh-alias\`、`%CD%\.config\wsh-alias\` 读取 alias 候选。
```

## 3. 更新"编辑配置文件"示例
将：
```markdown
# 编辑配置文件
--edit-config code %APP_CONFIG%/wsh-alias.txt
-ec wsha.bat --edit-config
```

改为：
```markdown
# 编辑配置文件
--edit-config code %APP_CONFIG%/wsh-alias/
-ec wsha.bat --edit-config
```

## 4. 更新"编辑用户配置文件"示例
将：
```markdown
# 编辑用户配置文件
--edit-config-user code %USERPROFILE%/.config/wsh-alias.txt
-ecu wsha.bat --edit-config-user
```

改为：
```markdown
# 编辑用户配置文件
--edit-config-user code %USERPROFILE%/.config/wsh-alias/
-ecu wsha.bat --edit-config-user
```
  </action>
  <verify>
    <automated>
grep -n "wsh-alias\.txt" README.md && echo "FAIL: Found old .txt paths" || echo "OK: No old .txt paths found"
    </automated>
  </verify>
  <done>README.md 中所有配置路径已更新为 wsh-alias/ 目录结构</done>
</task>

</tasks>

<verification>
## 整体验证

1. **运行时配置初始化测试**:
```bash
cd /e/project/self.project/git-utils.sh
pip install -e . --quiet
python -c "
import tempfile, os
from pathlib import Path

# 模拟新安装环境
with tempfile.TemporaryDirectory() as tmpdir:
    old_home = os.environ.get('HOME')
    os.environ['WSHA_OVERRIDE_HOME'] = tmpdir
    os.environ.pop('APP_HOME', None)  # 清除 APP_HOME 强制使用包内数据
    
    # 重新导入以触发 ensure_user_config
    import importlib
    from py.wsha import config
    importlib.reload(config)
    
    result = config.ensure_user_config()
    user_file = Path(tmpdir) / '.config' / 'wsh-alias' / 'default.txt'
    
    if user_file.exists():
        print(f'SUCCESS: User config created at {user_file}')
    else:
        print(f'FAIL: User config not created')
        exit(1)
"
```

2. **README 路径更新验证**:
```bash
grep -E "wsh-alias\.txt|config/wsh-alias/" README.md | head -20
```
预期：无 .txt 路径，有 / 结尾的目录路径

3. **包结构验证**:
```bash
python -c "
from importlib.resources import files
# 验证 wsha.data 包可被 importlib.resources 识别
data = files('wsha.data')
print(f'OK: wsha.data package found at {data}')
"
```
</verification>

<success_criteria>
- [ ] py/wsha/data/__init__.py 存在（使 wsha.data 成为合法 Python 包）
- [ ] py/wsha/data/default.txt 存在且内容与 config/wsh-alias/default.txt 一致
- [ ] pyproject.toml 包含 package data 配置
- [ ] py/wsha/config.py 导出 ensure_user_config() 函数
- [ ] wsha --list 能正常显示（不报错）
- [ ] 首次运行自动创建 $HOME/.config/wsh-alias/default.txt
- [ ] README.md 不再包含 wsh-alias.txt 路径
- [ ] README.md 配置路径说明使用 wsh-alias/ 目录结构
</success_criteria>

<output>
After completion, create `.planning/quick/260414-mos-readme-md-pip-install/260414-mos-SUMMARY.md`
</output>