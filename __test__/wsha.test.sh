#!/bin/bash

source "$(dirname "$0")/test_utils.sh"

BASE_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$BASE_DIR/.." && pwd)
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

# 生成测试配置文件
write_config() {
    local file_path="$1"
    local mode="$2"

    if [[ "$mode" == "normal" ]]; then
        cat > "$file_path" <<'EOF'
ab echo agent-browser
foo echo foobar open

# 注释行会被忽略
bar echo barbar $@ --name ccwq
EOF
    elif [[ "$mode" == "duplicate" ]]; then
        cat > "$file_path" <<'EOF'
ab echo first
ab echo second
EOF
    elif [[ "$mode" == "invalid" ]]; then
        cat > "$file_path" <<'EOF'
ab
EOF
    elif [[ "$mode" == "quoted_wildcard" ]]; then
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
    elif [[ "$mode" == "super_rule" ]]; then
        cat > "$file_path" <<'EOF'
"grcmd * *" $1 | findstr $2
EOF
    elif [[ "$mode" == "argv_quote" ]]; then
        cat > "$file_path" <<'EOF'
codex-l echo codex $@
codex-yo wsha codex-l --yolo $@
coyo wsha codex-yo
EOF
    elif [[ "$mode" == "block_bash" ]]; then
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
    elif [[ "$mode" == "block_invalid_runner" ]]; then
        cat > "$file_path" <<'EOF'
"bad" """python
echo bad
"""
EOF
    elif [[ "$mode" == "env_vars" ]]; then
        cat > "$file_path" <<'EOF'
show-home echo %APP_HOME%
show-sh echo %APP_SH%
show-config echo %APP_CONFIG%
EOF
    fi
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

# 调用 wsha 的 -lv/--list-view，并在测试模式下将弹窗输出转为文本
run_wsha_list_view() {
    local config_file="$1"
    shift

    raw_output=$(WSHA_CONFIG_FILE="$config_file" WSHA_TEST_GRID_CAPTURE="1" WSHA_TEST_TIME_LABEL="1" bash "$SCRIPT_TO_TEST" "$@" 2>&1)
    run_code=$?
    raw_output=$(printf "%s" "$raw_output" | tr -d '\r')
    output=$(strip_time_logs "$raw_output")
}

# 调用 wsha 默认多配置合并模式（不传 WSHA_CONFIG_FILE）
run_wsha_default() {
    local work_dir="$1"
    local user_home_dir="$2"
    shift 2

    raw_output=$(cd "$work_dir" && HOME="$user_home_dir" WSHA_TEST_TIME_LABEL="1" bash "$SCRIPT_TO_TEST" "$@" 2>&1)
    run_code=$?
    raw_output=$(printf "%s" "$raw_output" | tr -d '\r')
    output=$(strip_time_logs "$raw_output")
}

# 清理测试输出中的耗时日志和颜色控制符，便于断言业务内容
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

# 生成默认模式下的用户级与工作目录级配置
write_default_merge_configs() {
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

test_expand_ab() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-normal.txt"
    write_config "$config_file" "normal"

    run_wsha "$config_file" ab open
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -eq 0 ]] && [[ "$clean_output" == *"agent-browser open"* ]]; then
        result="PASS"
        log_success "ab 展开测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_expand_ab" "$result" "$duration" "$note"
}

test_expand_foo_append() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-normal.txt"
    write_config "$config_file" "normal"

    run_wsha "$config_file" foo --ping
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -eq 0 ]] && [[ "$clean_output" == *"foobar open --ping"* ]]; then
        result="PASS"
        log_success "foo 参数追加测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_expand_foo_append" "$result" "$duration" "$note"
}

test_expand_bar_placeholder() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-normal.txt"
    write_config "$config_file" "normal"

    run_wsha "$config_file" bar --age 40
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -eq 0 ]] && [[ "$clean_output" == *"barbar --age 40 --name ccwq"* ]]; then
        result="PASS"
        log_success "bar 占位符插入测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_expand_bar_placeholder" "$result" "$duration" "$note"
}

test_unknown_alias_passthrough_with_args() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-normal.txt"
    write_config "$config_file" "normal"

    run_wsha "$config_file" echo hello
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -eq 0 ]] && [[ "$clean_output" == *"hello"* ]]; then
        result="PASS"
        log_success "未知 alias 透传参数执行测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_unknown_alias_passthrough_with_args" "$result" "$duration" "$note"
}

test_unknown_alias_ping_passthrough() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-normal.txt"
    write_config "$config_file" "normal"

    run_wsha "$config_file" ping t.cn -n 1
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ "$clean_output" != *"'t.cn' is not recognized"* ]] && [[ "$clean_output" != *"'ping' is not recognized"* ]] && [[ "$clean_output" == *"t.cn"* ]]; then
        result="PASS"
        log_success "未知 alias 的 ping 透传测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_unknown_alias_ping_passthrough" "$result" "$duration" "$note"
}

test_quoted_alias_expand() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-normal.txt"
    write_config "$config_file" "normal"

    run_wsha "$config_file" "ab open t.cn"
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -eq 0 ]] && [[ "$clean_output" == *"agent-browser open t.cn"* ]]; then
        result="PASS"
        log_success "引号包裹 alias 展开测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_quoted_alias_expand" "$result" "$duration" "$note"
}

test_quoted_complex_command_passthrough() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-normal.txt"
    write_config "$config_file" "normal"

    run_wsha "$config_file" "echo foo | grep foo"
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -eq 0 ]] && [[ "$clean_output" == *"foo"* ]]; then
        result="PASS"
        log_success "引号复杂命令透传测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_quoted_complex_command_passthrough" "$result" "$duration" "$note"
}

test_quoted_and_chain_passthrough() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-normal.txt"
    write_config "$config_file" "normal"

    run_wsha "$config_file" "echo a && echo b"
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -eq 0 ]] && [[ "$clean_output" == *"a"* ]] && [[ "$clean_output" == *"b"* ]]; then
        result="PASS"
        log_success "引号与链式命令透传测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_quoted_and_chain_passthrough" "$result" "$duration" "$note"
}

test_unknown_command_passthrough_error_code() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-normal.txt"
    write_config "$config_file" "normal"

    run_wsha "$config_file" not_exist_cmd_12345
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -ne 0 ]] && [[ "$clean_output" == *"not found"* || "$clean_output" == *"not recognized"* ]]; then
        result="PASS"
        log_success "未知命令透传错误码测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_unknown_command_passthrough_error_code" "$result" "$duration" "$note"
}

test_list_long_flag() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-normal.txt"
    write_config "$config_file" "normal"

    run_wsha "$config_file" --list
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -eq 0 ]] \
        && [[ "$clean_output" == *"别名"* ]] \
        && [[ "$clean_output" == *"命令"* ]] \
        && [[ "$clean_output" == *"[自定义]"* ]] \
        && [[ "$clean_output" == *"alias-normal.txt"* ]] \
        && [[ "$clean_output" == *"ab"* ]] \
        && [[ "$clean_output" == *"echo agent-browser"* ]] \
        && [[ "$clean_output" == *"foo"* ]] \
        && [[ "$clean_output" == *"echo foobar open"* ]] \
        && [[ "$clean_output" == *"bar"* ]] \
        && [[ "$clean_output" == *"echo barbar \$@ --name ccwq"* ]]; then
        result="PASS"
        log_success "--list 表格输出测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_list_long_flag" "$result" "$duration" "$note"
}

test_list_short_flag() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-normal.txt"
    write_config "$config_file" "normal"

    run_wsha "$config_file" -l
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -eq 0 ]] \
        && [[ "$clean_output" == *"[自定义]"* ]] \
        && [[ "$clean_output" == *"alias-normal.txt"* ]] \
        && [[ "$clean_output" == *"ab"* ]] \
        && [[ "$clean_output" == *"echo agent-browser"* ]] \
        && [[ "$clean_output" == *"bar"* ]]; then
        result="PASS"
        log_success "-l 表格输出测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_list_short_flag" "$result" "$duration" "$note"
}

test_list_view_flag() {
    local start_time end_time duration result note config_file config_win
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-normal.txt"
    write_config "$config_file" "normal"
    config_win=$(cygpath -u "$config_file")

    run_wsha_list_view "$config_file" -lv
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -eq 0 ]] \
        && [[ "$clean_output" == *"[自定义]"* ]] \
        && [[ "$clean_output" == *"alias-normal.txt"* ]] \
        && [[ "$clean_output" == *"ab"* ]] \
        && [[ "$clean_output" == *"echo agent-browser"* ]]; then
        result="PASS"
        log_success "-lv 视图输出测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_list_view_flag" "$result" "$duration" "$note"
}

test_duplicate_alias() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-dup.txt"
    write_config "$config_file" "duplicate"

    run_wsha "$config_file" ab run
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -ne 0 ]] && [[ "$clean_output" == *"duplicate alias"* ]]; then
        result="PASS"
        log_success "重复 alias 检测测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_duplicate_alias" "$result" "$duration" "$note"
}

test_invalid_mapping() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-invalid.txt"
    write_config "$config_file" "invalid"

    run_wsha "$config_file" ab run
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -ne 0 ]] && [[ "$clean_output" == *"invalid config"* ]]; then
        result="PASS"
        log_success "非法配置检测测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_invalid_mapping" "$result" "$duration" "$note"
}

test_default_merge_priority() {
    local start_time end_time duration result note user_home_dir work_dir
    start_time=$(current_time)
    result="FAIL"
    note=""

    user_home_dir="$TEST_DIR/default-home"
    work_dir="$TEST_DIR/default-work"
    mkdir -p "$user_home_dir" "$work_dir"
    write_default_merge_configs "$user_home_dir" "$work_dir"

    run_wsha_default "$work_dir" "$user_home_dir" ab run
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -ne 0 ]] || [[ "$clean_output" != *"local-ab run"* ]]; then
        note="ab 覆盖失败 output=[$clean_output], code=$run_code"
        log_fail "$note"
        end_time=$(current_time)
        duration=$(calc_duration "$start_time" "$end_time")
        record_test_result "test_default_merge_priority" "$result" "$duration" "$note"
        return
    fi

    run_wsha_default "$work_dir" "$user_home_dir" foo ping
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -ne 0 ]] || [[ "$clean_output" != *"user-foo ping"* ]]; then
        note="foo 覆盖失败 output=[$clean_output], code=$run_code"
        log_fail "$note"
        end_time=$(current_time)
        duration=$(calc_duration "$start_time" "$end_time")
        record_test_result "test_default_merge_priority" "$result" "$duration" "$note"
        return
    fi

    result="PASS"
    log_success "默认多配置优先级合并测试通过"

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_default_merge_priority" "$result" "$duration" "$note"
}

test_default_missing_optional_configs_ignored() {
    local start_time end_time duration result note user_home_dir work_dir
    start_time=$(current_time)
    result="FAIL"
    note=""

    user_home_dir="$TEST_DIR/no-config-home"
    work_dir="$TEST_DIR/no-config-work"
    mkdir -p "$user_home_dir" "$work_dir"

    run_wsha_default "$work_dir" "$user_home_dir" echo hello-default
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -eq 0 ]] && [[ "$clean_output" == *"hello-default"* ]] && [[ "$clean_output" != *"config file not found"* ]]; then
        result="PASS"
        log_success "缺失可选配置忽略测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_default_missing_optional_configs_ignored" "$result" "$duration" "$note"
}

test_default_list_merged_aliases() {
    local start_time end_time duration result note user_home_dir work_dir builtin_win user_win local_win
    start_time=$(current_time)
    result="FAIL"
    note=""

    user_home_dir="$TEST_DIR/list-home"
    work_dir="$TEST_DIR/list-work"
    mkdir -p "$user_home_dir" "$work_dir"
    write_default_merge_configs "$user_home_dir" "$work_dir"
    builtin_win=$(cygpath -u "$PROJECT_ROOT/sh/config/wsh-alias")
    user_win=$(cygpath -u "$user_home_dir/.config/wsh-alias")
    local_win=$(cygpath -u "$work_dir/.config/wsh-alias")

    run_wsha_default "$work_dir" "$user_home_dir" --list
    if [[ $run_code -eq 0 ]] \
        && [[ "$output" == *"[内置] $builtin_win"* ]] \
        && [[ "$output" == *"[用户] $user_win"* ]] \
        && [[ "$output" == *"[项目] $local_win"* ]] \
        && [[ "$output" == *"ab"* ]] \
        && [[ "$output" == *"echo local-ab"* ]] \
        && [[ "$output" == *"foo"* ]] \
        && [[ "$output" == *"echo user-foo"* ]] \
        && [[ "$output" == *"bar"* ]]; then
        result="PASS"
        log_success "默认 --list 来源表格输出测试通过"
    else
        note="output=[$output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_default_list_merged_aliases" "$result" "$duration" "$note"
}

test_quoted_alias_with_space() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-quoted-wildcard.txt"
    write_config "$config_file" "quoted_wildcard"

    run_wsha "$config_file" pcodex
    if [[ $run_code -ne 0 ]] || [[ "$output" != *"codex-default"* ]]; then
        note="pcodex 未命中默认别名 output=[$output], code=$run_code"
        log_fail "$note"
        end_time=$(current_time)
        duration=$(calc_duration "$start_time" "$end_time")
        record_test_result "test_quoted_alias_with_space" "$result" "$duration" "$note"
        return
    fi

    run_wsha "$config_file" pcodex l
    if [[ $run_code -eq 0 ]] && [[ "$output" == *"codex-last"* ]]; then
        result="PASS"
        log_success "引号包裹空格 alias 测试通过"
    else
        note="pcodex l 未命中空格别名 output=[$output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_quoted_alias_with_space" "$result" "$duration" "$note"
}

test_wildcard_single_token_alias() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-quoted-wildcard.txt"
    write_config "$config_file" "quoted_wildcard"

    run_wsha "$config_file" pxhttp-server
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -eq 0 ]] && [[ "$clean_output" == *"pnpx http-server"* ]]; then
        result="PASS"
        log_success "单段通配符 alias 测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_wildcard_single_token_alias" "$result" "$duration" "$note"
}

test_wildcard_multi_token_alias() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-quoted-wildcard.txt"
    write_config "$config_file" "quoted_wildcard"

    run_wsha "$config_file" px http-server
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -eq 0 ]] && [[ "$clean_output" == *"pnpx http-server"* ]]; then
        result="PASS"
        log_success "多段 alias 通配符测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_wildcard_multi_token_alias" "$result" "$duration" "$note"
}

test_quoted_content_equivalence() {
    local start_time end_time duration result note config_file out_q1 out_q2
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-quoted-wildcard.txt"
    write_config "$config_file" "quoted_wildcard"

    run_wsha "$config_file" q1 http-server
    out_q1=$(strip_time_logs "$output")
    if [[ $run_code -ne 0 ]]; then
        note="q1 执行失败 output=[$out_q1], code=$run_code"
        log_fail "$note"
        end_time=$(current_time)
        duration=$(calc_duration "$start_time" "$end_time")
        record_test_result "test_quoted_content_equivalence" "$result" "$duration" "$note"
        return
    fi

    run_wsha "$config_file" q2 http-server
    out_q2=$(strip_time_logs "$output")
    if [[ $run_code -eq 0 ]] \
        && [[ "$out_q1" == *"[wsha] alias hit:"* ]] \
        && [[ "$out_q2" == *"[wsha] alias hit:"* ]] \
        && [[ "$out_q1" == *"pnpx http-server"* ]] \
        && [[ "$out_q2" == *"pnpx http-server"* ]]; then
        result="PASS"
        log_success "模板引号等价测试通过"
    else
        note="q1=[$out_q1], q2=[$out_q2], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_quoted_content_equivalence" "$result" "$duration" "$note"
}

test_double_star_capture() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-quoted-wildcard.txt"
    write_config "$config_file" "quoted_wildcard"

    run_wsha "$config_file" sls -l
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -eq 0 ]] && [[ "$clean_output" == *"wsh ls -l"* ]]; then
        result="PASS"
        log_success "双星号剩余参数捕获测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_double_star_capture" "$result" "$duration" "$note"
}

test_wildcard_multi_capture() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-quoted-wildcard.txt"
    write_config "$config_file" "quoted_wildcard"

    run_wsha "$config_file" tool alpha beta
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -eq 0 ]] && [[ "$clean_output" == *"alpha::beta"* ]]; then
        result="PASS"
        log_success "多捕获组替换测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_wildcard_multi_capture" "$result" "$duration" "$note"
}

# Given：配置中存在 coyo -> codex-yo -> codex-l 的递归 alias 链，codex-yo 使用 $@ 插入运行时参数。
# When：执行 w coyo --model gpt-5.4 "git-up -p"。
# Then：应在 core 内递归展开，保留带空格 prompt，并把 --yolo 放在 $@ 所在位置。
# 防回归：防止带空格 prompt 经多层 wsha/batch 重入后触发 quote 崩溃或参数顺序错乱。
test_recursive_alias_quoted_prompt_with_dollar_at() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-argv-quote.txt"
    write_config "$config_file" "argv_quote"

    run_wsha "$config_file" coyo --model gpt-5.4 "git-up -p"
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -eq 0 ]] \
        && [[ "$clean_output" == *"codex --yolo --model gpt-5.4 'git-up -p'"* ]]; then
        result="PASS"
        log_success "递归 alias 带空格 prompt 展开测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_recursive_alias_quoted_prompt_with_dollar_at" "$result" "$duration" "$note"
}

# Given：配置中存在同一条递归 alias 链，用户 prompt 文本自身以 $ 开头。
# When：执行 w coyo --model gpt-5.4 '$git-up -p'。
# Then：应把 $git-up -p 当作普通目标参数保留，不在 wsha 模板层展开变量。
# 防回归：防止用户想传给 Codex/Claude 的渐进式选项式提示被 wsha 当 shell 变量吞掉。
test_recursive_alias_dollar_prompt_is_literal() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-argv-quote.txt"
    write_config "$config_file" "argv_quote"

    run_wsha "$config_file" coyo --model gpt-5.4 '$git-up -p'
    local clean_output
    clean_output=$(strip_time_logs "$output")
    local expected_fragment="codex --yolo --model gpt-5.4 '\$git-up -p'"
    if [[ $run_code -eq 0 ]] \
        && [[ "$clean_output" == *"$expected_fragment"* ]]; then
        result="PASS"
        log_success "递归 alias dollar prompt 字面量测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_recursive_alias_dollar_prompt_is_literal" "$result" "$duration" "$note"
}

# Given：配置中存在 "grcmd * *" $1 | findstr $2 规则，首个捕获是原命令，第二个捕获是筛选关键字。
# When：执行 w grcmd tasklist chrome。
# Then：应展开为 tasklist | findstr chrome，并保持 0 退出码。
# 防回归：防止 super rule 在两个普通通配符场景下把 $1 / $2 替换错位。
test_super_rule_plain_tokens() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-super-rule.txt"
    write_config "$config_file" "super_rule"

    run_wsha "$config_file" grcmd tasklist chrome
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -eq 0 ]] && [[ "$clean_output" == *"tasklist | findstr chrome"* ]]; then
        result="PASS"
        log_success "super rule 普通参数展开测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_super_rule_plain_tokens" "$result" "$duration" "$note"
}

# Given：配置中存在 "grcmd * *" $1 | findstr $2 规则，并且首个捕获可能是带空格与通配符的整体参数。
# When：执行 w grcmd "tasklist /M chrome*" web。
# Then：应展开为 tasklist /M chrome* | findstr web，并保持 0 退出码。
# 防回归：防止带引号内容在 token 化后被拆散，导致管道前半段或筛选关键字展开异常。
test_super_rule_quoted_command() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-super-rule.txt"
    write_config "$config_file" "super_rule"

    run_wsha "$config_file" grcmd "tasklist /M chrome*" web
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ "$clean_output" == *"tasklist /M chrome* | findstr web"* ]]; then
        result="PASS"
        log_success "super rule 引号命令展开测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_super_rule_quoted_command" "$result" "$duration" "$note"
}

# Given：配置中存在 bash block alias，并使用 [[1]] 捕获用户参数。
# When：执行 w bhello Alice。
# Then：应生成并执行 bash block，输出 block-Alice。
# 防回归：防止 block 模板被单行 token 化破坏换行和捕获替换。
test_block_bash_capture_placeholder() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-block-bash.txt"
    write_config "$config_file" "block_bash"

    run_wsha "$config_file" bhello Alice Bob
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -eq 0 ]] && [[ "$clean_output" == *"block-Alice-Bob"* ]]; then
        result="PASS"
        log_success "bash block 捕获占位符测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_block_bash_capture_placeholder" "$result" "$duration" "$note"
}

# Given：配置中存在 sh block alias，并使用 [[1]] 捕获用户参数。
# When：执行 w shello World。
# Then：应生成并执行 sh block，输出 sh-block-World。
# 防回归：防止 runner sh 没有纳入 block 执行矩阵。
test_block_sh_runner() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-block-bash.txt"
    write_config "$config_file" "block_bash"

    run_wsha "$config_file" shello World
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -eq 0 ]] && [[ "$clean_output" == *"sh-block-World"* ]]; then
        result="PASS"
        log_success "sh block runner 测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_block_sh_runner" "$result" "$duration" "$note"
}

# Given：core 以 sh 输出协议展开 cmd/bat/pwsh/powershell block。
# When：分别请求四种 runner 的 alias 展开。
# Then：输出命令应包含对应 runner 和脚本路径，不应丢失反斜杠导致 Bash 吞路径。
# 防回归：防止非 bash block 在 Git Bash wrapper 下生成不可执行命令。
test_block_windows_runner_command_generation() {
    local start_time end_time duration result note config_file core_path out_cmd out_bat out_pwsh out_powershell
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-block-windows-runners.txt"
    core_path="$PROJECT_ROOT/sh/core/wsha_core.py"
    cat > "$config_file" <<'EOF'
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

    out_cmd=$(WSHA_CONFIG_FILE="$config_file" WSHA_CMDLINE_OUTPUT=sh python "$core_path" bcmd 2>&1)
    out_bat=$(WSHA_CONFIG_FILE="$config_file" WSHA_CMDLINE_OUTPUT=sh python "$core_path" bbat 2>&1)
    out_pwsh=$(WSHA_CONFIG_FILE="$config_file" WSHA_CMDLINE_OUTPUT=sh python "$core_path" bpwsh 2>&1 || true)
    out_powershell=$(WSHA_CONFIG_FILE="$config_file" WSHA_CMDLINE_OUTPUT=sh python "$core_path" bpowershell 2>&1 || true)

    if [[ "$out_cmd" == *"/c"* ]] \
        && [[ "$out_cmd" == *".cmd"* ]] \
        && [[ "$out_bat" == *"/c"* ]] \
        && [[ "$out_bat" == *".cmd"* ]] \
        && { [[ "$out_pwsh" == *"-File"* && "$out_pwsh" == *".ps1"* ]] || [[ "$out_pwsh" == *"runner \"pwsh\" not found"* ]]; } \
        && { [[ "$out_powershell" == *"-File"* && "$out_powershell" == *".ps1"* ]] || [[ "$out_powershell" == *"runner \"powershell\" not found"* ]]; }; then
        result="PASS"
        log_success "Windows block runner 命令生成测试通过"
    else
        note="cmd=[$out_cmd], bat=[$out_bat], pwsh=[$out_pwsh], powershell=[$out_powershell]"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_block_windows_runner_command_generation" "$result" "$duration" "$note"
}

# Given：配置中只存在 token 内嵌 ** 的 alias，且 ** 捕获要求非空。
# When：执行 w b 且 b** 的剩余捕获为空。
# Then：应在最终无 alias 命中时提示 ** 需要非空捕获。
# 防回归：防止 b** / prefix**suffix 这类内嵌 ** 空捕获静默透传。
test_block_embedded_double_star_empty_warn() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-block-embedded-dstar.txt"
    cat > "$config_file" <<'EOF'
"b**" """bash
echo rest-[[...]]
"""
EOF

    run_wsha "$config_file" b
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ "$clean_output" == *"warning: alias \"b**\" requires non-empty ** capture"* ]]; then
        result="PASS"
        log_success "内嵌双星号空捕获 warning 测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_block_embedded_double_star_empty_warn" "$result" "$duration" "$note"
}

# Given：配置中存在不消费额外参数的 bash block alias。
# When：执行 w bbase ignored-arg。
# Then：应输出橙色 warning 的纯文本内容并忽略额外参数，仍执行原 block。
# 防回归：防止 block alias 像单行 alias 一样自动追加 runtime args。
test_block_extra_args_warn_and_ignore() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-block-bash.txt"
    write_config "$config_file" "block_bash"

    run_wsha "$config_file" bbase ignored-arg
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -eq 0 ]] \
        && [[ "$clean_output" == *"warning: block alias \"bbase\" ignores extra args: ignored-arg"* ]] \
        && [[ "$clean_output" == *"block-base"* ]] \
        && [[ "$clean_output" != *"block-base ignored-arg"* ]]; then
        result="PASS"
        log_success "bash block 额外参数 warning 并忽略测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_block_extra_args_warn_and_ignore" "$result" "$duration" "$note"
}

# Given：配置中只存在 ** block alias，且 ** 捕获要求非空。
# When：执行 w onlyrest 且没有提供剩余参数。
# Then：应在最终无 alias 命中时提示 ** 需要非空捕获。
# 防回归：防止 ** 空捕获静默匹配导致生成无效脚本。
test_block_double_star_requires_non_empty_warn() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-block-bash.txt"
    cat > "$config_file" <<'EOF'
"onlyrest **" """bash
echo rest-[[...]]
"""
EOF

    run_wsha "$config_file" onlyrest
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ "$clean_output" == *"warning: alias \"onlyrest **\" requires non-empty ** capture"* ]]; then
        result="PASS"
        log_success "双星号空捕获 warning 测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_block_double_star_requires_non_empty_warn" "$result" "$duration" "$note"
}

# Given：配置中存在空 bash block alias。
# When：执行 w bempty。
# Then：应 warning 并以 no-op 成功返回。
# 防回归：允许默认配置中的占位 block 渐进编辑而不破坏加载。
test_block_empty_warn_noop() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-block-bash.txt"
    write_config "$config_file" "block_bash"

    run_wsha "$config_file" bempty
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -eq 0 ]] && [[ "$clean_output" == *"warning: block alias \"bempty\" is empty; nothing to execute"* ]]; then
        result="PASS"
        log_success "空 block warning no-op 测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_block_empty_warn_noop" "$result" "$duration" "$note"
}

# Given：列表中包含 bash block alias。
# When：执行 w --list。
# Then：命令列只显示 <bash block: N lines> 摘要，不展开完整脚本内容。
# 防回归：防止多行 block 撑坏列表表格。
test_block_list_summary() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-block-bash.txt"
    write_config "$config_file" "block_bash"

    run_wsha "$config_file" --list
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -eq 0 ]] \
        && [[ "$clean_output" == *"<bash block: 1 line>"* ]] \
        && [[ "$clean_output" == *"<bash block: empty>"* ]] \
        && [[ "$clean_output" != *"echo block-[[1]]"* ]]; then
        result="PASS"
        log_success "block list 摘要测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_block_list_summary" "$result" "$duration" "$note"
}

# Given：配置中存在未知 runner 的 block alias。
# When：加载配置并执行该 alias。
# Then：应配置加载失败并报告 invalid block runner。
# 防回归：防止拼错 runner 后降级为不可预期的普通命令。
test_block_invalid_runner_fails() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-block-invalid-runner.txt"
    write_config "$config_file" "block_invalid_runner"

    run_wsha "$config_file" bad
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -ne 0 ]] && [[ "$clean_output" == *"invalid block runner \"python\""* ]]; then
        result="PASS"
        log_success "非法 block runner 失败测试通过"
    else
        note="output=[$clean_output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_block_invalid_runner_fails" "$result" "$duration" "$note"
}

# Given：block alias 执行后会在 ~/.cache/wsha/blocks 生成脚本缓存。
# When：执行 w --cache-clear。
# Then：应清理 alias cache 和 block cache。
# 防回归：防止 block cache 在清理命令后残留。
test_block_cache_clear() {
    local start_time end_time duration result note config_file cache_home
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-block-bash.txt"
    cache_home="$TEST_DIR/block-cache-home"
    write_config "$config_file" "block_bash"

    raw_output=$(HOME="$cache_home" WSHA_CONFIG_FILE="$config_file" WSHA_TEST_TIME_LABEL="1" bash "$SCRIPT_TO_TEST" bhello Cache Hit 2>&1)
    run_code=$?
    raw_output=$(printf "%s" "$raw_output" | tr -d '\r')
    output=$(strip_time_logs "$raw_output")
    if [[ $run_code -ne 0 ]] || [[ ! -d "$cache_home/.cache/wsha/blocks" ]]; then
        note="block cache 未生成 output=[$output], code=$run_code"
        log_fail "$note"
        end_time=$(current_time)
        duration=$(calc_duration "$start_time" "$end_time")
        record_test_result "test_block_cache_clear" "$result" "$duration" "$note"
        return
    fi

    raw_output=$(HOME="$cache_home" WSHA_CONFIG_FILE="$config_file" WSHA_TEST_TIME_LABEL="1" bash "$SCRIPT_TO_TEST" --cache-clear 2>&1)
    run_code=$?
    raw_output=$(printf "%s" "$raw_output" | tr -d '\r')
    output=$(strip_time_logs "$raw_output")
    if [[ $run_code -eq 0 ]] && [[ ! -d "$cache_home/.cache/wsha/blocks" || -z "$(ls -A "$cache_home/.cache/wsha/blocks" 2>/dev/null)" ]]; then
        result="PASS"
        log_success "block cache 清理测试通过"
    else
        note="output=[$output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_block_cache_clear" "$result" "$duration" "$note"
}

test_builtin_env_vars() {
    local start_time end_time duration result note config_file expected_home expected_sh expected_config
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-env-vars.txt"
    write_config "$config_file" "env_vars"
    expected_home=$(cygpath -u "$PROJECT_ROOT")
    expected_sh=$(cygpath -u "$PROJECT_ROOT/sh")
    expected_config=$(cygpath -u "$PROJECT_ROOT/sh/config")

    run_wsha "$config_file" show-home
    local clean_output
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -ne 0 ]] || [[ "$clean_output" != *"$expected_home"* ]]; then
        note="APP_HOME 注入失败 output=[$clean_output], expected=[$expected_home], code=$run_code"
        log_fail "$note"
        end_time=$(current_time)
        duration=$(calc_duration "$start_time" "$end_time")
        record_test_result "test_builtin_env_vars" "$result" "$duration" "$note"
        return
    fi

    run_wsha "$config_file" show-sh
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -ne 0 ]] || [[ "$clean_output" != *"$expected_sh"* ]]; then
        note="APP_SH 注入失败 output=[$clean_output], expected=[$expected_sh], code=$run_code"
        log_fail "$note"
        end_time=$(current_time)
        duration=$(calc_duration "$start_time" "$end_time")
        record_test_result "test_builtin_env_vars" "$result" "$duration" "$note"
        return
    fi

    run_wsha "$config_file" show-config
    clean_output=$(strip_time_logs "$output")
    if [[ $run_code -eq 0 ]] && [[ "$clean_output" == *"$expected_config"* ]]; then
        result="PASS"
        log_success "内置环境变量注入测试通过"
    else
        note="APP_CONFIG 注入失败 output=[$clean_output], expected=[$expected_config], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_builtin_env_vars" "$result" "$duration" "$note"
}

main() {
    setup

    test_expand_ab
    test_expand_foo_append
    test_expand_bar_placeholder
    test_unknown_alias_passthrough_with_args
    test_unknown_alias_ping_passthrough
    test_quoted_alias_expand
    test_quoted_complex_command_passthrough
    test_quoted_and_chain_passthrough
    test_unknown_command_passthrough_error_code
    test_list_long_flag
    test_list_short_flag
    test_list_view_flag
    test_duplicate_alias
    test_invalid_mapping
    test_default_merge_priority
    test_default_missing_optional_configs_ignored
    test_default_list_merged_aliases
    test_quoted_alias_with_space
    test_wildcard_single_token_alias
    test_wildcard_multi_token_alias
    test_quoted_content_equivalence
    test_wildcard_multi_capture
    test_double_star_capture
    test_recursive_alias_quoted_prompt_with_dollar_at
    test_recursive_alias_dollar_prompt_is_literal
    test_super_rule_plain_tokens
    test_super_rule_quoted_command
    test_block_bash_capture_placeholder
    test_block_sh_runner
    test_block_windows_runner_command_generation
    test_block_embedded_double_star_empty_warn
    test_block_extra_args_warn_and_ignore
    test_block_double_star_requires_non_empty_warn
    test_block_empty_warn_noop
    test_block_list_summary
    test_block_invalid_runner_fails
    test_block_cache_clear
    test_builtin_env_vars

    cleanup
    generate_report

    echo "--------------------------------"
    echo "测试结果: PASS=$PASS_COUNT, FAIL=$FAIL_COUNT"

    if [[ "$FAIL_COUNT" -eq 0 ]]; then
        exit 0
    fi
    exit 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
