# Sh Runtime Install Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将运行时配置收口到 `sh/config`，补齐安装/卸载脚本，并让现有 `w`/`wsha`/`wsh-ping` 逻辑支持新旧路径兼容。

**Architecture:** 先把运行时路径解析统一为 `APP_HOME` + `APP_SH` + `APP_CONFIG`，让 shell、Python、batch、补全脚本都优先使用 `sh/config`，再新增 `install.sh` / `uninstall.sh` 负责把运行时复制到用户目录并生成 launcher/report。对旧版 `APP_HOME/config` 保留 fallback，避免一次性打断现有使用方式。

**Tech Stack:** Bash, Windows batch, Python, ripgrep, pytest, shell tests

---

## File Map

- Modify: `sh/wsha.sh`
  - 统一 `APP_CONFIG` 到 `sh/config`
  - 为旧的 `APP_HOME/config` 提供 fallback
- Modify: `sh/wsha-core.py`
  - 统一配置目录发现逻辑
  - 让缓存 key 与新路径兼容
- Modify: `py/wsha/config.py`
  - 内置配置复制与运行时解析切到 `sh/config`
- Modify: `py/setup_tools.py`
  - normal install 预热缓存时从 `sh/config/wsh-alias` 复制
- Modify: `sh/wsh-ping.bat`
  - 预设文件路径切到 `sh\config\wsh-ping.txt`
- Modify: `clink-lua-scripts/git-utils-common.lua`
  - 补全扫描路径切到 `sh/config`
- Create: `sh/install.sh`
  - 安装运行时到 `~/.local/share/git-utils.sh`
  - 生成 launcher 和安装 report
- Create: `sh/uninstall.sh`
  - 删除安装产物并生成卸载摘要
- Create: `sh/remote-install.sh`
  - 作为远程安装薄入口的本地对应实现
- Create: `__test__/install.test.sh`
  - 覆盖安装/卸载与 report
- Modify or Add: 受路径迁移影响的现有测试
  - 仅在获得用户批准后调整旧断言
- Modify: `README.md`
- Modify: `docs/WSHA.md`
- Modify: `docs/INSTALL.md`

### Task 1: Runtime Path Switch

**Files:**
- Modify: `sh/wsha.sh`
- Modify: `sh/wsha-core.py`
- Modify: `py/wsha/config.py`
- Test: `__test__/wsha.test.sh`
- Test: `__test__/test_cli_entry_parsing.py`

- [ ] **Step 1: 为运行时路径切换新增测试用例**

```bash
# __test__/wsha.test.sh
test_prefers_sh_config_when_present() {
    mkdir -p "$PROJECT_ROOT/sh/config/wsh-alias"
    cat > "$PROJECT_ROOT/sh/config/wsh-alias/test-runtime.txt" <<'EOF'
show-config echo %APP_CONFIG%
EOF

    run_wsha_capture "$PROJECT_ROOT" show-config
    assert_contains "$RUN_STDOUT" "/sh/config"
}
```

```python
# __test__/test_cli_entry_parsing.py
def test_get_app_env_prefers_sh_config(monkeypatch):
    monkeypatch.setenv("APP_HOME", "/tmp/app")
    monkeypatch.delenv("APP_CONFIG", raising=False)
    app_home, app_sh, app_config = get_app_env()
    assert app_home == "/tmp/app"
    assert app_sh == "/tmp/app/sh"
    assert app_config == "/tmp/app/sh/config"
```

- [ ] **Step 2: 运行新增测试，确认当前失败**

Run:

```bash
sh/exec-git-bash.bat -lc "__test__/wsha.test.sh"
pytest __test__/test_cli_entry_parsing.py -q
```

Expected:

- 新增 shell 断言失败，当前仍输出旧 `config`
- Python 断言失败，当前 `APP_CONFIG` 仍指向 `APP_HOME/config`

- [ ] **Step 3: 实现统一的运行时路径解析与 fallback**

```bash
# sh/wsha.sh
resolve_app_config_dir() {
    local new_dir="$APP_SH/config"
    local old_dir="$APP_HOME/config"

    if [[ -d "$new_dir" ]]; then
        printf '%s' "$new_dir"
        return 0
    fi

    printf '%s' "$old_dir"
}
```

```python
# sh/wsha-core.py / py/wsha/config.py
def resolve_app_config(app_home: str, app_sh: str) -> str:
    new_dir = os.path.join(app_sh, "config")
    old_dir = os.path.join(app_home, "config")
    return new_dir if os.path.isdir(new_dir) else old_dir
```

- [ ] **Step 4: 运行测试，确认新路径优先且旧路径兼容**

Run:

```bash
sh/exec-git-bash.bat -lc "__test__/wsha.test.sh"
pytest __test__/test_cli_entry_parsing.py -q
```

Expected:

- 新增新路径用例通过
- 原有非路径相关测试保持通过

- [ ] **Step 5: Commit**

```bash
git add sh/wsha.sh sh/wsha-core.py py/wsha/config.py __test__/wsha.test.sh __test__/test_cli_entry_parsing.py
git commit -m "refactor: resolve runtime config from sh directory"
```

### Task 2: Move Builtin Config Consumers

**Files:**
- Modify: `sh/wsh-ping.bat`
- Modify: `py/setup_tools.py`
- Modify: `clink-lua-scripts/git-utils-common.lua`
- Test: `__test__/test_windows_wrappers.py`
- Test: `__test__/test_cli_helpers.py`

- [ ] **Step 1: 为 `wsh-ping` 和缓存预热增加新路径测试**

```python
def test_wsh_ping_uses_sh_config():
    content = (ROOT / "sh" / "wsh-ping.bat").read_text(encoding="utf-8")
    assert r'set "CONFIG_FILE=%SCRIPT_DIR%config\wsh-ping.txt"' in content

def test_setup_tools_copies_from_sh_config():
    content = (ROOT / "py" / "setup_tools.py").read_text(encoding="utf-8")
    assert 'project_root / "sh" / "config" / "wsh-alias"' in content
```

- [ ] **Step 2: 运行测试，确认当前失败**

Run:

```bash
pytest __test__/test_windows_wrappers.py __test__/test_cli_helpers.py -q
```

Expected:

- 新增路径断言失败

- [ ] **Step 3: 更新批处理、安装 hook、补全脚本的路径引用**

```bat
set "CONFIG_FILE=%SCRIPT_DIR%config\wsh-ping.txt"
```

```python
src_config = project_root / "sh" / "config" / "wsh-alias"
```

```lua
join_path(ROOT_DIR, "sh", "config", "wsh-alias")
```

- [ ] **Step 4: 运行测试确认通过**

Run:

```bash
pytest __test__/test_windows_wrappers.py __test__/test_cli_helpers.py -q
```

Expected:

- 路径消费者测试通过

- [ ] **Step 5: Commit**

```bash
git add sh/wsh-ping.bat py/setup_tools.py clink-lua-scripts/git-utils-common.lua __test__/test_windows_wrappers.py __test__/test_cli_helpers.py
git commit -m "refactor: point runtime helpers to sh config"
```

### Task 3: Add Installer and Uninstaller

**Files:**
- Create: `sh/install.sh`
- Create: `sh/uninstall.sh`
- Create: `sh/remote-install.sh`
- Create: `__test__/install.test.sh`

- [ ] **Step 1: 编写安装/卸载测试脚本**

```bash
test_install_writes_runtime_and_report() {
    export HOME="$TEST_HOME"
    bash "$PROJECT_ROOT/sh/install.sh" --source "$PROJECT_ROOT"
    [[ -f "$HOME/.local/share/git-utils.sh/install-report.json" ]]
    [[ -f "$HOME/.local/bin/w" ]]
}

test_uninstall_removes_launchers_but_keeps_user_config() {
    mkdir -p "$HOME/.config/wsh-alias"
    echo "foo echo bar" > "$HOME/.config/wsh-alias/default.txt"
    bash "$PROJECT_ROOT/sh/uninstall.sh" --yes
    [[ ! -e "$HOME/.local/bin/w" ]]
    [[ -f "$HOME/.config/wsh-alias/default.txt" ]]
}
```

- [ ] **Step 2: 运行测试，确认当前失败**

Run:

```bash
sh/exec-git-bash.bat -lc "__test__/install.test.sh"
```

Expected:

- 失败，原因是安装脚本不存在

- [ ] **Step 3: 以最小实现补齐安装/卸载**

```bash
# sh/install.sh
INSTALL_ROOT="${HOME}/.local/share/git-utils.sh"
BIN_DIR="${HOME}/.local/bin"
REPORT_PATH="${INSTALL_ROOT}/install-report.json"
```

```bash
# sh/uninstall.sh
KEEP_USER_CONFIG=1
rm -f "${BIN_DIR}/w" "${BIN_DIR}/wsha" "${BIN_DIR}/wsh"
rm -rf "${INSTALL_ROOT}"
```

- [ ] **Step 4: 运行测试确认安装/卸载主链路通过**

Run:

```bash
sh/exec-git-bash.bat -lc "__test__/install.test.sh"
```

Expected:

- 安装产物和 report 生成成功
- 卸载后 launcher 被删除

- [ ] **Step 5: Commit**

```bash
git add sh/install.sh sh/uninstall.sh sh/remote-install.sh __test__/install.test.sh
git commit -m "feat: add runtime install and uninstall scripts"
```

### Task 4: Wire Launchers and Legacy Detection

**Files:**
- Modify: `sh/install.sh`
- Modify: `sh/uninstall.sh`
- Test: `__test__/install.test.sh`

- [ ] **Step 1: 为 report 和旧布局检测补测试**

```bash
test_install_report_records_legacy_paths() {
    mkdir -p "$HOME/.config/wsh-alias"
    bash "$PROJECT_ROOT/sh/install.sh" --source "$PROJECT_ROOT"
    grep -q '"migration_suggested": true' "$HOME/.local/share/git-utils.sh/install-report.json"
}
```

- [ ] **Step 2: 运行测试，确认当前失败**

Run:

```bash
sh/exec-git-bash.bat -lc "__test__/install.test.sh"
```

Expected:

- report 中尚未记录 legacy 检测

- [ ] **Step 3: 实现 launcher 模板、report 清单和 legacy 检测**

```bash
write_launcher() {
    local name="$1"
    cat > "$BIN_DIR/$name" <<EOF
#!/bin/bash
export APP_HOME="$INSTALL_ROOT"
exec "$INSTALL_ROOT/sh/$name.sh" "\$@"
EOF
}
```

```bash
legacy_detected_json() {
    [[ -d "$HOME/.config/wsh-alias" ]] && printf '"legacy_detected":["%s"],"migration_suggested":true' "$HOME/.config/wsh-alias"
}
```

- [ ] **Step 4: 运行测试确认 report 与 launcher 正确**

Run:

```bash
sh/exec-git-bash.bat -lc "__test__/install.test.sh"
```

Expected:

- report 包含 `files_written`、`launchers_created`、`legacy_detected`
- launcher 执行时注入正确 `APP_HOME`

- [ ] **Step 5: Commit**

```bash
git add sh/install.sh sh/uninstall.sh __test__/install.test.sh
git commit -m "feat: report installed files and legacy hints"
```

### Task 5: Update Docs After Tests Pass

**Files:**
- Modify: `README.md`
- Modify: `docs/WSHA.md`
- Modify: `docs/INSTALL.md`

- [ ] **Step 1: 先运行完整相关测试，确认实现稳定**

Run:

```bash
pytest __test__/test_windows_wrappers.py __test__/test_cli_entry_parsing.py __test__/test_cli_helpers.py -q
sh/exec-git-bash.bat -lc "__test__/wsha.test.sh"
sh/exec-git-bash.bat -lc "__test__/install.test.sh"
```

Expected:

- 全部通过后再进入文档更新

- [ ] **Step 2: 更新 README 安装说明和路径说明**

```markdown
- 内置配置：`sh/config/wsh-alias/`
- `wsh-ping` 读取 `sh/config/wsh-ping.txt`
- 安装到 `~/.local/share/git-utils.sh`
```

- [ ] **Step 3: 更新 `docs/WSHA.md` 与 `docs/INSTALL.md`**

```markdown
`APP_CONFIG` = `$APP_HOME/sh/config`
```

- [ ] **Step 4: 快速人工检查文档中的旧路径残留**

Run:

```bash
rg -n "config/wsh|APP_HOME/config" README.md docs/WSHA.md docs/INSTALL.md
```

Expected:

- 仅保留兼容说明中的旧路径引用

- [ ] **Step 5: Commit**

```bash
git add README.md docs/WSHA.md docs/INSTALL.md
git commit -m "docs: document sh runtime install layout"
```

## Self-Review

- Spec coverage:
  - `sh/config` 新布局：Task 1, Task 2
  - 安装到用户私有目录：Task 3, Task 4
  - 安装/卸载 report：Task 3, Task 4
  - Windows Git Bash 限制：Task 3
  - 旧路径 fallback 与迁移提示：Task 1, Task 4
  - 文档同步：Task 5
- Placeholder scan:
  - 未保留 `TODO/TBD/implement later` 一类占位内容
- Type consistency:
  - 统一使用 `APP_HOME` / `APP_SH` / `APP_CONFIG`
  - 安装 report 统一使用 `install-report.json`

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-24-sh-runtime-install-plan.md`.

Two execution options:

1. Subagent-Driven (recommended) - I dispatch a fresh subagent per task, review between tasks, fast iteration
2. Inline Execution - Execute tasks in this session using executing-plans, batch execution with checkpoints

The user has already requested inline implementation in this session, so execute inline after plan review and any required approval gates for existing test modifications.
