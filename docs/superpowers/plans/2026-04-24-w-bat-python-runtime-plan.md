# w / wsha.bat Python Runtime Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 `sh/w.bat` 作为 `sh/wsha.bat` 的语法糖入口，而 `sh/wsha.bat` 成为 `wsha.sh` 的 Windows 对应实现：通过调用 `sh/wsha-core.py` 完成解析，并在 Windows 下执行解析结果与输出回显，不再通过 Git Bash 转发到 `wsha.sh`。

**Architecture:** 保持 `wsha.sh` 的总分层不变：`wsha-core.py` 负责 alias 解析与命令展开，`wsha.bat` 负责 Windows 下的入口参数处理、Python 定位、调用 `wsha-core.py`、区分“透传/别名命中”、打印 `alias hit` / `exec` 回显，并执行最终命令；`w.bat` 仅设置 `WSHA_ENTRY=w` 后委托给 `wsha.bat`。Python 不可用时直接报错退出，不再回退到 Git Bash。

**Tech Stack:** Windows batch, Python, Click CLI, pytest

---

## File Structure

- Modify: `sh/w.bat`
  - 改成仅负责语法糖转发到 `wsha.bat`。
- Modify: `sh/wsha.bat`
  - 从 Git Bash 包装器改成 Windows 版 `wsha.sh` 入口，并承接解析、执行、回显职责。
- Maybe modify: `sh/wsha-core.py`
  - 如果当前 `wsha-core.py` 对 Windows 批处理入口还有缺口，则做最小补齐，但不改它“只负责解析/展开”的定位。
- Modify: `__test__/test_windows_wrappers.py`
  - 用户已批准修改现有测试，需要把旧的 Git Bash 断言调整为新的批处理分层断言。
- Maybe create: `__test__/test_w_bat_python_launcher.py`
  - 如果需要把 `w.bat` 与 `wsha.bat` 的职责拆开回归，可新增更细粒度测试。
- Maybe modify: `docs/WSHA.md`
  - Windows 入口说明目前写死“统一通过 Git Bash”，需要和实现保持一致。
- Maybe modify: `README.md`
  - 当前 README 也写死了 `w.bat` / `wsha.bat` 通过 `exec-git-bash.bat` 运行。

## Task 1: 固化入口分层与职责

**Files:**
- Review: `sh/w.bat`
- Review: `sh/wsha.bat`
- Review: `docs/WSHA.md`
- Review: `README.md`
- Review: `__test__/test_windows_wrappers.py`

- [ ] **Step 1: 固化 `w.bat` / `wsha.bat` 的职责边界**

已确认方案：

```text
`sh/w.bat` 是 `sh/wsha.bat` 的语法糖：
- `w.bat` 只负责设置 `WSHA_ENTRY=w` 并转发参数
- `wsha.bat` 负责 Python 启动、调用 `wsha-core.py`、命令执行、执行前回显
```

- [ ] **Step 2: 明确 Python 不可用时的行为**

已确认方案：

```text
直接报错并退出，提示当前未找到可用 Python 解释器。
不再回退到 `exec-git-bash.bat` / `wsha.sh`。
```

- [ ] **Step 3: 明确批处理调用的 Python 入口**

已确认方案：

```text
由 `wsha.bat` 调用 `sh/wsha-core.py`；
`w.bat` 不直接调用 Python，而是转发给 `wsha.bat`。
```

实现约束：

```text
参考 `wsha.sh` 的行为来实现 Windows 版本：
- `wsha-core.py` 仍负责“解析并输出最终命令文本”
- `wsha.bat` 负责“调用 core + 回显 + 执行”
- 行为目标是与 `wsha.sh` 尽量一致，只是运行在 Windows 下
```

## Task 2: 设计 `wsha.bat` 的 Python 启动策略

**Files:**
- Modify: `sh/wsha.bat`
- Maybe modify: `sh/wsha-core.py`

- [ ] **Step 1: 定义批处理中的 Python 查找顺序**

建议顺序：

```bat
1. 使用显式环境变量，例如 `WSHA_PYTHON`
2. `py -3`
3. `python`
4. `python3`
```

说明：Windows 上 `py -3` 通常比裸 `python` 更稳定；加 `WSHA_PYTHON` 方便用户强制绑定解释器。

- [ ] **Step 2: 定义批处理如何调用仓库内 Python 入口**

候选实现：

```bat
set "SCRIPT_DIR=%~dp0"
set "PY_ENTRY=%SCRIPT_DIR%wsha-core.py"
if not defined WSHA_ENTRY set "WSHA_ENTRY=wsha"
```

关键点：

```text
- `wsha.bat` 要参考 `wsha.sh`，承接调用 core 后的回显和执行逻辑
- `wsha-core.py` 只负责返回最终命令文本，不负责 Windows 端执行
- 需要把 `%*` 原样透传，不能破坏含空格和 `--help` 的参数
```

- [ ] **Step 3: 明确直接执行与 fallback 的退出码约定**

已确认方案：

```text
- Python 启动成功时，返回 Python 进程退出码
- Python 解释器不可用时，直接返回非 0 退出码并输出错误提示
- `wsha-core.py` 返回空结果或异常时，`wsha.bat` 返回非 0 退出码
```

## Task 3: 规划 `w.bat` 语法糖转发

**Files:**
- Modify: `sh/w.bat`

- [ ] **Step 1: 将 `w.bat` 收敛为薄包装器**

目标行为：

```bat
@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
set "WSHA_ENTRY=w"
call "%SCRIPT_DIR%wsha.bat" %*
exit /b %errorlevel%
```

说明：

```text
- `w.bat` 不再接触 Python 路径探测细节
- 所有 Windows 端实现逻辑都集中在 `wsha.bat`
```

## Task 4: 规划测试调整

**Files:**
- Modify: `__test__/test_windows_wrappers.py`
- Maybe create: `__test__/test_wsha_bat_python_launcher.py`

- [ ] **Step 1: 按已授权结果修改现有测试**

当前状态：

```text
用户已明确批准修改现有测试。
```

- [ ] **Step 2: 确定测试策略**

已确认方案：

```text
直接修改 `__test__/test_windows_wrappers.py`。
```

- [ ] **Step 3: 定义最小回归断言**

建议断言：

```text
- `w.bat` 设置了 `WSHA_ENTRY=w`
- `w.bat` 调用的是 `wsha.bat`，而不是 `exec-git-bash.bat`
- `wsha.bat` 会调用 `wsha-core.py` 而非 `wsha.sh`
- `wsha.bat` 包含与 `wsha.sh` 对齐的回显/执行分支
- `wsha.bat` 在未设置 `WSHA_ENTRY` 时默认回落到 `wsha`
```

## Task 5: 规划文档同步

**Files:**
- Modify: `docs/WSHA.md`
- Modify: `README.md`

- [ ] **Step 1: 在测试通过后更新 `docs/WSHA.md`**

需要修正的内容：

```text
- “Windows 下统一通过 Git Bash” 这句话不再对 `w` / `wsha` 成立
- 需要改成区分入口：
  - `w.bat`：语法糖，转发到 `wsha.bat`
  - `wsha.bat`：Windows 下调用 `wsha-core.py` 并执行结果
```

- [ ] **Step 2: 在测试通过后更新 `README.md`**

需要修正的内容：

```text
- Windows 入口说明
- `w` / `wsha` 章节中的实现描述
- 需要补充 Python 解释器要求与未找到时的报错行为
```

## Task 6: 验证计划

**Files:**
- Test: `__test__/test_windows_wrappers.py`
- Test: `__test__/test_wsha_bat_python_launcher.py`

- [ ] **Step 1: 跑 Python 相关单测**

建议命令：

```bash
pytest __test__/test_windows_wrappers.py -q
```

如果新增专用测试：

```bash
pytest __test__/test_windows_wrappers.py __test__/test_wsha_bat_python_launcher.py -q
```

- [ ] **Step 2: 做最小人工验证**

建议场景：

```text
1. `sh\\w.bat --list`
2. `sh\\w.bat pcodex`
3. `sh\\w.bat echo hello`
4. `sh\\wsha.bat --list`
5. Python 不存在或被故意指定为无效路径时的报错行为
```

- [ ] **Step 3: 文档同步**

约束：

```text
只有在测试跑通之后，才更新 `docs/WSHA.md` 和 `README.md`。
```

## Open Questions

1. `wsha.bat` 的执行分支是否需要完全镜像 `wsha.sh` 的“复杂命令单独走 shell、简单命令直接执行”策略？
2. Python 查找顺序是否固定为 `WSHA_PYTHON` -> `py -3` -> `python` -> `python3`？

## Self-Review

- 规格覆盖：
  - 已覆盖 `w.bat` / `wsha.bat` 分层、`wsha-core.py` 解析、测试审批结果、文档延后同步。
- 占位符扫描：
  - 无 `TBD` / `TODO` 类占位描述。
- 一致性检查：
  - 方案已调整为“`w.bat` 语法糖 + `wsha.bat` 对齐 `wsha.sh` + `wsha-core.py` 负责解析”的结构，与用户最新决策一致。
