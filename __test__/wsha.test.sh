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
bar echo barbar -- --name ccwq
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

    mkdir -p "$user_home_dir/.config"
    mkdir -p "$work_dir/.config"

    cat > "$user_home_dir/.config/wsh-alias.txt" <<'EOF'
ab echo user-ab
foo echo user-foo
EOF

    cat > "$work_dir/.config/wsh-alias.txt" <<'EOF'
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
        && [[ "$clean_output" == *"[自定义] $config_file"* ]] \
        && [[ "$clean_output" == *"ab"* ]] \
        && [[ "$clean_output" == *"echo agent-browser"* ]] \
        && [[ "$clean_output" == *"foo"* ]] \
        && [[ "$clean_output" == *"echo foobar open"* ]] \
        && [[ "$clean_output" == *"bar"* ]] \
        && [[ "$clean_output" == *"echo barbar -- --name ccwq"* ]]; then
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
        && [[ "$clean_output" == *"[自定义] $config_file"* ]] \
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
        && [[ "$clean_output" == *"[自定义] $config_win"* ]] \
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
    builtin_win=$(cygpath -u "$PROJECT_ROOT/config/wsh-alias.txt")
    user_win=$(cygpath -u "$user_home_dir/.config/wsh-alias.txt")
    local_win=$(cygpath -u "$work_dir/.config/wsh-alias.txt")

    run_wsha_default "$work_dir" "$user_home_dir" --list
    if [[ $run_code -eq 0 ]] \
        && [[ "$output" == *"[内置] $builtin_win"* ]] \
        && [[ "$output" == *"[用户级] $user_win"* ]] \
        && [[ "$output" == *"[项目级] $local_win"* ]] \
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

test_builtin_env_vars() {
    local start_time end_time duration result note config_file expected_home expected_sh expected_config
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-env-vars.txt"
    write_config "$config_file" "env_vars"
    expected_home=$(cygpath -u "$PROJECT_ROOT")
    expected_sh=$(cygpath -u "$PROJECT_ROOT/sh")
    expected_config=$(cygpath -u "$PROJECT_ROOT/config")

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
