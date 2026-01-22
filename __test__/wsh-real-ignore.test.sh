#!/bin/bash

# 引入公共测试工具
source "$(dirname "$0")/test_utils.sh"

# 路径配置
BASE_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$BASE_DIR/.." && pwd)
SCRIPT_TO_TEST="$PROJECT_ROOT/sh/wsh-real-ignore.sh"
TEST_DIR="$PROJECT_ROOT/test_playground"

# 设置测试环境
setup() {
    log_info "正在设置测试环境..."
    
    # 清理旧环境
    if [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
    
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR" || exit 1
    
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
    rm -rf "$TEST_DIR"
    log_info "清理完成。"
}

# 测试用例 1: 忽略单个文件
test_ignore_file() {
    echo "---------------------------------------------------"
    log_info "Running Test: 忽略单个文件 (ignore single file)"
    local start_time=$(current_time)
    
    local target_file="config.json"
    
    # 1. 创建并提交文件
    echo '{"secret": "123"}' > "$target_file"
    git add "$target_file"
    git commit -m "Add config file" -q
    
    # 2. 运行脚本
    bash "$SCRIPT_TO_TEST" "$target_file"
    
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
    
    local end_time=$(current_time)
    local duration=$(calc_duration $start_time $end_time)
    
    if [ $error_found -eq 0 ]; then
        log_success "忽略单个文件测试通过"
        record_test_result "忽略单个文件" "PASS" "$duration" "正常"
    else
        record_test_result "忽略单个文件" "FAIL" "$duration" "$note"
    fi
}

# 测试用例 2: 忽略目录
test_ignore_dir() {
    echo "---------------------------------------------------"
    log_info "Running Test: 忽略目录 (ignore directory)"
    local start_time=$(current_time)
    
    local target_dir=".obsidian"
    local target_file="$target_dir/workspace.json"
    
    # 1. 创建并提交目录和文件
    mkdir -p "$target_dir"
    echo "{}" > "$target_file"
    git add "$target_dir"
    git commit -m "Add directory" -q
    
    # 2. 运行脚本
    bash "$SCRIPT_TO_TEST" "$target_dir"
    
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
    
    local end_time=$(current_time)
    local duration=$(calc_duration $start_time $end_time)
    
    if [ $error_found -eq 0 ]; then
        log_success "忽略目录测试通过"
        record_test_result "忽略目录" "PASS" "$duration" "正常"
    else
        record_test_result "忽略目录" "FAIL" "$duration" "$note"
    fi
}

# 主函数
main() {
    setup
    
    test_ignore_file
    test_ignore_dir
    
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
