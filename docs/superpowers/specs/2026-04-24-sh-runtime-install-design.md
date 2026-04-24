# sh 运行时布局与安装/卸载设计

## 背景

当前仓库把运行时脚本放在 `sh/`，但内置配置仍位于仓库根的 `config/`，这导致以下问题：

- 运行时资产没有收口到同一目录，脚本、配置、安装器的边界不清晰
- 文档、测试、Python 实现、Clink 补全都隐含依赖 `APP_HOME/config`
- 准备增加一键安装时，难以直接把 `sh/` 视为可分发的运行时主体
- Windows 环境存在 Git Bash / PowerShell / CMD 多入口，安装约束和运行保证不够明确

本次设计聚焦两件事：

1. 将内置配置从仓库根 `config/` 收敛到 `sh/config/`
2. 设计面向用户目录的一键安装/卸载机制，支持安装报告与可审计清单

## 目标

- 让 `sh/` 成为仓库内唯一明确的 shell 运行时根目录
- 安装后将运行时主体放到用户私有目录，而不是直接散落到 PATH
- 对外提供远程一键安装入口，但核心逻辑保留在仓库内脚本中
- Windows 上安装脚本只允许在 Git Bash 中执行
- 安装结束后输出 report，清楚列出写入了哪些文件、目录和 launcher
- 提供对称的卸载脚本，支持删除安装产物并输出卸载 report
- 对旧版路径和历史布局做检测，但默认不自动迁移用户配置

## 非目标

- 本次不引入完整的发布产物系统或多渠道打包分发
- 本次不移除现有 Windows `.bat` 入口，只调整其安装后的定位
- 本次不默认自动迁移已有 `~/.config/wsh-alias/` 或其他用户自定义配置
- 本次不修改已有测试用例语义；如需改旧测试，需先单独确认原因

## 方案选型

### 方案 A：`sh` 运行时收口 + 远程薄入口（推荐）

- 仓库内将 `config/` 移动到 `sh/config/`
- 新增 `sh/install.sh`、`sh/uninstall.sh`
- 新增远程安装入口脚本，只负责下载并调用本地 `install.sh`
- 安装目标为用户私有目录，PATH 中只放薄 launcher

优点：

- 源码布局与运行时布局一致
- 安装逻辑与本地开发逻辑可复用
- 更容易测试、文档化和后续升级

代价：

- 需要统一修正代码、补全、文档、测试中的路径假设

### 方案 B：仅安装产物重排

- 仓库继续保留根目录 `config/`
- 只在安装到用户目录时改造成运行时结构

不推荐原因：

- 源码布局与安装后布局分叉
- 文档与调试复杂度上升
- 后续维护成本更高

### 方案 C：发布产物中心化

- 将源码、构建产物、安装器彻底分层

不推荐原因：

- 对当前目标过重
- 会把本次重构扩大成发布系统改造

## 总体设计

### 仓库内目录

目标结构：

```text
sh/
  config/
    wsh-alias/
      default.txt
      app-in.txt
    wsh-ping.txt
  install.sh
  uninstall.sh
  remote-install.sh
  w.sh
  w.bat
  wsha.sh
  wsha.bat
  wsh.bat
  wsh-ping.bat
  ...
```

### 安装后目录

统一安装到用户私有目录：

- Linux/macOS: `~/.local/share/git-utils.sh`
- Windows(Git Bash): `~/.local/share/git-utils.sh`

运行时主体放在私有目录中，PATH 中只放薄 launcher：

- Linux/macOS: `~/.local/bin/w`、`wsha`、`wsh`
- Windows: 安装 Git Bash 可用 launcher；如保留 `.bat`，它们仅作兼容转发层

### 环境变量约定

统一约定以下运行时路径：

- `APP_HOME`: 运行时根目录
- `APP_SH`: `$APP_HOME/sh`
- `APP_CONFIG`: `$APP_HOME/sh/config`

这样安装前和安装后都遵守同一套路径协议，不再默认使用 `APP_HOME/config`。

## 安装设计

### 用户入口

对外统一入口：

```bash
curl -fsSL "$INSTALL_URL" | bash
```

Windows 用户同样要求在 Git Bash 中执行该命令。

其中 `INSTALL_URL` 表示项目正式发布的远程安装脚本地址；实现阶段需要在文档中给出明确地址。

### 分层职责

#### 1. 远程入口

远程脚本职责尽量保持最薄，只负责：

- 检测平台与 shell 环境
- 在 Windows 上校验当前 shell 为 Git Bash
- 下载安装所需文件到临时目录
- 调用临时目录中的 `install.sh`

远程入口不承担复杂安装逻辑，避免线上逻辑与仓库源码分叉。

#### 2. `sh/install.sh`

核心安装器负责：

- 解析安装目标目录
- 校验运行环境
- 创建安装目录
- 复制运行时文件
- 生成 launcher
- 检查 PATH 并给出后续提示
- 检测旧版布局
- 生成并打印安装 report

### Windows 约束

- Windows 上安装脚本必须在 Git Bash 中运行
- 安装结束后可同时提供 Git Bash launcher 和兼容 `.bat` launcher
- 终端输出和 report 中需明确声明：Windows 下仅保证 Git Bash 行为

### PATH 策略

安装器默认不直接修改用户 PATH，而是：

- 检测 `~/.local/bin` 是否已在 PATH 中
- 未命中时打印清晰的后续操作提示
- report 中记录建议动作

这样可以避免安装脚本在不同 shell、不同平台下修改 profile 文件带来的副作用。

## 卸载设计

新增 `sh/uninstall.sh`，行为与安装器对称。

职责包括：

- 删除安装目录中的运行时文件
- 删除本次安装生成的 launcher
- 默认保留用户配置
- 可通过显式参数选择删除用户配置
- 生成并打印卸载 report

卸载过程中如果检测到以下情况，需要在 report 中标明，而不是静默处理：

- launcher 被用户手动修改
- 安装目录中存在非本次安装生成的额外文件
- 待删除文件缺失或已被外部进程占用

## Report 设计

安装和卸载都需要输出两份结果：

1. 终端摘要，供用户立即查看
2. 机器可读 report 文件，供后续排障和审计

建议 report 路径：

- 安装：`$APP_HOME/install-report.json`
- 卸载：临时打印摘要，并在可行时将最近一次卸载结果写入用户临时目录或标准输出

安装 report 至少包含以下字段：

```json
{
  "install_time": "2026-04-24T10:00:00+08:00",
  "platform": "windows-git-bash",
  "install_root": "~/.local/share/git-utils.sh",
  "launchers_created": [
    "~/.local/bin/w",
    "~/.local/bin/wsha",
    "~/.local/bin/wsh"
  ],
  "files_written": [
    "~/.local/share/git-utils.sh/sh/wsha.sh"
  ],
  "files_overwritten": [],
  "dirs_created": [
    "~/.local/share/git-utils.sh"
  ],
  "legacy_detected": [
    "~/.config/wsh-alias"
  ],
  "migration_suggested": true,
  "next_steps": [
    "ensure ~/.local/bin is in PATH"
  ]
}
```

终端摘要应重点展示：

- 安装到了哪里
- 写入了哪些 launcher
- 是否检测到旧版布局
- 用户下一步需要做什么
- Windows 下仅保证 Git Bash 行为

## 配置与路径解析

### 新路径

内置配置读取位置调整为：

1. `$APP_CONFIG/wsh-alias/*.txt`
2. `$HOME/.config/wsh-alias/*.txt`
3. `$PWD/.config/wsh-alias/*.txt`

`wsh-ping` 调整为读取：

- `$APP_CONFIG/wsh-ping.txt`

### 兼容策略

为避免一次性打断历史使用方式，本次引入过渡期 fallback：

1. 优先尝试新路径：`$APP_HOME/sh/config`
2. 新路径不存在时，回退尝试旧路径：`$APP_HOME/config`
3. 命中旧路径时输出一次轻量提示，提示后续迁移

该 fallback 同时适用于：

- `sh/wsha.sh`
- `sh/wsha-core.py`
- `py/wsha/config.py`
- `sh/wsh-ping.bat`
- Clink 相关补全脚本

## 旧版布局检测与迁移策略

安装器需要检测常见旧版布局，例如：

- 旧安装目录
- 历史根目录 `config/` 假设
- 已存在的 `~/.config/wsh-alias`

默认策略：

- 仅检测
- 不自动迁移
- 在终端和 report 中给出迁移建议

这样可以降低误操作风险，保留用户对已有配置的控制权。

## 影响范围

需要同步调整的范围包括：

- Shell 脚本：
  - `sh/wsha.sh`
  - `sh/wsh-ping.bat`
  - 新增 `sh/install.sh`
  - 新增 `sh/uninstall.sh`
  - 可能新增 `sh/remote-install.sh`
- Python：
  - `sh/wsha-core.py`
  - `py/wsha/config.py`
- 补全：
  - `clink-lua-scripts/*.lua`
- 文档：
  - `README.md`
  - `docs/WSHA.md`
  - `docs/INSTALL.md`
- 测试：
  - 受路径假设影响的 shell / Python / wrapper 测试

## 数据流

### 安装流程

```text
curl -fsSL "$INSTALL_URL" | bash
  -> remote-install.sh
  -> 检测平台 / shell
  -> 下载临时文件
  -> install.sh
  -> 创建 ~/.local/share/git-utils.sh
  -> 复制 sh 运行时文件
  -> 生成 ~/.local/bin launcher
  -> 生成 install-report.json
  -> 打印 next steps
```

### 运行流程

```text
用户执行 w / wsha / wsh
  -> launcher
  -> 设置 APP_HOME / APP_SH / APP_CONFIG
  -> 读取 $APP_CONFIG 下内置配置
  -> 合并用户级 / 项目级配置
  -> 执行目标命令
```

### 卸载流程

```text
用户执行 uninstall.sh
  -> 校验安装根
  -> 删除 launcher
  -> 删除运行时目录
  -> 保留或可选删除用户配置
  -> 输出 uninstall report
```

## 错误处理

安装器与卸载器需要覆盖以下场景：

- 网络下载失败
  - 远程入口应中止，并输出清晰错误
  - 如后续实现包含重试，需显式记录每次重试
- 非 Git Bash 的 Windows shell
  - 直接拒绝执行，并提示切换到 Git Bash
- 目标目录不可写
  - 中止安装，report 中记录失败原因
- launcher 已存在且不属于当前工具
  - 不覆盖，要求用户手动处理
- 部分文件复制成功、部分失败
  - 输出失败摘要，保留已写入清单，避免无痕失败

## 测试策略

本次设计要求优先新增测试，不默认修改现有测试语义。

建议测试覆盖包括：

1. 路径解析
   - 新路径优先
   - 旧路径 fallback
   - `APP_HOME` / `APP_SH` / `APP_CONFIG` 注入正确

2. 安装器
   - 安装到用户私有目录
   - launcher 生成正确
   - report 记录完整
   - Windows Git Bash 限制生效

3. 卸载器
   - 删除已安装文件
   - 默认保留用户配置
   - 显式删除配置时行为正确
   - report 记录完整

4. 兼容行为
   - 检测旧布局但不自动迁移
   - 发现冲突 launcher 时拒绝覆盖

如果后续需要修改旧测试用例，应先说明原因并获得确认。

## 验收标准

- 仓库内不再依赖根目录 `config/` 作为运行时主路径
- `sh/` 可以被明确视为运行时主体
- 用户可通过远程入口完成安装
- 安装主体落在 `~/.local/share/git-utils.sh`
- PATH 中仅需要薄 launcher
- Windows 安装脚本仅允许在 Git Bash 中执行
- 安装完成后可获得清晰 report，列出写入文件与后续动作
- 卸载脚本可删除安装产物，并输出卸载结果
- 旧版布局仅检测和提示，不自动迁移

## 实施建议

推荐按以下顺序实施：

1. 先重构目录与路径解析，建立 `sh/config` 新主路径和旧路径 fallback
2. 再实现本地 `install.sh` / `uninstall.sh`
3. 最后补远程入口和安装文档

这样可以先稳定运行时，再叠加安装能力，降低调试复杂度。
