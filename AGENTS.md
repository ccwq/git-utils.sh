# 主要约束
- 使用中文
- 当前环境是windows, 优先通过 `sh\core\exec-git-bash.bat` 调用 Git Bash, 例如 `sh\core\exec-git-bash.bat .\foo\bar.sh`
    - Git Bash 解析顺序：有效的 `GIT_BASH` 环境变量、HKCU 用户缓存、`where.exe git` 相对路径、Git 默认安装路径。
- 原 `/prompts/spec.md` 当前不存在。修改脚本前先检查对应规范文件；未提供时，沿用相邻脚本的 Bash/Python 风格和本文件约束。

## 项目结构与入口
- Shell 运行时在 `sh/`：`w.sh` / `wsha.sh` 为 Unix 入口，`w.bat` / `wsha.bat` / `wsh.bat` 为 Windows 入口；共享启动桥在 `sh/core/exec-git-bash.bat`。
- Python `wsha` CLI 位于 `py/wsha/`，包配置见 `pyproject.toml`；别名配置位于 `sh/config/wsh-alias/`。
- 安装入口为 `scripts/install.sh`，远程安装入口为 `scripts/remote-install.sh`；安装后的运行时只依赖 `sh/`，不要把仅用于仓库维护的文件放入该目录。
- 用户文档以 `README.md`、`TESTING.md`、`docs/INSTALL.md` 与 `docs/W-WSHA.md` 为准；行为变化应同步更新对应文档。

## 验证
- Shell 脚本或 Windows 包装器改动：运行对应的 `__test__/*.test.sh`，并通过 `sh\core\exec-git-bash.bat` 执行。
- Python `wsha` 改动：运行受影响的 `__test__/test_*.py` pytest 用例。
- 涉及入口、安装或运行时目录布局的跨模块改动：运行 `npm test`（等价于经 Git Bash 执行 `test-all.sh`）。


# 同步
文档和测试的同步

- 对于test的更新存在如下约束
    - 如果需要对测试用例进行修改, 需要像我说明原因, 等我审批或者调整之后,才能继续
    - 新特性可以直接新增测试用例
- 当测试用例跑通之后, 再结合测试用例来更新文档
