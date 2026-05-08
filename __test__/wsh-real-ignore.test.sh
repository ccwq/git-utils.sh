#!/bin/bash

# 引入公共测试工具
source "$(dirname "$0")/test_utils.sh"

# 路径配置
BASE_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$BASE_DIR/.." && pwd)
SCRIPT_TO_TEST="$PROJECT_ROOT/sh/wsh-real-ignore.sh"
W_BAT_TO_TEST="$PROJECT_ROOT/sh/w.bat"
TEST_DIR="$PROJECT_ROOT/test_playground"
W_BAT_WIN=""

# 设置测试环境
setup() {
    log_info "正在设置测试环境..."
    
    # 清理旧环境
    if [ -d "$TEST_DIR" ]; then
        cleanup || exit 1
    fi
    
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR" || exit 1
    W_BAT_WIN=$(cygpath -am "$W_BAT_TO_TEST")
    
    # 初始化 Git
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    # 创建初始提交
    touch README.md
    git add README.md
    git commit -m "Initial commit" -q
    
    log_info "测试环境已准备就绪: $TEST_DIR"
}

# 清理测试环境
cleanup() {
    log_info "正在清理测试环境..."
    cd "$PROJECT_ROOT" || exit 1

    # Windows/Git Bash 下刚执行完 filter-branch/gc 时偶尔会短暂占用 .git 文件。
    for _ in 1 2 3 4 5; do
        rm -rf "$TEST_DIR" 2>/dev/null
        if [ ! -d "$TEST_DIR" ]; then
            log_info "清理完成。"
            return 0
        fi
        sleep 1
    done

    log_fail "测试目录清理失败: $TEST_DIR"
    return 1
}

# 测试用例 1: 默认从当前索引和历史中彻底忽略单个文件
test_purge_file_from_history() {
    echo "---------------------------------------------------"
    log_info "Running Test: 默认清理单个文件历史 (purge single file from history)"
    local start_time=$(current_time)
    
    local target_file="config.json"
    
    # 1. 创建并提交文件
    echo '{"secret": "123"}' > "$target_file"
    git add "$target_file"
    git commit -m "Add config file" -q
    
    # 2. 运行脚本；默认行为会改写历史，测试中使用 -y 跳过交互确认
    bash "$SCRIPT_TO_TEST" -y "$target_file"
    
    # 3. 验证
    local error_found=0
    local note=""
    
    # 验证文件是否仍存在于磁盘
    if [ ! -f "$target_file" ]; then
        log_fail "文件被物理删除！"
        error_found=1
        note="文件被物理删除"
    fi
    
    # 验证文件是否已从 Git 索引移除
    if git ls-files --error-unmatch "$target_file" >/dev/null 2>&1; then
        log_fail "文件仍在 Git 索引中！"
        error_found=1
        note="文件仍在 Git 索引中"
    fi
    
    # 验证 .gitignore
    if ! grep -qxF "$target_file" .gitignore; then
        log_fail ".gitignore 未包含目标文件！"
        error_found=1
        note=".gitignore 未包含目标文件"
    fi

    # 验证历史对象中已经没有目标路径
    if git rev-list --objects --all | grep -F -- "$target_file" >/dev/null 2>&1; then
        log_fail "历史提交中仍包含目标文件！"
        error_found=1
        note="历史提交中仍包含目标文件"
    fi

    # 验证本地文件因为 .gitignore 规则被忽略
    if ! git check-ignore -q "$target_file"; then
        log_fail "目标文件未被 Git 忽略！"
        error_found=1
        note="目标文件未被 Git 忽略"
    fi
    
    local end_time=$(current_time)
    local duration=$(calc_duration $start_time $end_time)
    
    if [ $error_found -eq 0 ]; then
        log_success "默认清理单个文件历史测试通过"
        record_test_result "默认清理单个文件历史" "PASS" "$duration" "正常"
    else
        record_test_result "默认清理单个文件历史" "FAIL" "$duration" "$note"
    fi
}

# 测试用例 2: 默认从当前索引和历史中彻底忽略带空格的文件名
test_purge_file_with_spaces_from_history() {
    echo "---------------------------------------------------"
    log_info "Running Test: 默认清理带空格文件名历史 (purge spaced filename from history)"
    local start_time=$(current_time)

    local target_file="CLIProxyAPI - copy.bin"

    # 1. 创建并提交带空格的文件名，覆盖 index-filter 和备份恢复的 quoting 行为
    echo "binary placeholder" > "$target_file"
    git add "$target_file"
    git commit -m "Add spaced filename" -q

    # 2. 运行脚本；目标必须作为单个参数传入
    bash "$SCRIPT_TO_TEST" -y "$target_file"

    # 3. 验证
    local error_found=0
    local note=""

    if [ ! -f "$target_file" ]; then
        log_fail "带空格文件名的本地文件被物理删除！"
        error_found=1
        note="带空格文件名的本地文件被物理删除"
    fi

    if git ls-files --error-unmatch "$target_file" >/dev/null 2>&1; then
        log_fail "带空格文件名仍在 Git 索引中！"
        error_found=1
        note="带空格文件名仍在 Git 索引中"
    fi

    if ! grep -qxF "$target_file" .gitignore; then
        log_fail ".gitignore 未精确包含带空格文件名！"
        error_found=1
        note=".gitignore 未精确包含带空格文件名"
    fi

    if git rev-list --objects --all | grep -F -- "$target_file" >/dev/null 2>&1; then
        log_fail "历史提交中仍包含带空格文件名！"
        error_found=1
        note="历史提交中仍包含带空格文件名"
    fi

    if ! git check-ignore -q "$target_file"; then
        log_fail "带空格文件名未被 Git 忽略！"
        error_found=1
        note="带空格文件名未被 Git 忽略"
    fi

    local end_time=$(current_time)
    local duration=$(calc_duration $start_time $end_time)

    if [ $error_found -eq 0 ]; then
        log_success "默认清理带空格文件名历史测试通过"
        record_test_result "默认清理带空格文件名历史" "PASS" "$duration" "正常"
    else
        record_test_result "默认清理带空格文件名历史" "FAIL" "$duration" "$note"
    fi
}

# 测试用例 3: 通过 w.bat git-omit 语法糖清理带空格文件名
test_w_bat_git_omit_with_spaces() {
    echo "---------------------------------------------------"
    log_info "Running Test: w.bat git-omit 清理带空格文件名"
    local start_time=$(current_time)

    local target_file="CLIProxyAPI - copy.bin"

    # 1. 创建并提交带空格文件名
    echo "binary placeholder" > "$target_file"
    git add "$target_file"
    git commit -m "Add spaced filename for w.bat" -q

    # 2. 通过 w.bat git-omit 调用，验证 bat/alias/wsh 三层转发不会拆散空格参数
    local output
    local run_code
    output=$(cmd.exe //c "$W_BAT_WIN" git-omit -y "$target_file" 2>&1)
    run_code=$?
    output=$(printf "%s" "$output" | tr -d '\r')

    # 3. 验证
    local error_found=0
    local note=""

    if [ $run_code -ne 0 ]; then
        log_fail "w.bat git-omit 执行失败: $output"
        error_found=1
        note="w.bat git-omit 执行失败"
    fi

    if [ ! -f "$target_file" ]; then
        log_fail "w.bat git-omit 后本地文件被物理删除！"
        error_found=1
        note="w.bat git-omit 后本地文件被物理删除"
    fi

    if git ls-files --error-unmatch "$target_file" >/dev/null 2>&1; then
        log_fail "w.bat git-omit 后文件仍在 Git 索引中！"
        error_found=1
        note="w.bat git-omit 后文件仍在 Git 索引中"
    fi

    if ! grep -qxF "$target_file" .gitignore; then
        log_fail "w.bat git-omit 后 .gitignore 未精确包含带空格文件名！"
        error_found=1
        note="w.bat git-omit 后 .gitignore 未精确包含带空格文件名"
    fi

    if git rev-list --objects --all | grep -F -- "$target_file" >/dev/null 2>&1; then
        log_fail "w.bat git-omit 后历史提交中仍包含带空格文件名！"
        error_found=1
        note="w.bat git-omit 后历史提交中仍包含带空格文件名"
    fi

    if ! git check-ignore -q "$target_file"; then
        log_fail "w.bat git-omit 后带空格文件名未被 Git 忽略！"
        error_found=1
        note="w.bat git-omit 后带空格文件名未被 Git 忽略"
    fi

    local end_time=$(current_time)
    local duration=$(calc_duration $start_time $end_time)

    if [ $error_found -eq 0 ]; then
        log_success "w.bat git-omit 清理带空格文件名测试通过"
        record_test_result "w.bat git-omit 清理带空格文件名" "PASS" "$duration" "正常"
    else
        record_test_result "w.bat git-omit 清理带空格文件名" "FAIL" "$duration" "$note"
    fi
}

# 测试用例 4: 默认从当前索引和历史中彻底忽略目录
test_purge_dir_from_history() {
    echo "---------------------------------------------------"
    log_info "Running Test: 默认清理目录历史 (purge directory from history)"
    local start_time=$(current_time)
    
    local target_dir=".obsidian"
    local target_file="$target_dir/workspace.json"
    
    # 1. 创建并提交目录和文件
    mkdir -p "$target_dir"
    echo "{}" > "$target_file"
    git add "$target_dir"
    git commit -m "Add directory" -q
    
    # 2. 运行脚本；默认行为会改写历史，测试中使用 -y 跳过交互确认
    bash "$SCRIPT_TO_TEST" -y "$target_dir"
    
    # 3. 验证
    local error_found=0
    local note=""
    
    # 验证文件是否仍存在于磁盘
    if [ ! -f "$target_file" ]; then
        log_fail "目录中的文件被物理删除！"
        error_found=1
        note="目录中的文件被物理删除"
    fi
    
    # 验证文件是否已从 Git 索引移除
    if git ls-files --error-unmatch "$target_file" >/dev/null 2>&1; then
        log_fail "文件仍在 Git 索引中！"
        error_found=1
        note="文件仍在 Git 索引中"
    fi
    
    # 验证 .gitignore
    if ! grep -qxF "$target_dir" .gitignore; then
        log_fail ".gitignore 未包含目标目录！"
        error_found=1
        note=".gitignore 未包含目标目录"
    fi

    # 验证历史对象中已经没有目录内文件
    if git rev-list --objects --all | grep -F -- "$target_file" >/dev/null 2>&1; then
        log_fail "历史提交中仍包含目录内文件！"
        error_found=1
        note="历史提交中仍包含目录内文件"
    fi

    # 验证本地目录因为 .gitignore 规则被忽略
    if ! git check-ignore -q "$target_file"; then
        log_fail "目录内文件未被 Git 忽略！"
        error_found=1
        note="目录内文件未被 Git 忽略"
    fi
    
    local end_time=$(current_time)
    local duration=$(calc_duration $start_time $end_time)
    
    if [ $error_found -eq 0 ]; then
        log_success "默认清理目录历史测试通过"
        record_test_result "默认清理目录历史" "PASS" "$duration" "正常"
    else
        record_test_result "默认清理目录历史" "FAIL" "$duration" "$note"
    fi
}

# 测试用例 5: --cached-only 保留旧行为，不改写历史
test_cached_only_mode() {
    echo "---------------------------------------------------"
    log_info "Running Test: 仅当前索引忽略 (--cached-only)"
    local start_time=$(current_time)

    local target_file="local-only.log"

    # 1. 创建并提交文件
    echo "runtime log" > "$target_file"
    git add "$target_file"
    git commit -m "Add local log" -q

    # 2. 运行旧行为模式
    bash "$SCRIPT_TO_TEST" --cached-only "$target_file"

    # 3. 验证
    local error_found=0
    local note=""

    if [ ! -f "$target_file" ]; then
        log_fail "文件被物理删除！"
        error_found=1
        note="文件被物理删除"
    fi

    if git ls-files --error-unmatch "$target_file" >/dev/null 2>&1; then
        log_fail "文件仍在 Git 索引中！"
        error_found=1
        note="文件仍在 Git 索引中"
    fi

    if ! grep -qxF "$target_file" .gitignore; then
        log_fail ".gitignore 未包含目标文件！"
        error_found=1
        note=".gitignore 未包含目标文件"
    fi

    if ! git rev-list --objects --all | grep -F -- "$target_file" >/dev/null 2>&1; then
        log_fail "--cached-only 不应清理历史！"
        error_found=1
        note="--cached-only 错误清理了历史"
    fi

    local end_time=$(current_time)
    local duration=$(calc_duration $start_time $end_time)

    if [ $error_found -eq 0 ]; then
        log_success "仅当前索引忽略测试通过"
        record_test_result "仅当前索引忽略" "PASS" "$duration" "正常"
    else
        record_test_result "仅当前索引忽略" "FAIL" "$duration" "$note"
    fi
}

# 主函数
main() {
    setup
    test_purge_file_from_history
    cleanup

    setup
    test_purge_file_with_spaces_from_history
    cleanup

    setup
    test_w_bat_git_omit_with_spaces
    cleanup

    setup
    test_purge_dir_from_history
    cleanup

    setup
    test_cached_only_mode
    cleanup
    
    generate_report
    
    echo "---------------------------------------------------"
    echo "测试结果汇总:"
    echo -e "${GREEN}PASS: $PASS_COUNT${NC}"
    if [ $FAIL_COUNT -gt 0 ]; then
        echo -e "${RED}FAIL: $FAIL_COUNT${NC}"
        # cleanup # 失败时不清理，方便调试
        exit 1
    else
        echo -e "${RED}FAIL: $FAIL_COUNT${NC}"
        cleanup
        exit 0
    fi
}

main
