#!/bin/bash

source "$(dirname "$0")/test_utils.sh"

BASE_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$BASE_DIR/.." && pwd)
SCRIPT_TO_TEST="$PROJECT_ROOT/sh/wsh.bat"
TEST_DIR="$PROJECT_ROOT/test_playground_wsh"

SCRIPT_WIN=""

# 准备测试沙箱与路径
setup() {
    log_info "正在设置 wsh 测试环境..."
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    SCRIPT_WIN=$(cygpath -am "$SCRIPT_TO_TEST")
}

# 清理测试沙箱
cleanup() {
    log_info "正在清理 wsh 测试环境..."
    rm -rf "$TEST_DIR"
}

# 调用 wsh 并回收输出与退出码
run_wsh() {
    output=$(cmd.exe //c "$SCRIPT_WIN" "$@" 2>&1)
    run_code=$?
    output=$(printf "%s" "$output" | tr -d '\r')
}

test_help_no_args() {
    local start_time end_time duration result note
    start_time=$(current_time)
    result="FAIL"
    note=""

    run_wsh
    if [[ $run_code -eq 0 ]] && [[ "$output" == *"Usage:"* ]] && [[ "$output" == *"Behavior:"* ]]; then
        result="PASS"
        log_success "无参数帮助输出测试通过"
    else
        note="output=[$output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_help_no_args" "$result" "$duration" "$note"
}

test_help_long_flag() {
    local start_time end_time duration result note
    start_time=$(current_time)
    result="FAIL"
    note=""

    run_wsh --help
    if [[ $run_code -eq 0 ]] && [[ "$output" == *"wsh --help | -h"* ]]; then
        result="PASS"
        log_success "--help 输出测试通过"
    else
        note="output=[$output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_help_long_flag" "$result" "$duration" "$note"
}

test_help_short_flag() {
    local start_time end_time duration result note
    start_time=$(current_time)
    result="FAIL"
    note=""

    run_wsh -h
    if [[ $run_code -eq 0 ]] && [[ "$output" == *"wsh ."* ]]; then
        result="PASS"
        log_success "-h 输出测试通过"
    else
        note="output=[$output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_help_short_flag" "$result" "$duration" "$note"
}

test_passthrough_non_whitelist() {
    local start_time end_time duration result note
    start_time=$(current_time)
    result="FAIL"
    note=""

    run_wsh printf hello
    if [[ $run_code -eq 0 ]] && [[ "$output" == "hello" ]]; then
        result="PASS"
        log_success "非白名单命令透传测试通过"
    else
        note="output=[$output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_passthrough_non_whitelist" "$result" "$duration" "$note"
}

test_pipe_non_whitelist() {
    local start_time end_time duration result note
    start_time=$(current_time)
    result="FAIL"
    note=""

    run_wsh "printf 'a\\nb\\n' | wc -l"
    if [[ $run_code -eq 0 ]] && [[ "$output" == *"2"* ]]; then
        result="PASS"
        log_success "非白名单管道命令测试通过"
    else
        note="output=[$output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_pipe_non_whitelist" "$result" "$duration" "$note"
}

test_pipe_with_ls_current_behavior() {
    local start_time end_time duration result note
    start_time=$(current_time)
    result="FAIL"
    note=""

    run_wsh "ls | wc -l"
    if [[ $run_code -ne 0 ]] && [[ "$output" == *"wc: unknown option"* ]]; then
        result="PASS"
        log_success "ls 管道当前行为测试通过"
    else
        note="output=[$output], code=$run_code"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_pipe_with_ls_current_behavior" "$result" "$duration" "$note"
}

main() {
    setup

    test_help_no_args
    test_help_long_flag
    test_help_short_flag
    test_passthrough_non_whitelist
    test_pipe_non_whitelist
    test_pipe_with_ls_current_behavior

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
