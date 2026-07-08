#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/test_utils.sh"

WSHA_TEST_BASE_DIR=$(cd "$(dirname "${BASH_SOURCE[1]:-$0}")" && pwd)
PROJECT_ROOT=$(cd "$WSHA_TEST_BASE_DIR/.." && pwd)
SCRIPT_TO_TEST="$PROJECT_ROOT/sh/wsha.sh"
TEST_DIR="$PROJECT_ROOT/test_playground_wsha"

# 准备测试沙箱与路径
setup() {
    log_info "正在设置 wsha 测试环境..."
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
}

# 清理测试沙箱
cleanup() {
    log_info "正在清理 wsha 测试环境..."
    rm -rf "$TEST_DIR"
}

write_wsha_normal_config() {
    local file_path="$1"
    cat > "$file_path" <<'EOF'
ab echo agent-browser
foo echo foobar open

# 注释行会被忽略
bar echo barbar $@ --name ccwq
EOF
}

write_wsha_duplicate_config() {
    local file_path="$1"
    cat > "$file_path" <<'EOF'
ab echo first
ab echo second
EOF
}

write_wsha_invalid_config() {
    local file_path="$1"
    cat > "$file_path" <<'EOF'
ab
EOF
}

write_wsha_quoted_wildcard_config() {
    local file_path="$1"
    cat > "$file_path" <<'EOF'
pcodex echo codex-default
"pcodex l" echo codex-last
"px*" echo pnpx $1
"px *" echo pnpx $1
"q1 *" "echo pnpx $1"
"q2 *" echo pnpx $1
"tool * *" echo $1::$2
"s**" echo wsh $$
EOF
}

write_wsha_super_rule_config() {
    local file_path="$1"
    cat > "$file_path" <<'EOF'
"grcmd * *" $1 | findstr $2
EOF
}

write_wsha_grep_chain_config() {
    local file_path="$1"
    cat > "$file_path" <<'EOF'
"grcmd * *" $1 | findstr $2
grep wsha grcmd
EOF
}

write_wsha_argv_quote_config() {
    local file_path="$1"
    cat > "$file_path" <<'EOF'
codex-l echo codex $@
codex-yo wsha codex-l --yolo $@
coyo wsha codex-yo
EOF
}

write_wsha_git_up_alias_config() {
    local file_path="$1"
    cat > "$file_path" <<'EOF'
codex-l echo codex $@
codex-yo wsha codex-l --yolo $@
coyo wsha codex-yo
git-up-p wsha coyo --model gpt-5.4 "$git-up -p"
EOF
}

write_wsha_block_bash_config() {
    local file_path="$1"
    cat > "$file_path" <<'EOF'
"bhello * *" """bash
echo block-[[1]]-[[2]]
"""

"shello *" """sh
echo sh-block-[[1]]
"""

"bbase" """bash
echo block-base
"""

"brest **" """bash
echo rest-[[...]]
"""

"bempty" """bash

"""
EOF
}

write_wsha_block_embedded_dstar_config() {
    local file_path="$1"
    cat > "$file_path" <<'EOF'
"b**" """bash
echo rest-[[...]]
"""
EOF
}

write_wsha_block_onlyrest_config() {
    local file_path="$1"
    cat > "$file_path" <<'EOF'
"onlyrest **" """bash
echo rest-[[...]]
"""
EOF
}

write_wsha_block_unclosed_config() {
    local file_path="$1"
    cat > "$file_path" <<'EOF'
"broken" """bash
echo never-closed
EOF
}

write_wsha_multiple_double_star_config() {
    local file_path="$1"
    cat > "$file_path" <<'EOF'
"multi ** **" echo should-not-match
EOF
}

write_wsha_block_invalid_runner_config() {
    local file_path="$1"
    cat > "$file_path" <<'EOF'
"bad" """python
echo bad
"""
EOF
}

write_wsha_prefix_alias_config() {
    local file_path="$1"
    cat > "$file_path" <<'EOF'
&seq echo sequential-prefix
|fallback echo or-prefix
EOF
}

write_wsha_block_windows_runners_config() {
    local file_path="$1"
    cat > "$file_path" <<'EOF'
"bcmd" """cmd
echo cmd-ok
"""
"bbat" """bat
echo bat-ok
"""
"bpwsh" """pwsh
Write-Output pwsh-ok
"""
"bpowershell" """powershell
Write-Output powershell-ok
"""
EOF
}

write_wsha_table_list_config() {
    local file_path="$1"
    cat > "$file_path" <<'EOF'
zeta echo zeta-command
alpha echo alpha-command with a very very very long argument tail
"px *" echo pnpx $1
"bbuild" """bash
echo build
"""
EOF
}

write_wsha_env_vars_config() {
    local file_path="$1"
    cat > "$file_path" <<'EOF'
show-home echo %APP_HOME%
show-sh echo %APP_SH%
show-config echo %APP_CONFIG%
EOF
}

write_wsha_tping_config() {
    local file_path="$1"
    cat > "$file_path" <<'EOF'
"tping -qq" wsh %APP_SH%/core/tping.sh qq.com 443
EOF
}

# 调用 wsha 并回收输出与退出码
run_wsha() {
    local config_file="$1"
    shift

    raw_output=$(WSHA_CONFIG_FILE="$config_file" WSHA_TEST_TIME_LABEL="1" bash "$SCRIPT_TO_TEST" "$@" 2>&1)
    run_code=$?
    raw_output=$(printf "%s" "$raw_output" | tr -d '\r')
    output=$(strip_time_logs "$raw_output")
}

# 只调用 Python core 取得展开命令，不执行最终命令。
run_wsha_core() {
    local config_file="$1"
    shift

    raw_output=$(WSHA_CONFIG_FILE="$config_file" WSHA_TEST_TIME_LABEL="1" python "$PROJECT_ROOT/sh/core/wsha_core.py" -e w "$@" 2>&1)
    run_code=$?
    raw_output=$(printf "%s" "$raw_output" | tr -d '\r')
    output=$(strip_time_logs "$raw_output")
}

# 以 sh 输出协议调用 Python core，适合验证 block runner 生成的命令文本。
capture_wsha_core_sh_output() {
    local config_file="$1"
    shift

    APP_HOME="$PROJECT_ROOT" APP_SH="$PROJECT_ROOT/sh" APP_CONFIG="$PROJECT_ROOT/sh/config" WSHA_CONFIG_FILE="$config_file" WSHA_CMDLINE_OUTPUT=sh python "$PROJECT_ROOT/sh/core/wsha_core.py" "$@" 2>&1
}

# 以 cmd 输出协议调用 Python core，适合验证 Windows batch 入口执行字符串。
capture_wsha_core_cmd_output() {
    local config_file="$1"
    shift

    APP_HOME="$PROJECT_ROOT" APP_SH="$PROJECT_ROOT/sh" APP_CONFIG="$PROJECT_ROOT/sh/config" WSHA_CONFIG_FILE="$config_file" WSHA_CMDLINE_OUTPUT=cmd python "$PROJECT_ROOT/sh/core/wsha_core.py" -e w "$@" 2>&1
}

# 调用 wsha 的 -lv/--list-view，并在测试模式下将弹窗输出转为文本。
run_wsha_list_view() {
    local config_file="$1"
    shift

    raw_output=$(WSHA_CONFIG_FILE="$config_file" WSHA_TEST_GRID_CAPTURE="1" WSHA_TEST_TIME_LABEL="1" bash "$SCRIPT_TO_TEST" "$@" 2>&1)
    run_code=$?
    raw_output=$(printf "%s" "$raw_output" | tr -d '\r')
    output=$(strip_time_logs "$raw_output")
}

# 调用 wsha 的 TTY 表格列表分支，测试中通过环境变量模拟交互终端。
run_wsha_table_list() {
    local config_file="$1"
    shift

    raw_output=$(WSHA_CONFIG_FILE="$config_file" WSHA_FORCE_TABLE_LIST="1" WSHA_TABLE_WIDTH="58" WSHA_TEST_TIME_LABEL="1" bash "$SCRIPT_TO_TEST" "$@" 2>&1)
    run_code=$?
    raw_output=$(printf "%s" "$raw_output" | tr -d '\r')
    output=$(strip_time_logs "$raw_output")
}

# 调用 wsha 默认多配置合并模式（不传 WSHA_CONFIG_FILE）。
run_wsha_default() {
    local work_dir="$1"
    local user_home_dir="$2"
    shift 2

    raw_output=$(cd "$work_dir" && HOME="$user_home_dir" WSHA_TEST_TIME_LABEL="1" bash "$SCRIPT_TO_TEST" "$@" 2>&1)
    run_code=$?
    raw_output=$(printf "%s" "$raw_output" | tr -d '\r')
    output=$(strip_time_logs "$raw_output")
}

# 指定 HOME 调用 wsha，用于验证 cache 等 home-scoped 行为。
run_wsha_with_home() {
    local home_dir="$1"
    local config_file="$2"
    shift 2

    raw_output=$(HOME="$home_dir" WSHA_CONFIG_FILE="$config_file" WSHA_TEST_TIME_LABEL="1" bash "$SCRIPT_TO_TEST" "$@" 2>&1)
    run_code=$?
    raw_output=$(printf "%s" "$raw_output" | tr -d '\r')
    output=$(strip_time_logs "$raw_output")
}

# 指定 HOME 并关闭 block cache 调用 wsha。
run_wsha_with_home_no_block_cache() {
    local home_dir="$1"
    local config_file="$2"
    shift 2

    raw_output=$(HOME="$home_dir" WSHA_CONFIG_FILE="$config_file" WSHA_BLOCK_NO_CACHE="1" WSHA_TEST_TIME_LABEL="1" bash "$SCRIPT_TO_TEST" "$@" 2>&1)
    run_code=$?
    raw_output=$(printf "%s" "$raw_output" | tr -d '\r')
    output=$(strip_time_logs "$raw_output")
}

# 清理测试输出中的耗时日志和颜色控制符，便于断言业务内容。
strip_time_logs() {
    printf "%s" "$1" | awk '
        BEGIN {
            esc = sprintf("%c", 27)
        }
        {
            gsub(esc "\\[[0-9;]*[A-Za-z]", "")
            if ($0 ~ /^\[wsha\]\[time\] /) next
            print
        }
    '
}

# 生成默认模式下的用户级与工作目录级配置。
write_wsha_default_merge_configs() {
    local user_home_dir="$1"
    local work_dir="$2"

    mkdir -p "$user_home_dir/.config/wsh-alias"
    mkdir -p "$work_dir/.config/wsh-alias"

    cat > "$user_home_dir/.config/wsh-alias/default.txt" <<'EOF'
ab echo user-ab
foo echo user-foo
EOF

    cat > "$work_dir/.config/wsh-alias/default.txt" <<'EOF'
ab echo local-ab
bar echo local-bar
EOF
}
