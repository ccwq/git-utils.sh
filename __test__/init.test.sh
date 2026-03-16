#!/bin/bash

source "$(dirname "$0")/test_utils.sh"

BASE_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$BASE_DIR/.." && pwd)
SCRIPT_TO_TEST="$PROJECT_ROOT/scripts/init.bat"
TEST_DIR="$PROJECT_ROOT/test_playground_init"

SCRIPT_WIN=""
STATE_FILE_WIN=""
EXPECTED_SH_WIN=""
EXPECTED_CLINK_WIN=""
RUNNER_CMD=""
RUNNER_WIN=""

setup() {
    log_info "正在设置 init 测试环境..."
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    SCRIPT_WIN=$(cygpath -aw "$SCRIPT_TO_TEST")
    STATE_FILE_WIN=$(cygpath -aw "$TEST_DIR/init-state.env")
    EXPECTED_SH_WIN=$(cygpath -aw "$PROJECT_ROOT/sh")
    EXPECTED_CLINK_WIN=$(cygpath -aw "$PROJECT_ROOT/clink-lua-scripts")
    RUNNER_CMD="$TEST_DIR/run-init.cmd"
    RUNNER_WIN=$(cygpath -aw "$RUNNER_CMD")
}

cleanup() {
    log_info "正在清理 init 测试环境..."
    rm -rf "$TEST_DIR"
}

run_init() {
    local process_path="$1"
    local overwrite_choice="$2"

    cat > "$RUNNER_CMD" <<EOF
@echo off
set "GIT_UTILS_INIT_STATE_FILE=$STATE_FILE_WIN"
set "GIT_UTILS_INIT_PROCESS_PATH=$process_path"
set "GIT_UTILS_INIT_OVERWRITE_CHOICE=$overwrite_choice"
call "$SCRIPT_WIN"
EOF

    output=$(cmd.exe //v:off //c "$RUNNER_WIN" 2>&1)
    run_code=$?
    output=$(printf "%s" "$output" | tr -d '\r')
}

state_value() {
    local key="$1"
    local value
    value=$(grep -m1 "^${key}=" "$TEST_DIR/init-state.env" | cut -d= -f2-)
    printf "%s" "$value"
}

test_adds_path_and_clink_when_missing() {
    local start_time end_time duration result note user_path clink_path
    start_time=$(current_time)
    result="FAIL"
    note=""

    : > "$TEST_DIR/init-state.env"
    run_init "C:\\Windows\\System32" "Y"
    user_path=$(state_value "Path")
    clink_path=$(state_value "CLINK_PATH")

    if [[ $run_code -eq 0 ]] && [[ "$user_path" == "$EXPECTED_SH_WIN" ]] && [[ "$clink_path" == "$EXPECTED_CLINK_WIN" ]]; then
        result="PASS"
        log_success "缺失环境变量时自动初始化测试通过"
    else
        note="output=[$output], code=$run_code, Path=[$user_path], CLINK_PATH=[$clink_path]"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_adds_path_and_clink_when_missing" "$result" "$duration" "$note"
}

test_keeps_existing_values_without_duplicates() {
    local start_time end_time duration result note user_path clink_path
    start_time=$(current_time)
    result="FAIL"
    note=""

    cat > "$TEST_DIR/init-state.env" <<EOF
Path=$EXPECTED_SH_WIN
CLINK_PATH=$EXPECTED_CLINK_WIN
EOF

    run_init "$EXPECTED_SH_WIN;C:\\Windows\\System32" "Y"
    user_path=$(state_value "Path")
    clink_path=$(state_value "CLINK_PATH")

    if [[ $run_code -eq 0 ]] && [[ "$user_path" == "$EXPECTED_SH_WIN" ]] && [[ "$clink_path" == "$EXPECTED_CLINK_WIN" ]] && [[ "$output" == *"Current PATH already contains the sh directory."* ]]; then
        result="PASS"
        log_success "已存在配置时保持不变测试通过"
    else
        note="output=[$output], code=$run_code, Path=[$user_path], CLINK_PATH=[$clink_path]"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_keeps_existing_values_without_duplicates" "$result" "$duration" "$note"
}

test_skips_clink_overwrite_when_user_rejects() {
    local start_time end_time duration result note user_path clink_path
    start_time=$(current_time)
    result="FAIL"
    note=""

    cat > "$TEST_DIR/init-state.env" <<EOF
Path=C:\Tools
CLINK_PATH=C:\Other\Clink
EOF

    run_init "C:\\Windows\\System32" "N"
    user_path=$(state_value "Path")
    clink_path=$(state_value "CLINK_PATH")

    if [[ $run_code -eq 0 ]] && [[ "$user_path" == "C:\Tools;$EXPECTED_SH_WIN" ]] && [[ "$clink_path" == "C:\Other\Clink" ]] && [[ "$output" == *"Keeping the current CLINK_PATH."* ]]; then
        result="PASS"
        log_success "拒绝覆盖 CLINK_PATH 测试通过"
    else
        note="output=[$output], code=$run_code, Path=[$user_path], CLINK_PATH=[$clink_path]"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_skips_clink_overwrite_when_user_rejects" "$result" "$duration" "$note"
}

test_overwrites_clink_when_user_confirms() {
    local start_time end_time duration result note clink_path
    start_time=$(current_time)
    result="FAIL"
    note=""

    cat > "$TEST_DIR/init-state.env" <<EOF
Path=C:\Tools
CLINK_PATH=C:\Other\Clink
EOF

    run_init "C:\\Windows\\System32" "Y"
    clink_path=$(state_value "CLINK_PATH")

    if [[ $run_code -eq 0 ]] && [[ "$clink_path" == "$EXPECTED_CLINK_WIN" ]] && [[ "$output" == *"Updated CLINK_PATH to this repo."* ]]; then
        result="PASS"
        log_success "确认覆盖 CLINK_PATH 测试通过"
    else
        note="output=[$output], code=$run_code, CLINK_PATH=[$clink_path]"
        log_fail "$note"
    fi

    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_overwrites_clink_when_user_confirms" "$result" "$duration" "$note"
}

main() {
    setup

    test_adds_path_and_clink_when_missing
    test_keeps_existing_values_without_duplicates
    test_skips_clink_overwrite_when_user_rejects
    test_overwrites_clink_when_user_confirms

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
