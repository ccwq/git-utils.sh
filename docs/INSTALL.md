# 安装编译发布手册

本文档详细介绍 git-utils.sh 项目的安装、编译和发布流程。

## 目录

- [环境要求](#环境要求)
- [安装方式](#安装方式)
- [编译构建](#编译构建)
- [发布流程](#发布流程)
- [常见问题](#常见问题)

---

## 环境要求

### 必需依赖

| 依赖 | 版本 | 说明 |
|------|------|------|
| Git | 任意版本 | 必须已安装 |
| Python | >= 3.8 | 用于 Python CLI 工具 |
| pip | 最新版 | 用于安装 Python 包 |

### 可选依赖

| 依赖 | 平台 | 说明 |
|------|------|------|
| Git Bash | Windows | 推荐使用 |
| Rust | Windows | 用于编译 win-helper.exe |
| Cargo | Windows | Rust 包管理器 |
| Node.js/pnpm | 跨平台 | 项目脚本使用 pnpm@10.21.0 |

---

## 安装方式

### 方式一：Git 克隆（推荐）

```bash
git clone https://github.com/ccwq/git-utils.sh.git
cd git-utils.sh
```

### 方式二：pip 全局安装 wsha

安装后可在任意目录使用 `w` 或 `wsha` 命令：

```bash
pip install .
# 或使用 uvx 免安装运行
uvx wsha --list
```

### 方式三：Windows 初始化脚本

自动配置 PATH 和 CLINK_PATH：

```bat
# 在项目根目录执行
npm run init

# 或直接运行
scripts\init.bat
```

### 方式四：免安装直接运行

```bat
# Windows 下使用 exec-git-bash.bat 启动
sh\exec-git-bash.bat sh\wsha.sh --list

# 或直接用 bash
bash sh\wsha.sh --list
```

---

## 编译构建

### 1. Python CLI 工具

项目使用 hatchling 作为构建后端：

```bash
# 开发模式安装（可编辑）
pip install -e .

# 构建 wheel 包
pip wheel . -w dist/

# 构建发布包
pip build
```

构建产物位于 `dist/` 目录。

### 2. Windows 运行时 (win-helper.exe)

使用 Cargo 编译 Rust 工具：

```bat
# 方式一：使用 npm 脚本
npm run build:win-helper

# 方式二：直接运行构建脚本
bin\win-helper\build.bat

# 方式三：使用 Cargo
cargo build --manifest-path bin\win-helper\Cargo.toml --release
```

构建产物输出到：

```
bin\win-helper\win-helper.exe
bin\win-helper\target\release\win-helper.exe
```

### 3. 验证安装

```bash
# 验证 Python CLI
wsha --list
w --list

# 验证 Shell 脚本
bash sh/wsha.sh --list

# Windows 下验证
sh\w.bat --list
sh\wsha.bat --list
```

---

## 发布流程

### 1. Python 包发布到 PyPI

#### 准备工作

```bash
# 安装发布工具
pip install build twine
```

#### 构建发布包

```bash
# 清理旧构建
rm -rf dist/ build/ *.egg-info

# 构建 sdist 和 wheel
pip build
```

#### 上传到 PyPI

```bash
# 测试环境（先发布到 Test PyPI）
twine upload --repository testpypi dist/*

# 正式环境
twine upload dist/*
```

#### 版本更新

编辑 `pyproject.toml` 中的版本号：

```toml
[project]
version = "0.2.0"
```

### 2. GitHub Release 发布

#### 标签并推送

```bash
# 创建标签
git tag -a v1.1.0 -m "Release v1.1.0"

# 推送标签
git push origin v1.1.0
```

#### 使用 GitHub CLI 发布

```bash
# 创建发行版
gh release create v1.1.0 \
  --title "Release v1.1.0" \
  --notes "See CHANGELOG for details"

# 上传构建产物
gh release upload v1.1.0 dist/*
```

### 3. Windows exe 独立发布

win-helper.exe 可以作为独立工具发布：

```bat
# 重新构建 release 版本
cargo build --manifest-path bin\win-helper\Cargo.toml --release --strip

# 复制到发布目录
copy bin\win-helper\target\release\win-helper.exe dist\
```

---

## 常见问题

### Q: pip install 报错 "wheel not supported"？

确保 pip 版本是最新的：

```bash
pip install --upgrade pip
```

### Q: win-helper.exe 无法启动？

1. 检查 Rust 环境：`rustc --version`
2. 重新编译：`cargo build --release`
3. 查看错误信息：`cargo run --release`

### Q: w 命令找不到？

确保 `sh\` 目录在 PATH 中：

```bat
# 临时添加（当前会话）
set PATH=%PATH%;E:\project\self.project\git-utils.sh\sh

# 永久添加（用户环境）
setx PATH "%PATH%;E:\project\self.project\git-utils.sh\sh"
```

### Q: Python 版本兼容性问题？

项目要求 Python >= 3.8。检查版本：

```bash
python --version
```

### Q: Windows 下执行脚本报错？

Windows 下必须通过 Git Bash 执行 `.sh` 脚本：

```bat
sh\exec-git-bash.bat sh\wsha.sh --list
```

### Q: 如何更新已安装的版本？

```bash
# 通过 pip 更新
pip install --upgrade .

# 或通过 Git 更新源码
git pull
```

### Q: 缓存问题导致配置不生效？

清除 wsha 缓存：

```bash
# Python 版本
wsha --cache-clear

# Shell 版本（删除缓存目录）
rm -rf ~/.cache/wsha/
```

---

## 快速参考

| 操作 | 命令 |
|------|------|
| 克隆项目 | `git clone https://github.com/ccwq/git-utils.sh.git` |
| 初始化环境 | `npm run init` |
| 安装 Python CLI | `pip install .` |
| 构建 Python 包 | `pip build` |
| 编译 win-helper | `npm run build:win-helper` |
| 运行测试 | `npm test` |
| 发布到 PyPI | `twine upload dist/*` |
| 创建 Git Tag | `git tag v1.0.0 && git push origin v1.0.0` |
