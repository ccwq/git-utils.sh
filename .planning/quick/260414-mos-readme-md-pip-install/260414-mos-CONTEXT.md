# Quick Task 260414-mos: README.md更新与pip install配置复制 - Context

**Gathered:** 2026-04-14
**Status:** Ready for planning

<domain>
## Task Boundary

在 README.md 中更新陈旧的配置路径描述，并实现 pip install 时复制默认配置文件到用户目录。

</domain>

<decisions>
## Implementation Decisions

### README 更新范围
- 完全更新配置路径描述，将旧的 config/wsh-alias.txt 文件路径改为 config/wsh-alias/ 目录结构
- 更新优先级说明：builtin (APP_HOME/config/wsh-alias/) > user ($HOME/.config/wsh-alias/) > project ($PWD/.config/wsh-alias/)

### 用户目录路径
- pip install 时将 config/wsh-alias/default.txt 复制到 $HOME/.config/wsh-alias/default.txt
- 与现有 Python 实现中的 get_default_config_paths() 保持一致

### pip install 配置复制
- 使用 hatchling 的构建钩子或 pyproject.toml 配置实现自动复制
- 仅在首次安装时复制，不覆盖已存在的用户配置

### Claude's Discretion
- 具体的 hatchling 构建钩子实现方式
- 如何处理跨平台路径问题

</decisions>

<specifics>
## Specific Ideas

- 参考 config.py 中的 get_default_config_paths() 函数实现
- 用户目录格式：$HOME/.config/wsh-alias/（Linux）或 %USERPROFILE%\.config\wsh-alias\（Windows）
- 当前实际配置目录结构：config/wsh-alias/default.txt

</specifics>

<canonical_refs>
## Canonical References

- .planning/STATE.md - 项目当前状态
- py/wsha/config.py - 配置加载逻辑
- config/wsh-alias/default.txt - 默认配置文件
- pyproject.toml - Python 项目配置

</canonical_refs>