#!/bin/bash

# 引入测试工具
source "$(dirname "$0")/test_utils.sh"

TEST_PLAYGROUND="test_playground_patch"

setup() {
    log_info "正在设置测试环境..."
    if [ -d "$TEST_PLAYGROUND" ]; then
        rm -rf "$TEST_PLAYGROUND"
    fi
    mkdir -p "$TEST_PLAYGROUND"
    cd "$TEST_PLAYGROUND" || exit 1
    
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"
}

cleanup() {
    log_info "清理测试环境..."
    cd ..
    if [ -d "$TEST_PLAYGROUND" ]; then
        rm -rf "$TEST_PLAYGROUND"
    fi
}

test_help() {
    local start_time=$(current_time)
    local result="FAIL"
    local note=""
    
    # 运行脚本帮助
    # 注意：需要引用正确路径
    output=$("$BASE_DIR/../sh/wsh-fpatch.sh" -h)
    
    if echo "$output" | grep -q "使用方法"; then
        result="PASS"
        log_success "Help check passed"
    else
        note="Help output missing expected text"
        log_fail "$note"
    fi
    
    local end_time=$(current_time)
    record_test_result "test_help" "$result" "$(calc_duration "$start_time" "$end_time")" "$note"
}

test_one_commit() {
    local start_time=$(current_time)
    local result="FAIL"
    local note=""
    
    # 准备数据
    echo "v1" > file1.txt
    git add file1.txt
    git commit -m "init" > /dev/null
    local commit1=$(git rev-parse HEAD)
    
    echo "v2" > file1.txt
    echo "new" > file2.txt
    # 注意：脚本是对比 commit 与工作区，所以不需要 commit 新的更改
    
    # 验证
    local out_dir="output_one"
    "$BASE_DIR/../sh/wsh-fpatch.sh" "$commit1" -o "$out_dir" > /dev/null
    
    if [[ -f "$out_dir/file1.txt" ]] && [[ -f "$out_dir/file2.txt" ]]; then
        # 移除 Windows 回车符进行比较
        content1=$(tr -d '\r' < "$out_dir/file1.txt")
        content2=$(tr -d '\r' < "$out_dir/file2.txt")
        
        if [[ "$content1" == "v2" ]] && [[ "$content2" == "new" ]]; then
            result="PASS"
            log_success "One commit test passed"
        else
            note="Content mismatch: file1=$content1, file2=$content2"
            log_fail "$note"
        fi
    else
        note="Files not created in output dir"
        log_fail "$note"
    fi
    
    local end_time=$(current_time)
    record_test_result "test_one_commit" "$result" "$(calc_duration "$start_time" "$end_time")" "$note"
}

test_two_commits() {
    local start_time=$(current_time)
    local result="FAIL"
    local note=""
    
    # 准备数据
    echo "v1" > fileA.txt
    git add fileA.txt
    git commit -m "c1" > /dev/null
    local c1=$(git rev-parse HEAD)
    
    echo "v2" > fileA.txt
    echo "v1" > fileB.txt
    git add .
    git commit -m "c2" > /dev/null
    local c2=$(git rev-parse HEAD)
    
    # 修改工作区为 v3 (验证脚本取的是工作区最新版)
    echo "v3" > fileA.txt
    
    # 运行脚本: c1 vs c2 (fileA changed, fileB added)
    local out_dir="output_two"
    "$BASE_DIR/../sh/wsh-fpatch.sh" "$c1" "$c2" -o "$out_dir" > /dev/null
    
    if [[ -f "$out_dir/fileA.txt" ]] && [[ -f "$out_dir/fileB.txt" ]]; then
        contentA=$(tr -d '\r' < "$out_dir/fileA.txt")
        
        # 脚本逻辑是：取工作区最新版
        if [[ "$contentA" == "v3" ]]; then
            result="PASS"
            log_success "Two commits test passed"
        else
            note="Content mismatch: expected v3, got $contentA"
            log_fail "$note"
        fi
    else
        note="Files not created"
        log_fail "$note"
    fi
    
    local end_time=$(current_time)
    record_test_result "test_two_commits" "$result" "$(calc_duration "$start_time" "$end_time")" "$note"
}

test_missing_file() {
    local start_time=$(current_time)
    local result="FAIL"
    local note=""
    
    # 准备数据
    echo "v1" > fileDel.txt
    git add fileDel.txt
    git commit -m "del_init" > /dev/null
    local c1=$(git rev-parse HEAD)
    
    rm fileDel.txt
    
    # 运行脚本: c1 vs workspace (fileDel changed/deleted)
    local out_dir="output_del"
    "$BASE_DIR/../sh/wsh-fpatch.sh" "$c1" -o "$out_dir" > /dev/null
    
    if [[ ! -e "$out_dir/fileDel.txt" ]]; then
        result="PASS"
        log_success "Missing file skipped"
    else
        note="Deleted file was copied?"
        log_fail "$note"
    fi
    
    local end_time=$(current_time)
    record_test_result "test_missing_file" "$result" "$(calc_duration "$start_time" "$end_time")" "$note"
}

test_input_exclude() {
    local start_time=$(current_time)
    local result="FAIL"
    local note=""

    # 准备数据
    mkdir -p notes/tmp src other
    echo "base" > notes/n1.txt
    echo "base" > notes/tmp/t1.txt
    echo "base" > src/s1.txt
    echo "base" > other/o1.txt
    git add .
    git commit -m "input_exclude_base" > /dev/null
    local commit_base=$(git rev-parse HEAD)

    echo "v2" > notes/n1.txt
    echo "v2" > notes/tmp/t1.txt
    echo "v2" > src/s1.txt
    echo "v2" > other/o1.txt
    echo "new" > notes/new.txt
    echo "new" > src/new.txt
    echo "new" > notes/tmp/newtmp.txt

    # 运行脚本: 仅包含 notes 与 src/*.txt，排除 notes/tmp
    local out_dir="output_input_exclude"
    "$BASE_DIR/../sh/wsh-fpatch.sh" "$commit_base" -i "./notes,src/*.txt" -e "./notes/tmp" -o "$out_dir" > /dev/null

    if [[ -f "$out_dir/notes/n1.txt" ]] && [[ -f "$out_dir/notes/new.txt" ]] && [[ -f "$out_dir/src/s1.txt" ]] && [[ -f "$out_dir/src/new.txt" ]]; then
        if [[ ! -e "$out_dir/notes/tmp/t1.txt" ]] && [[ ! -e "$out_dir/notes/tmp/newtmp.txt" ]] && [[ ! -e "$out_dir/other/o1.txt" ]]; then
            result="PASS"
            log_success "Input/exclude test passed"
        else
            note="Excluded files were copied"
            log_fail "$note"
        fi
    else
        note="Expected files missing in output dir"
        log_fail "$note"
    fi

    local end_time=$(current_time)
    record_test_result "test_input_exclude" "$result" "$(calc_duration "$start_time" "$end_time")" "$note"
}

test_complex_patterns() {
    local start_time=$(current_time)
    local result="FAIL"
    local note=""

    # 准备数据
    mkdir -p "space dir/sub" src/alpha src/beta
    echo "base" > "space dir/keep.txt"
    echo "base" > "space dir/sub/skip.txt"
    echo "base" > "src/alpha/test-1.txt"
    echo "base" > "src/beta/test-2.txt"
    echo "base" > "src/beta/other.md"
    git add .
    git commit -m "complex_base" > /dev/null
    local commit_base=$(git rev-parse HEAD)

    echo "v2" > "space dir/keep.txt"
    echo "v2" > "space dir/sub/skip.txt"
    echo "v2" > "src/alpha/test-1.txt"
    echo "v2" > "src/beta/test-2.txt"
    echo "v2" > "src/beta/other.md"
    echo "new" > "src/alpha/test-new.txt"
    echo "new" > "space dir/new.txt"

    # 运行脚本: 包含空格目录与 glob，排除子目录与指定文件
    local out_dir="output_complex"
    "$BASE_DIR/../sh/wsh-fpatch.sh" "$commit_base" \
        -i "./space dir/*,src/*/test*.txt" \
        -e "./space dir/sub,src/beta/test-2.txt" \
        -o "$out_dir" > /dev/null

    if [[ -f "$out_dir/space dir/keep.txt" ]] && [[ -f "$out_dir/space dir/new.txt" ]] \
        && [[ -f "$out_dir/src/alpha/test-1.txt" ]] && [[ -f "$out_dir/src/alpha/test-new.txt" ]]; then
        if [[ ! -e "$out_dir/space dir/sub/skip.txt" ]] \
            && [[ ! -e "$out_dir/src/beta/test-2.txt" ]] \
            && [[ ! -e "$out_dir/src/beta/other.md" ]]; then
            result="PASS"
            log_success "Complex patterns test passed"
        else
            note="Excluded files were copied"
            log_fail "$note"
        fi
    else
        note="Expected files missing in output dir"
        log_fail "$note"
    fi

    local end_time=$(current_time)
    record_test_result "test_complex_patterns" "$result" "$(calc_duration "$start_time" "$end_time")" "$note"
}

main() {
    setup
    
    test_help
    test_one_commit
    test_two_commits
    test_missing_file
    test_input_exclude
    test_complex_patterns
    
    cleanup
    generate_report
}

main
