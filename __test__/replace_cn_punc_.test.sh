#!/bin/bash

# 引入公共测试工具
source "$(dirname "$0")/test_utils.sh"

# Setup
setup() {
    log_info "正在准备测试环境..."
    mkdir -p test_playground/punc_test
    
    # 创建测试文件 1: 包含多种中文标点
    cat > test_playground/punc_test/test1.txt <<EOF
你好，世界。
这是一个测试！
真的吗？
是的：确信；
“引用” ‘单引用’
（括号） 【中括号】 《书名号》
一、二、三
EOF

    # 创建测试文件 2: 纯英文文件 (不应改变)
    cat > test_playground/punc_test/test2.txt <<EOF
Hello, World.
This is a test!
Really?
Yes: sure;
"Quote" 'Single Quote'
(Parentheses) [Brackets] <Book>
One, Two, Three
EOF
}

# Cleanup
cleanup() {
    log_info "正在清理测试环境..."
    rm -rf test_playground/punc_test
}

# Test Case 1: 验证中文标点替换
test_replace_punctuation() {
    log_info "测试用例 1: 验证中文标点替换..."
    local start_time=$(current_time)
    
    local target_file="test_playground/punc_test/test1.txt"
    
    # 运行脚本
    # 注意：根据当前目录结构，脚本在 ../sh/replace_cn_punc_.sh
    # 但我们通常在根目录或 __test__ 目录运行。
    # 假设我们在项目根目录运行此测试脚本，或者通过 absolute path 引用。
    # 这里我们尝试找到脚本路径。
    local script_path
    if [ -f "./sh/replace_cn_punc_.sh" ]; then
        script_path="./sh/replace_cn_punc_.sh"
    elif [ -f "../sh/replace_cn_punc_.sh" ]; then
        script_path="../sh/replace_cn_punc_.sh"
    else
        log_fail "找不到目标脚本 replace_cn_punc_.sh"
        local end_time=$(current_time)
        record_test_result "验证中文标点替换" "FAIL" "$(calc_duration $start_time $end_time)" "找不到目标脚本"
        return
    fi
    
    # 执行替换
    bash "$script_path" "$target_file" > /dev/null
    
    # 验证内容
    # 预期结果
    # 你好,世界.
    # 这是一个测试!
    # 真的吗?
    # 是的:确信;
    # "引用" '单引用'
    # (括号) [中括号] <书名号>
    # 一,二,三
    
    local content=$(cat "$target_file")
    local end_time=$(current_time)
    local duration=$(calc_duration $start_time $end_time)
    
    # 简单的 grep 检查
    if echo "$content" | grep -q "，"; then
        log_fail "文件中仍包含中文逗号"
        record_test_result "验证中文标点替换" "FAIL" "$duration" "文件中仍包含中文逗号"
    elif echo "$content" | grep -q "。"; then
        log_fail "文件中仍包含中文句号"
        record_test_result "验证中文标点替换" "FAIL" "$duration" "文件中仍包含中文句号"
    elif ! echo "$content" | grep -q "你好,世界."; then
        log_fail "内容替换不正确: $content"
        record_test_result "验证中文标点替换" "FAIL" "$duration" "内容替换不正确"
    else
        log_success "中文标点替换成功"
        record_test_result "验证中文标点替换" "PASS" "$duration" "正常"
    fi
}

# Test Case 2: 验证英文文件不受影响
test_ignore_english() {
    log_info "测试用例 2: 验证英文文件不受影响..."
    local start_time=$(current_time)
    
    local target_file="test_playground/punc_test/test2.txt"
    local original_md5
    local new_md5
    
    if command -v md5sum >/dev/null 2>&1; then
         original_md5=$(md5sum "$target_file" | awk '{print $1}')
    elif command -v md5 >/dev/null 2>&1; then
         original_md5=$(md5 "$target_file" | awk '{print $1}') # Mac
    else
         original_md5="unknown"
    fi

    local script_path
    if [ -f "./sh/replace_cn_punc_.sh" ]; then
        script_path="./sh/replace_cn_punc_.sh"
    elif [ -f "../sh/replace_cn_punc_.sh" ]; then
        script_path="../sh/replace_cn_punc_.sh"
    fi
    
    bash "$script_path" "$target_file" > /dev/null
    
    local end_time=$(current_time)
    local duration=$(calc_duration $start_time $end_time)
    
    if [ "$original_md5" != "unknown" ]; then
        if command -v md5sum >/dev/null 2>&1; then
             new_md5=$(md5sum "$target_file" | awk '{print $1}')
        elif command -v md5 >/dev/null 2>&1; then
             new_md5=$(md5 "$target_file" | awk '{print $1}')
        fi
        
        if [ "$original_md5" == "$new_md5" ]; then
            log_success "英文文件未被修改"
            record_test_result "验证英文文件不受影响" "PASS" "$duration" "MD5一致"
        else
            log_fail "英文文件被修改了 (MD5 变化)"
            record_test_result "验证英文文件不受影响" "FAIL" "$duration" "MD5变化"
        fi
    else
        # Fallback verification if md5 not available
        if grep -q "Hello, World." "$target_file"; then
             log_success "英文文件内容看似正常"
             record_test_result "验证英文文件不受影响" "PASS" "$duration" "内容看似正常 (无MD5)"
        else
             log_fail "英文文件内容异常"
             record_test_result "验证英文文件不受影响" "FAIL" "$duration" "内容异常"
        fi
    fi
}

main() {
    setup
    
    test_replace_punctuation
    test_ignore_english
    
    cleanup
    
    generate_report
    
    echo "--------------------------------"
    echo "测试结果: PASS=$PASS_COUNT, FAIL=$FAIL_COUNT"
    if [ $FAIL_COUNT -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
