#!/bin/bash

set -u

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_DIR="$PROJECT_ROOT/test_playground_runtime_layout"
PASS_COUNT=0
FAIL_COUNT=0

log_success() { echo -e "${GREEN}[PASS]${NC} $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

strip_ansi() {
    printf "%s" "$1" | awk '
        BEGIN { esc = sprintf("%c", 27) }
        { gsub(esc "\\[[0-9;]*[A-Za-z]", ""); print }
    '
}

setup() {
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR/home/.config/wsh-alias" "$TEST_DIR/work/.config/wsh-alias"
}

test_builtin_app_config_points_to_sh_config() {
    local config_file="$TEST_DIR/env.txt"
    cat > "$config_file" <<'EOF'
show-config echo %APP_CONFIG%
EOF

    local output
    output=$(WSHA_CONFIG_FILE="$config_file" bash "$PROJECT_ROOT/sh/wsha.sh" show-config 2>&1)
    output=$(strip_ansi "$output")
    if [[ "$output" == *"/sh/config"* ]]; then
        log_success "APP_CONFIG 默认指向 sh/config"
    else
        log_fail "APP_CONFIG 未指向 sh/config: $output"
    fi
}

test_default_list_uses_sh_config_builtin_dir() {
    cat > "$TEST_DIR/home/.config/wsh-alias/default.txt" <<'EOF'
foo echo user-foo
EOF
    cat > "$TEST_DIR/work/.config/wsh-alias/default.txt" <<'EOF'
bar echo local-bar
EOF

    local output
    output=$(cd "$TEST_DIR/work" && HOME="$TEST_DIR/home" bash "$PROJECT_ROOT/sh/wsha.sh" --list 2>&1)
    output=$(strip_ansi "$output")
    if [[ "$output" == *"$PROJECT_ROOT/sh/config/wsh-alias"* ]] && [[ "$output" == *"default.txt"* ]]; then
        log_success "默认列表优先展示 sh/config 内置目录"
    else
        log_fail "默认列表未展示 sh/config 内置目录: $output"
    fi
}

main() {
    setup
    test_builtin_app_config_points_to_sh_config
    test_default_list_uses_sh_config_builtin_dir
    echo "PASS=$PASS_COUNT FAIL=$FAIL_COUNT"
    [[ $FAIL_COUNT -eq 0 ]]
}

main
