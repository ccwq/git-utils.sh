#!/bin/bash

set -u

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_DIR="$PROJECT_ROOT/test_playground_install"
PASS_COUNT=0
FAIL_COUNT=0

log_success() { echo -e "${GREEN}[PASS]${NC} $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

setup() {
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR/home" "$TEST_DIR/bin"
}

test_install_writes_runtime_and_report() {
    # Given：仓库源码和隔离的 HOME / bin 目录已准备完成。
    # When：通过 scripts/install.sh 执行本地安装。
    # Then：安装目录、launcher 和 install-report.json 会被正确写入。
    # 防回归：防止安装入口迁移到 scripts 后仍测试旧 sh/install.sh 路径。
    local install_root="$TEST_DIR/home/.local/share/git-utils-a"
    local bin_dir="$TEST_DIR/bin-a"
    HOME="$TEST_DIR/home" bash "$PROJECT_ROOT/scripts/install.sh" --source "$PROJECT_ROOT" --install-root "$install_root" --bin-dir "$bin_dir" >/tmp/install-test.log 2>&1

    if [[ -f "$install_root/install-report.json" ]] \
        && [[ -f "$install_root/sh/config/wsh-alias/default.txt" ]] \
        && [[ -f "$install_root/sh/core/wsha_core.py" ]] \
        && [[ -f "$install_root/sh/core/exec-git-bash.bat" ]] \
        && [[ -f "$install_root/sh/core/tping.sh" ]] \
        && [[ -f "$bin_dir/w" ]] \
        && grep -q '"launchers_created"' "$install_root/install-report.json"; then
        log_success "安装脚本会写入运行时与 report"
    else
        log_fail "安装脚本未正确写入运行时或 report"
    fi
}

test_install_report_records_legacy_paths() {
    # Given：用户 HOME 中存在旧版 .config/wsh-alias 布局。
    # When：通过 scripts/install.sh 执行本地安装。
    # Then：install-report.json 会记录 migration_suggested=true。
    # 防回归：防止安装入口迁移后遗漏旧布局检测报告。
    local install_root="$TEST_DIR/home/.local/share/git-utils-b"
    local bin_dir="$TEST_DIR/bin-b"
    mkdir -p "$TEST_DIR/home/.config/wsh-alias"
    echo "foo echo bar" > "$TEST_DIR/home/.config/wsh-alias/default.txt"

    HOME="$TEST_DIR/home" bash "$PROJECT_ROOT/scripts/install.sh" --source "$PROJECT_ROOT" --install-root "$install_root" --bin-dir "$bin_dir" >/tmp/install-test-legacy.log 2>&1

    if grep -q '"migration_suggested": true' "$install_root/install-report.json"; then
        log_success "安装 report 会记录旧布局提示"
    else
        log_fail "安装 report 未记录旧布局提示"
    fi
}

test_uninstall_removes_launchers_but_keeps_user_config() {
    # Given：安装产物和用户级 alias 配置都已存在。
    # When：执行运行时 sh/uninstall.sh 卸载。
    # Then：launcher 和安装目录被删除，用户配置仍保留。
    # 防回归：确保 install.sh 迁入 scripts 后不会破坏运行时卸载入口。
    local install_root="$TEST_DIR/home/.local/share/git-utils-c"
    local bin_dir="$TEST_DIR/bin-c"
    mkdir -p "$TEST_DIR/home/.config/wsh-alias"
    echo "foo echo bar" > "$TEST_DIR/home/.config/wsh-alias/default.txt"
    HOME="$TEST_DIR/home" bash "$PROJECT_ROOT/scripts/install.sh" --source "$PROJECT_ROOT" --install-root "$install_root" --bin-dir "$bin_dir" >/tmp/install-test-uninstall.log 2>&1

    HOME="$TEST_DIR/home" bash "$PROJECT_ROOT/sh/uninstall.sh" --install-root "$install_root" --bin-dir "$bin_dir" --yes >/tmp/uninstall-test.log 2>&1

    if [[ ! -e "$bin_dir/w" ]] \
        && [[ ! -d "$install_root" ]] \
        && [[ -f "$TEST_DIR/home/.config/wsh-alias/default.txt" ]]; then
        log_success "卸载会删除安装产物并保留用户配置"
    else
        log_fail "卸载行为不符合预期"
    fi
}

test_install_windows_launchers_use_core_exec_git_bash() {
    # Given：安装脚本已经生成 Windows bin wrapper。
    # When：检查生成的 w.bat 内容。
    # Then：w.bat 应委托运行时原生 w.bat，而不是强制进入 Git Bash。
    # 防回归：保证安装后的 CMD 环境注入继续使用 CMD 格式。
    local install_root="$TEST_DIR/home/.local/share/git-utils-d"
    local bin_dir="$TEST_DIR/bin-d"
    HOME="$TEST_DIR/home" bash "$PROJECT_ROOT/scripts/install.sh" --source "$PROJECT_ROOT" --install-root "$install_root" --bin-dir "$bin_dir" >/tmp/install-test-core-launcher.log 2>&1

    if [[ -f "$install_root/bin/w.bat" ]] \
        && grep -Fq '%APP_SH%\w.bat' "$install_root/bin/w.bat"; then
        log_success "Windows 安装 wrapper 使用原生 w.bat"
    else
        log_fail "Windows 安装 wrapper 未使用原生 w.bat"
    fi
}

# Given：安装脚本在 Windows Git Bash 环境中写入运行时与 launcher。
# When：执行安装并检查安装产物。
# Then：应生成 PowerShell 原生 `wsha.ps1` launcher，且它会委托运行时 sh/wsha.ps1。
# 防回归：防止 PowerShell 入口只存在于源码树，安装后无法使用。
test_install_writes_powershell_wsha_launcher() {
    local install_root="$TEST_DIR/home/.local/share/git-utils-ps"
    local bin_dir="$TEST_DIR/bin-ps"
    local output
    local run_code
    HOME="$TEST_DIR/home" bash "$PROJECT_ROOT/scripts/install.sh" --source "$PROJECT_ROOT" --install-root "$install_root" --bin-dir "$bin_dir" >/tmp/install-test-powershell-launcher.log 2>&1
    output=$(powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$install_root/bin/wsha.ps1" -e name=ccwq Write-Output '$env:name' 2>&1)
    run_code=$?

    if [[ -f "$install_root/bin/wsha.ps1" ]] \
        && grep -Fq 'wsha.ps1' "$install_root/bin/wsha.ps1" \
        && [[ $run_code -eq 0 ]] \
        && [[ "$output" == *"ccwq"* ]]; then
        log_success "安装脚本会写入 PowerShell wsha launcher"
    else
        log_fail "安装后的 PowerShell wsha launcher 不可用 output=[$output] code=$run_code"
    fi
}

main() {
    setup
    test_install_writes_runtime_and_report
    test_install_report_records_legacy_paths
    test_install_windows_launchers_use_core_exec_git_bash
    test_install_writes_powershell_wsha_launcher
    test_uninstall_removes_launchers_but_keeps_user_config
    echo "PASS=$PASS_COUNT FAIL=$FAIL_COUNT"
    [[ $FAIL_COUNT -eq 0 ]]
}

main
