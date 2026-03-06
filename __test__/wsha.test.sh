#!/bin/bash

source "$(dirname "$0")/test_utils.sh"

BASE_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$BASE_DIR/.." && pwd)
SCRIPT_TO_TEST="$PROJECT_ROOT/sh/wsha.bat"
TEST_DIR="$PROJECT_ROOT/test_playground_wsha"

SCRIPT_WIN=""

# 准备测试沙箱与路径
setup() {
    log_info "正在设置 wsha 测试环境..."
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    SCRIPT_WIN=$(cygpath -am "$SCRIPT_TO_TEST")
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
    fi
}

# 调用 wsha 并回收输出与退出码
run_wsha() {
    local config_file="$1"
    shift
    local config_win
    config_win=$(cygpath -am "$config_file")

    output=$(WSHA_CONFIG_FILE="$config_win" cmd.exe //c "$SCRIPT_WIN" "$@" 2>&1)
    run_code=$?
    output=$(printf "%s" "$output" | tr -d '\r')
}

test_expand_ab() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-normal.txt"
    write_config "$config_file" "normal"

    run_wsha "$config_file" ab open
    if [[ $run_code -eq 0 ]] && [[ "$output" == *"agent-browser open"* ]]; then
        result="PASS"
        log_success "ab 展开测试通过"
    else
        note="output=[$output], code=$run_code"
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
    if [[ $run_code -eq 0 ]] && [[ "$output" == *"foobar open --ping"* ]]; then
        result="PASS"
        log_success "foo 参数追加测试通过"
    else
        note="output=[$output], code=$run_code"
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
    if [[ $run_code -eq 0 ]] && [[ "$output" == *"barbar --age 40 --name ccwq"* ]]; then
        result="PASS"
        log_success "bar 占位符插入测试通过"
    else
        note="output=[$output], code=$run_code"
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
    if [[ $run_code -eq 0 ]] && [[ "$output" == *"hello"* ]]; then
        result="PASS"
        log_success "未知 alias 透传参数执行测试通过"
    else
        note="output=[$output], code=$run_code"
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
    if [[ "$output" != *"'t.cn' is not recognized"* ]] && [[ "$output" != *"'ping' is not recognized"* ]] && [[ "$output" == *"t.cn"* ]]; then
        result="PASS"
        log_success "未知 alias 的 ping 透传测试通过"
    else
        note="output=[$output], code=$run_code"
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
    if [[ $run_code -eq 0 ]] && [[ "$output" == *"agent-browser open t.cn"* ]]; then
        result="PASS"
        log_success "引号包裹 alias 展开测试通过"
    else
        note="output=[$output], code=$run_code"
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

    run_wsha "$config_file" "echo foo | findstr foo"
    if [[ $run_code -eq 0 ]] && [[ "$output" == *"foo"* ]]; then
        result="PASS"
        log_success "引号复杂命令透传测试通过"
    else
        note="output=[$output], code=$run_code"
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
    if [[ $run_code -eq 0 ]] && [[ "$output" == *"a"* ]] && [[ "$output" == *"b"* ]]; then
        result="PASS"
        log_success "引号与链式命令透传测试通过"
    else
        note="output=[$output], code=$run_code"
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
    if [[ $run_code -ne 0 ]] && [[ "$output" == *"not recognized"* ]]; then
        result="PASS"
        log_success "未知命令透传错误码测试通过"
    else
        note="output=[$output], code=$run_code"
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
    if [[ $run_code -eq 0 ]] && [[ "$output" == *"ab echo agent-browser"* ]] && [[ "$output" == *"foo echo foobar open"* ]] && [[ "$output" == *"bar echo barbar -- --name ccwq"* ]]; then
        result="PASS"
        log_success "--list 输出测试通过"
    else
        note="output=[$output], code=$run_code"
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
    if [[ $run_code -eq 0 ]] && [[ "$output" == *"ab echo agent-browser"* ]] && [[ "$output" == *"foo echo foobar open"* ]] && [[ "$output" == *"bar echo barbar -- --name ccwq"* ]]; then
        result="PASS"
        log_success "-l 输出测试通过"
    else
        note="output=[$output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_list_short_flag" "$result" "$duration" "$note"
}

test_duplicate_alias() {
    local start_time end_time duration result note config_file
    start_time=$(current_time)
    result="FAIL"
    note=""
    config_file="$TEST_DIR/alias-dup.txt"
    write_config "$config_file" "duplicate"

    run_wsha "$config_file" ab run
    if [[ $run_code -ne 0 ]] && [[ "$output" == *"duplicate alias"* ]]; then
        result="PASS"
        log_success "重复 alias 检测测试通过"
    else
        note="output=[$output], code=$run_code"
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
    if [[ $run_code -ne 0 ]] && [[ "$output" == *"invalid config"* ]]; then
        result="PASS"
        log_success "非法配置检测测试通过"
    else
        note="output=[$output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_invalid_mapping" "$result" "$duration" "$note"
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
    test_duplicate_alias
    test_invalid_mapping

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
