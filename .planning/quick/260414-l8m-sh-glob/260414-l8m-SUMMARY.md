# Quick Task 260414-l8m Summary

## 概要
已完成 shell 版 `wsha.sh` 的目录化配置加载改造，并同步更新 `docs/INSTALL.md` 说明，Shell 版本现在与 Python 版的 `config/wsh-alias/*.txt` 目录结构保持一致。

## 完成任务

### Task 1: 实现目录 glob 加载和前缀解析
- 新增目录级配置加载逻辑，支持遍历 `*.txt` 文件并跳过以下划线开头的文件。
- 配置缓存版本从 `v2` 提升到 `v3`，避免旧缓存污染新解析结果。
- 增加 `ALIAS_PREFIX_TYPES` 记录 alias 前缀执行模式，并支持 `&` / `|` 前缀解析。
- `load_config()` 现在可识别目录 spec，并在 `main()` 中改为加载目录路径。
- `show_list_table()` 按来源名称分组，兼容目录模式下同一来源多个配置文件。

验证：
- `bash -n sh/wsha.sh`
- `bash sh/wsha.sh --list 2>&1 | head -20`

提交：`9361eec`

### Task 2: 更新 INSTALL.md 文档
- 新增配置说明，明确目录化配置路径：
  - `APP_HOME/config/wsh-alias/`
  - `$HOME/.config/wsh-alias/`
  - `$PWD/.config/wsh-alias/`
- 补充 `_` 前缀文件会被忽略的规则。
- 保留 `WSHA_CONFIG_FILE` 单文件覆盖说明，兼容临时配置场景。

验证：
- `grep -n "wsh-alias" docs/INSTALL.md`

提交：`1fadefc`

## 结果
- Shell 配置加载已支持目录 glob。
- 文档已同步为目录形式说明。
- 本次 quick task 的代码改动已分别提交。
