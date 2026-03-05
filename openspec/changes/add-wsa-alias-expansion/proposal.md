## Why

当前复杂命令输入较长、易出错，缺少统一的缩写机制。需要新增基于配置文件的命令别名展开能力，以便在 Windows 环境下通过批处理入口快速执行标准命令。

## What Changes

- 新增 `sh/wsha.bat` 作为命令入口，读取 `config/wsh-alias.txt` 并展开别名。
- 支持配置行格式：`<alias> <target...>`，其中 `<target...>` 可包含默认参数。
- 支持忽略空行与 `#` 注释行。
- 支持运行时参数拼接：`wsa <alias> <args...>`。
- 支持 `--` 作为插入占位符：当配置中存在 `--` 时，将运行时参数插入到 `--` 位置；否则附加到末尾。
- 对未知别名与配置错误提供明确失败提示与非零退出码。

## Capabilities

### New Capabilities
- `wsa-alias-expansion`: 基于 `config/wsh-alias.txt` 将短别名展开为目标命令，并按规则合并运行时参数。
- `wsa-config-parsing`: 解析 alias 配置文件，支持注释/空行忽略与合法性校验。

### Modified Capabilities
- 无

## Impact

- Affected code:
  - `sh/wsha.bat`（新增或重构）
  - `config/wsh-alias.txt`（新增示例与默认配置）
- APIs/CLI:
  - 新增/固定命令调用形式：`wsa <alias> [args...]`
- Dependencies:
  - 无新增第三方依赖，使用 Windows 批处理与现有 shell 环境
- Systems:
  - 主要影响 Windows + Git Bash 场景下的命令执行入口
