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
    local install_root="$TEST_DIR/home/.local/share/git-utils-a"
    local bin_dir="$TEST_DIR/bin-a"
    HOME="$TEST_DIR/home" bash "$PROJECT_ROOT/sh/install.sh" --source "$PROJECT_ROOT" --install-root "$install_root" --bin-dir "$bin_dir" >/tmp/install-test.log 2>&1

    if [[ -f "$install_root/install-report.json" ]] \
        && [[ -f "$install_root/sh/config/wsh-alias/default.txt" ]] \
        && [[ -f "$bin_dir/w" ]] \
        && grep -q '"launchers_created"' "$install_root/install-report.json"; then
        log_success "安装脚本会写入运行时与 report"
    else
        log_fail "安装脚本未正确写入运行时或 report"
    fi
}

test_install_report_records_legacy_paths() {
    local install_root="$TEST_DIR/home/.local/share/git-utils-b"
    local bin_dir="$TEST_DIR/bin-b"
    mkdir -p "$TEST_DIR/home/.config/wsh-alias"
    echo "foo echo bar" > "$TEST_DIR/home/.config/wsh-alias/default.txt"

    HOME="$TEST_DIR/home" bash "$PROJECT_ROOT/sh/install.sh" --source "$PROJECT_ROOT" --install-root "$install_root" --bin-dir "$bin_dir" >/tmp/install-test-legacy.log 2>&1

    if grep -q '"migration_suggested": true' "$install_root/install-report.json"; then
        log_success "安装 report 会记录旧布局提示"
    else
        log_fail "安装 report 未记录旧布局提示"
    fi
}

test_uninstall_removes_launchers_but_keeps_user_config() {
    local install_root="$TEST_DIR/home/.local/share/git-utils-c"
    local bin_dir="$TEST_DIR/bin-c"
    mkdir -p "$TEST_DIR/home/.config/wsh-alias"
    echo "foo echo bar" > "$TEST_DIR/home/.config/wsh-alias/default.txt"
    HOME="$TEST_DIR/home" bash "$PROJECT_ROOT/sh/install.sh" --source "$PROJECT_ROOT" --install-root "$install_root" --bin-dir "$bin_dir" >/tmp/install-test-uninstall.log 2>&1

    HOME="$TEST_DIR/home" bash "$PROJECT_ROOT/sh/uninstall.sh" --install-root "$install_root" --bin-dir "$bin_dir" --yes >/tmp/uninstall-test.log 2>&1

    if [[ ! -e "$bin_dir/w" ]] \
        && [[ ! -d "$install_root" ]] \
        && [[ -f "$TEST_DIR/home/.config/wsh-alias/default.txt" ]]; then
        log_success "卸载会删除安装产物并保留用户配置"
    else
        log_fail "卸载行为不符合预期"
    fi
}

main() {
    setup
    test_install_writes_runtime_and_report
    test_install_report_records_legacy_paths
    test_uninstall_removes_launchers_but_keeps_user_config
    echo "PASS=$PASS_COUNT FAIL=$FAIL_COUNT"
    [[ $FAIL_COUNT -eq 0 ]]
}

main
