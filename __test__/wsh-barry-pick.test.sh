#!/bin/bash

# 引入公共测试工具
source "$(dirname "$0")/test_utils.sh"

# 测试注释模板说明
#   * Given：说明测试前置状态和数据条件。
#   * When：说明触发的用户行为或系统请求。
#   * Then：说明期望结果和关键断言。
#   * 防回归：说明历史问题或风险点。

# 路径配置
BASE_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$BASE_DIR/.." && pwd)
SCRIPT_TO_TEST="$PROJECT_ROOT/sh/wsh-barry-pick.sh"
TEST_DIR="$PROJECT_ROOT/test_playground_barry_pick"

# 设置测试环境
setup() {
    log_info "正在设置 barry-pick 测试环境..."

    if [ -d "$TEST_DIR" ]; then
        cleanup || exit 1
    fi

    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR" || exit 1

    git init -q -b master
    git config user.email "test@example.com"
    git config user.name "Test User"

    echo "base" > README.md
    git add README.md
    git commit -m "Initial commit" -q

    log_info "测试环境已准备就绪: $TEST_DIR"
}

# 清理测试环境
cleanup() {
    log_info "正在清理 barry-pick 测试环境..."
    cd "$PROJECT_ROOT" || exit 1

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

# 调用脚本并回收输出与退出码
run_script() {
    output=$(bash "$SCRIPT_TO_TEST" "$@" 2>&1)
    run_code=$?
    output=$(printf "%s" "$output" | tr -d '\r')
}

# 创建一个不包含排除配置的来源分支
create_source_branch_without_exclude() {
    git checkout -q -b feature-no-exclude
    echo "hello from feature" > feature.txt
    mkdir -p docs
    echo "feature doc" > docs/guide.md
    git add feature.txt docs/guide.md
    git commit -m "Add feature files" -q
    git checkout -q master
}

# 创建一个包含排除配置的来源分支
create_source_branch_with_exclude() {
    git checkout -q -b feature-with-exclude
    echo "keep me" > keep.txt
    echo "drop me" > secret.env
    cat > .squash-exclude <<'EOF'
secret.env
.squash-exclude
EOF
    git add keep.txt secret.env .squash-exclude
    git commit -m "Add excluded and included files" -q
    git checkout -q master
}

# 创建一个所有变更都会被排除的来源分支
create_source_branch_all_excluded() {
    git checkout -q -b feature-all-excluded
    echo "drop me too" > secret.env
    cat > .squash-exclude <<'EOF'
secret.env
.squash-exclude
EOF
    git add secret.env .squash-exclude
    git commit -m "Add only excluded files" -q
    git checkout -q master
}

# 创建一个使用接近 .gitignore 风格排除规则的来源分支
create_source_branch_with_gitignore_like_exclude() {
    git checkout -q -b feature-gitignore-like-exclude
    mkdir -p docs test-results src
    echo "doc page" > docs/index.md
    echo "analysis" > findings.md
    echo "result" > test-results/output.txt
    echo "progress" > progress.md
    echo "plan" > task_plan.md
    echo "keep me" > src/keep.js
    cat > .squash-exclude <<'EOF'
/docs
findings.md
test-results
progress.md
task_plan.md
EOF
    git add docs/index.md findings.md test-results/output.txt progress.md task_plan.md src/keep.js .squash-exclude
    git commit -m "Add gitignore-like excluded files" -q
    git checkout -q master
}

# 创建一个包含注释行与空白行排除规则的来源分支
create_source_branch_with_comment_and_whitespace_exclude() {
    git checkout -q -b feature-comment-whitespace-exclude
    echo "keep me" > keep.txt
    echo "drop me" > secret.env
    cat > .squash-exclude <<'EOF'
# 注释行：当前实现应忽略


secret.env
EOF
    git add keep.txt secret.env .squash-exclude
    git commit -m "Add exclude config with comments and whitespace" -q
    git checkout -q master
}

# 创建一个会修改 master 已存在文件，并通过排除规则恢复为 HEAD 的来源分支
create_source_branch_with_existing_file_excluded() {
    mkdir -p config
    echo "base" > config/app.env
    git add config/app.env
    git commit -m "Add base config file" -q

    git checkout -q -b feature-existing-file-excluded
    echo "feature-version" > config/app.env
    echo "keep me" > keep.txt
    cat > .squash-exclude <<'EOF'
config/app.env
EOF
    git add config/app.env keep.txt .squash-exclude
    git commit -m "Update existing config and add keep file" -q
    git checkout -q master
}

# 创建一个会修改 master 已存在目录，并通过目录规则整体恢复为 HEAD 的来源分支
create_source_branch_with_existing_directory_excluded() {
    mkdir -p docs src
    echo "base-a" > docs/a.md
    echo "base-b" > docs/b.md
    git add docs/a.md docs/b.md
    git commit -m "Add base docs directory" -q

    git checkout -q -b feature-existing-directory-excluded
    echo "feature-a" > docs/a.md
    echo "feature-c" > docs/c.md
    echo "keep me" > src/keep.js
    cat > .squash-exclude <<'EOF'
/docs
EOF
    git add docs/a.md docs/c.md src/keep.js .squash-exclude
    git commit -m "Update existing docs directory" -q
    git checkout -q master
}

# 创建一个会在 squash merge 时产生普通冲突的来源分支
create_source_branch_with_merge_conflict() {
    echo "base" > conflict.txt
    git add conflict.txt
    git commit -m "Add conflict base file" -q

    git checkout -q -b feature-conflict
    echo "feature-change" > conflict.txt
    git add conflict.txt
    git commit -m "Change conflict file on feature" -q
    git checkout -q master

    echo "master-change" > conflict.txt
    git add conflict.txt
    git commit -m "Change conflict file on master" -q
}

# 创建一个会在冲突前读取到排除配置，但仍在 merge 阶段产生冲突的来源分支
create_source_branch_with_merge_conflict_and_exclude() {
    echo "base" > conflict.txt
    git add conflict.txt
    git commit -m "Add conflict base file" -q

    git checkout -q -b feature-conflict-with-exclude
    echo "feature-change" > conflict.txt
    echo "drop me" > secret.env
    cat > .squash-exclude <<'EOF'
conflict.txt
secret.env
EOF
    git add conflict.txt secret.env .squash-exclude
    git commit -m "Change conflict file and add exclude config" -q
    git checkout -q master

    echo "master-change" > conflict.txt
    git add conflict.txt
    git commit -m "Change conflict file on master" -q
}

# 创建一个只有命中 exclude 文件发生冲突的来源分支
create_source_branch_with_excluded_file_conflict() {
    echo "base" > conflict.txt
    git add conflict.txt
    git commit -m "Add excluded conflict base file" -q

    git checkout -q -b feature-excluded-file-conflict
    echo "feature-change" > conflict.txt
    echo "keep me" > keep.txt
    cat > .squash-exclude <<'EOF'
conflict.txt
EOF
    git add conflict.txt keep.txt .squash-exclude
    git commit -m "Change excluded file and add keep file" -q
    git checkout -q master

    echo "master-change" > conflict.txt
    git add conflict.txt
    git commit -m "Change excluded file on master" -q
}

# 创建一个只有命中 exclude 目录发生冲突的来源分支
create_source_branch_with_excluded_directory_conflict() {
    mkdir -p docs src
    echo "base-doc" > docs/a.md
    git add docs/a.md
    git commit -m "Add excluded docs base file" -q

    git checkout -q -b feature-excluded-directory-conflict
    echo "feature-doc" > docs/a.md
    echo "keep me" > src/keep.js
    cat > .squash-exclude <<'EOF'
docs
EOF
    git add docs/a.md src/keep.js .squash-exclude
    git commit -m "Change excluded docs and add keep file" -q
    git checkout -q master

    echo "master-doc" > docs/a.md
    git add docs/a.md
    git commit -m "Change excluded docs on master" -q
}

# 创建一个同时存在命中 exclude 冲突和未命中 exclude 冲突的来源分支
create_source_branch_with_mixed_excluded_and_unexcluded_conflicts() {
    mkdir -p docs src
    echo "base-doc" > docs/a.md
    echo "base-app" > src/app.js
    git add docs/a.md src/app.js
    git commit -m "Add mixed conflict base files" -q

    git checkout -q -b feature-mixed-conflicts
    echo "feature-doc" > docs/a.md
    echo "feature-app" > src/app.js
    cat > .squash-exclude <<'EOF'
docs
EOF
    git add docs/a.md src/app.js .squash-exclude
    git commit -m "Change excluded docs and unexcluded app" -q
    git checkout -q master

    echo "master-doc" > docs/a.md
    echo "master-app" > src/app.js
    git add docs/a.md src/app.js
    git commit -m "Change mixed files on master" -q
}

# 创建一个所有冲突都命中 exclude 且没有其他变更的来源分支
create_source_branch_with_all_conflicts_excluded() {
    mkdir -p docs
    echo "base-doc" > docs/a.md
    git add docs/a.md
    git commit -m "Add all-excluded conflict base file" -q

    git checkout -q -b feature-all-conflicts-excluded
    echo "feature-doc" > docs/a.md
    cat > .squash-exclude <<'EOF'
docs
EOF
    git add docs/a.md .squash-exclude
    git commit -m "Change only excluded docs" -q
    git checkout -q master

    echo "master-doc" > docs/a.md
    git add docs/a.md
    git commit -m "Change only excluded docs on master" -q
}

# 创建一个来源分支删除和重命名命中 exclude 路径的场景
create_source_branch_with_excluded_delete_and_rename() {
    mkdir -p docs
    echo "keep delete target" > docs/delete-me.md
    echo "keep rename target" > docs/old-name.md
    git add docs/delete-me.md docs/old-name.md
    git commit -m "Add excluded delete and rename base files" -q

    git checkout -q -b feature-excluded-delete-rename
    rm docs/delete-me.md
    git mv docs/old-name.md docs/new-name.md
    cat > .squash-exclude <<'EOF'
docs
EOF
    git add -A docs .squash-exclude
    git commit -m "Delete and rename excluded docs" -q
    git checkout -q master
}


# 断言暂存区包含指定路径
assert_staged_contains() {
    local path="$1"

    if git diff --cached --name-only | grep -qxF "$path"; then
        return 0
    fi
    return 1
}

# 断言暂存区不包含指定路径
assert_staged_not_contains() {
    local path="$1"

    if git diff --cached --name-only | grep -qxF "$path"; then
        return 1
    fi
    return 0
}

# 断言冲突列表包含指定路径
assert_unmerged_contains() {
    local path="$1"

    if git diff --name-only --diff-filter=U | grep -qxF "$path"; then
        return 0
    fi
    return 1
}

# 断言冲突列表不包含指定路径
assert_unmerged_not_contains() {
    local path="$1"

    if git diff --name-only --diff-filter=U | grep -qxF "$path"; then
        return 1
    fi
    return 0
}

# 断言工作区文件内容等于预期值
assert_file_content_equals() {
    local path="$1"
    local expected="$2"

    if [ -f "$path" ] && [ "$(cat "$path")" = "$expected" ]; then
        return 0
    fi
    return 1
}

# Given：脚本存在且用户未传入任何参数。
# When：直接执行 barry-pick 脚本。
# Then：脚本应返回成功退出码，并显示完整帮助信息与关键参数说明。
# 防回归：避免无参数调用被当作错误处理，导致用户无法通过默认入口查看用法。
test_show_help_without_arguments() {
    echo "---------------------------------------------------"
    log_info "Running Test: 无参数时显示帮助信息"
    local start_time=$(current_time)
    local result="FAIL"
    local note=""

    run_script

    if [ "$run_code" -eq 0 ] \
        && [[ "$output" == *"使用方法:"* ]] \
        && [[ "$output" == *"wsh-barry-pick.sh"* ]] \
        && [[ "$output" == *"target-branch"* ]] \
        && [[ "$output" == *"-h, --help"* ]]; then
        result="PASS"
        log_success "无参数帮助信息测试通过"
    else
        note="output=[$output], code=$run_code"
        log_fail "$note"
    fi

    local end_time=$(current_time)
    local duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_show_help_without_arguments" "$result" "$duration" "$note"
}

# Given：脚本存在且用户通过短参数请求帮助。
# When：使用 -h 执行 barry-pick 脚本。
# Then：脚本应返回成功退出码，并显示完整帮助信息。
# 防回归：避免仅支持无参数帮助而遗漏短参数帮助入口。
test_show_help_with_short_option() {
    echo "---------------------------------------------------"
    log_info "Running Test: -h 时显示帮助信息"
    local start_time=$(current_time)
    local result="FAIL"
    local note=""

    run_script -h

    if [ "$run_code" -eq 0 ] \
        && [[ "$output" == *"使用方法:"* ]] \
        && [[ "$output" == *"target-branch"* ]] \
        && [[ "$output" == *"-h, --help"* ]]; then
        result="PASS"
        log_success "短参数帮助信息测试通过"
    else
        note="output=[$output], code=$run_code"
        log_fail "$note"
    fi

    local end_time=$(current_time)
    local duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_show_help_with_short_option" "$result" "$duration" "$note"
}

# Given：脚本存在且用户通过长参数请求帮助。
# When：使用 --help 执行 barry-pick 脚本。
# Then：脚本应返回成功退出码，并显示完整帮助信息。
# 防回归：避免长参数帮助入口失效，影响命令行工具的一致性。
test_show_help_with_long_option() {
    echo "---------------------------------------------------"
    log_info "Running Test: --help 时显示帮助信息"
    local start_time=$(current_time)
    local result="FAIL"
    local note=""

    run_script --help

    if [ "$run_code" -eq 0 ] \
        && [[ "$output" == *"使用方法:"* ]] \
        && [[ "$output" == *"target-branch"* ]] \
        && [[ "$output" == *"-h, --help"* ]]; then
        result="PASS"
        log_success "长参数帮助信息测试通过"
    else
        note="output=[$output], code=$run_code"
        log_fail "$note"
    fi

    local end_time=$(current_time)
    local duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_show_help_with_long_option" "$result" "$duration" "$note"
}

# Given：工作区存在已跟踪文件的未提交修改，且来源分支合法存在。
# When：执行 barry-pick 脚本尝试 squash merge。
# Then：脚本应拒绝继续执行，并提示工作区或索引不干净。
# 防回归：避免在脏工作区上执行 squash merge，导致用户本地改动与待合并改动混杂。
test_reject_dirty_worktree() {
    echo "---------------------------------------------------"
    log_info "Running Test: 脏工作区时拒绝执行"
    local start_time=$(current_time)
    local result="FAIL"
    local note=""

    create_source_branch_without_exclude
    echo "dirty change" >> README.md

    run_script feature-no-exclude

    if [ "$run_code" -ne 0 ] && [[ "$output" == *"working tree or index is not clean"* ]]; then
        result="PASS"
        log_success "脏工作区拒绝执行测试通过"
    else
        note="output=[$output], code=$run_code"
        log_fail "$note"
    fi

    local end_time=$(current_time)
    local duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_reject_dirty_worktree" "$result" "$duration" "$note"
}

# Given：来源分支包含多个新增文件，且没有 .squash-exclude 配置。
# When：执行 barry-pick 脚本进行 squash merge。
# Then：脚本应完成 squash merge，并把来源分支变更全部保留在暂存区。
# 防回归：避免“无排除配置”场景误删正常变更，导致 squash 结果不完整。
test_merge_without_exclude_config() {
    echo "---------------------------------------------------"
    log_info "Running Test: 无排除配置时保留全部 squash 结果"
    local start_time=$(current_time)
    local result="FAIL"
    local note=""

    create_source_branch_without_exclude
    run_script feature-no-exclude

    if [ "$run_code" -eq 0 ] \
        && [[ "$output" == *"No exclude config found in source branch"* ]] \
        && assert_staged_contains "feature.txt" \
        && assert_staged_contains "docs/guide.md"; then
        result="PASS"
        log_success "无排除配置 squash 测试通过"
    else
        note="output=[$output], code=$run_code, staged=[$(git diff --cached --name-only | tr '\n' ',')]"
        log_fail "$note"
    fi

    local end_time=$(current_time)
    local duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_merge_without_exclude_config" "$result" "$duration" "$note"
}

# Given：来源分支既有应保留文件，也有写入 .squash-exclude 的排除文件。
# When：执行 barry-pick 脚本并应用排除规则。
# Then：脚本应仅保留未排除文件在暂存区，并从工作区恢复被排除路径。
# 防回归：避免 restore 逻辑失效，导致本应排除的敏感文件被一起带入 squash 结果。
test_apply_exclude_config() {
    echo "---------------------------------------------------"
    log_info "Running Test: 排除配置可移除指定路径"
    local start_time=$(current_time)
    local result="FAIL"
    local note=""

    create_source_branch_with_exclude
    run_script feature-with-exclude

    if [ "$run_code" -eq 0 ] \
        && [[ "$output" == *"Found exclude config in feature-with-exclude:.squash-exclude"* ]] \
        && [[ "$output" == *"Applying exclusions..."* ]] \
        && assert_staged_contains "keep.txt" \
        && assert_staged_not_contains "secret.env" \
        && assert_staged_not_contains ".squash-exclude" \
        && [ ! -f "secret.env" ] \
        && [ ! -f ".squash-exclude" ]; then
        result="PASS"
        log_success "排除配置应用测试通过"
    else
        note="output=[$output], code=$run_code, staged=[$(git diff --cached --name-only | tr '\n' ',')]"
        log_fail "$note"
    fi

    local end_time=$(current_time)
    local duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_apply_exclude_config" "$result" "$duration" "$note"
}

# Given：来源分支中的全部新增内容都被写入 .squash-exclude。
# When：执行 barry-pick 脚本完成 squash merge 后应用排除。
# Then：脚本应提示没有可提交内容，并以成功状态退出。
# 防回归：避免全部排除时误报成功但残留 staged 变更，影响后续提交流程判断。
test_nothing_to_commit_after_exclude() {
    echo "---------------------------------------------------"
    log_info "Running Test: 全部排除后提示无可提交内容"
    local start_time=$(current_time)
    local result="FAIL"
    local note=""

    create_source_branch_all_excluded
    run_script feature-all-excluded

    if [ "$run_code" -eq 0 ] \
        && [[ "$output" == *"Nothing to commit after applying excludes."* ]] \
        && [ -z "$(git diff --cached --name-only)" ]; then
        result="PASS"
        log_success "全部排除后无可提交内容测试通过"
    else
        note="output=[$output], code=$run_code, staged=[$(git diff --cached --name-only | tr '\n' ',')]"
        log_fail "$note"
    fi

    local end_time=$(current_time)
    local duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_nothing_to_commit_after_exclude" "$result" "$duration" "$note"
}

# Given：来源分支中的 .squash-exclude 使用接近 .gitignore 的简单写法，既包含根目录文件，也包含目录路径。
# When：执行 barry-pick 脚本并按这些规则应用排除。
# Then：脚本应排除 docs、test-results 与指定根文件，只保留未命中的业务文件进入暂存区。
# 防回归：避免后续路径匹配退化，导致常见的目录名和根文件名写法无法按预期生效。
test_apply_gitignore_like_exclude_config() {
    echo "---------------------------------------------------"
    log_info "Running Test: 接近 .gitignore 风格的排除规则可生效"
    local start_time=$(current_time)
    local result="FAIL"
    local note=""

    create_source_branch_with_gitignore_like_exclude
    run_script feature-gitignore-like-exclude

    if [ "$run_code" -eq 0 ] \
        && [[ "$output" == *"Found exclude config in feature-gitignore-like-exclude:.squash-exclude"* ]] \
        && [[ "$output" == *"Applying exclusions..."* ]] \
        && assert_staged_contains "src/keep.js" \
        && assert_staged_not_contains "docs/index.md" \
        && assert_staged_not_contains "findings.md" \
        && assert_staged_not_contains "test-results/output.txt" \
        && assert_staged_not_contains "progress.md" \
        && assert_staged_not_contains "task_plan.md" \
        && assert_staged_not_contains ".squash-exclude" \
        && [ ! -e "docs/index.md" ] \
        && [ ! -e "findings.md" ] \
        && [ ! -e "test-results/output.txt" ] \
        && [ ! -e "progress.md" ] \
        && [ ! -e "task_plan.md" ]; then
        result="PASS"
        log_success "接近 .gitignore 风格的排除规则测试通过"
    else
        note="output=[$output], code=$run_code, staged=[$(git diff --cached --name-only | tr '\n' ',')]"
        log_fail "$note"
    fi

    local end_time=$(current_time)
    local duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_apply_gitignore_like_exclude_config" "$result" "$duration" "$note"
}

# Given：来源分支中的 .squash-exclude 含有注释行、空行和真实规则。
# When：执行 barry-pick 脚本应用排除规则。
# Then：脚本应忽略注释与空行，只对真实路径生效，并保留未命中的业务文件进入暂存区。
# 防回归：避免用户按文档写注释或空白分隔后，排除流程被无效 pathspec 破坏。
test_exclude_config_comment_lines() {
    echo "---------------------------------------------------"
    log_info "Running Test: 注释行与空白行不会破坏排除规则"
    local start_time=$(current_time)
    local result="FAIL"
    local note=""

    create_source_branch_with_comment_and_whitespace_exclude
    run_script feature-comment-whitespace-exclude

    if [ "$run_code" -eq 0 ] \
        && [[ "$output" == *"Applying exclusions..."* ]] \
        && assert_staged_contains "keep.txt" \
        && assert_staged_not_contains "secret.env" \
        && assert_staged_not_contains ".squash-exclude" \
        && [ ! -f "secret.env" ] \
        && [ ! -f ".squash-exclude" ]; then
        result="PASS"
        log_success "注释行与空白行排除规则测试通过"
    else
        note="output=[$output], code=$run_code, staged=[$(git diff --cached --name-only | tr '\n' ',')]"
        log_fail "$note"
    fi

    local end_time=$(current_time)
    local duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_exclude_config_comment_lines" "$result" "$duration" "$note"
}

# Given：当前分支 HEAD 中已存在文件，来源分支修改了该文件并把它写入 .squash-exclude。
# When：执行 barry-pick 脚本应用排除规则。
# Then：脚本应把该文件恢复为当前分支 HEAD 内容，而不是把 feature 版本或删除结果留在工作区。
# 防回归：避免排除“已有文件修改”时只覆盖 staged 状态，却未正确恢复工作区文件内容。
test_restore_existing_file_to_head_when_excluded() {
    echo "---------------------------------------------------"
    log_info "Running Test: 已存在文件被排除时恢复为 HEAD"
    local start_time=$(current_time)
    local result="FAIL"
    local note=""

    create_source_branch_with_existing_file_excluded
    run_script feature-existing-file-excluded

    if [ "$run_code" -eq 0 ] \
        && assert_staged_contains "keep.txt" \
        && assert_staged_not_contains "config/app.env" \
        && assert_staged_not_contains ".squash-exclude" \
        && [ "$(cat config/app.env)" = "base" ]; then
        result="PASS"
        log_success "已存在文件恢复 HEAD 测试通过"
    else
        note="output=[$output], code=$run_code, file=[$(cat config/app.env 2>/dev/null)], staged=[$(git diff --cached --name-only | tr '\n' ',')]"
        log_fail "$note"
    fi

    local end_time=$(current_time)
    local duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_restore_existing_file_to_head_when_excluded" "$result" "$duration" "$note"
}

# Given：当前分支 HEAD 中已存在目录，来源分支修改和新增了该目录下文件，并通过目录规则写入 .squash-exclude。
# When：执行 barry-pick 脚本应用排除规则。
# Then：脚本应整体恢复该目录到当前分支 HEAD，只保留未命中的业务文件进入暂存区。
# 防回归：避免目录规则只能排除“纯新增目录”，却无法正确恢复已有目录中的修改与新增文件。
test_restore_existing_directory_to_head_when_excluded() {
    echo "---------------------------------------------------"
    log_info "Running Test: 已存在目录被排除时整体恢复为 HEAD"
    local start_time=$(current_time)
    local result="FAIL"
    local note=""

    create_source_branch_with_existing_directory_excluded
    run_script feature-existing-directory-excluded

    if [ "$run_code" -eq 0 ] \
        && assert_staged_contains "src/keep.js" \
        && assert_staged_not_contains "docs/a.md" \
        && assert_staged_not_contains "docs/c.md" \
        && assert_staged_not_contains ".squash-exclude" \
        && [ "$(cat docs/a.md)" = "base-a" ] \
        && [ ! -e "docs/c.md" ]; then
        result="PASS"
        log_success "已存在目录恢复 HEAD 测试通过"
    else
        note="output=[$output], code=$run_code, docs_a=[$(cat docs/a.md 2>/dev/null)], docs_c_exists=[$([ -e docs/c.md ] && echo yes || echo no)], staged=[$(git diff --cached --name-only | tr '\n' ',')]"
        log_fail "$note"
    fi

    local end_time=$(current_time)
    local duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_restore_existing_directory_to_head_when_excluded" "$result" "$duration" "$note"
}

# Given：当前分支和来源分支都修改了同一文件同一位置，且不存在排除配置。
# When：执行 barry-pick 脚本触发 squash merge。
# Then：脚本应因 merge 冲突失败，并留下未合并文件供用户手工处理。
# 防回归：避免后续实现误吞掉 merge 冲突，导致用户误以为 squash 已成功完成。
test_merge_conflict_without_exclude() {
    echo "---------------------------------------------------"
    log_info "Running Test: 普通 merge 冲突会导致脚本失败"
    local start_time=$(current_time)
    local result="FAIL"
    local note=""

    create_source_branch_with_merge_conflict
    run_script feature-conflict

    if [ "$run_code" -ne 0 ] \
        && [[ "$output" == *"CONFLICT"* || "$output" == *"Automatic merge failed"* ]] \
        && assert_unmerged_contains "conflict.txt"; then
        result="PASS"
        log_success "普通 merge 冲突测试通过"
    else
        note="output=[$output], code=$run_code, unmerged=[$(git diff --name-only --diff-filter=U | tr '\n' ',')]"
        log_fail "$note"
    fi

    local end_time=$(current_time)
    local duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_merge_conflict_without_exclude" "$result" "$duration" "$note"
}

# Given：来源分支中的冲突文件命中 .squash-exclude，且还包含一个未排除的新文件。
# When：执行 barry-pick 脚本进行 squash merge。
# Then：命中 exclude 的冲突文件应保持当前分支 HEAD 内容，不进入 unmerged 状态，未排除文件仍进入暂存区。
# 防回归：避免 exclude 仍停留在 merge 后 restore 语义，导致被排除冲突文件阻塞整个 squash 流程。
test_excluded_file_conflict_does_not_block_squash_merge() {
    echo "---------------------------------------------------"
    log_info "Running Test: 命中 exclude 的冲突文件不阻塞 squash merge"
    local start_time=$(current_time)
    local result="FAIL"
    local note=""

    create_source_branch_with_excluded_file_conflict
    run_script feature-excluded-file-conflict

    if [ "$run_code" -eq 0 ] \
        && assert_file_content_equals "conflict.txt" "master-change" \
        && assert_unmerged_not_contains "conflict.txt" \
        && assert_staged_contains "keep.txt" \
        && assert_staged_not_contains "conflict.txt" \
        && assert_staged_not_contains ".squash-exclude"; then
        result="PASS"
        log_success "命中 exclude 的冲突文件不阻塞测试通过"
    else
        note="output=[$output], code=$run_code, conflict=[$(cat conflict.txt 2>/dev/null)], unmerged=[$(git diff --name-only --diff-filter=U | tr '\n' ',')], staged=[$(git diff --cached --name-only | tr '\n' ',')]"
        log_fail "$note"
    fi

    local end_time=$(current_time)
    local duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_excluded_file_conflict_does_not_block_squash_merge" "$result" "$duration" "$note"
}

# Given：来源分支中的冲突目录命中 .squash-exclude，且还包含一个未排除的新文件。
# When：执行 barry-pick 脚本进行 squash merge。
# Then：命中 exclude 的目录应整体保持当前分支 HEAD 状态，不留下目录内冲突，未排除文件仍进入暂存区。
# 防回归：避免目录级 exclude 只能处理无冲突恢复，无法在冲突前过滤来源分支目录影响。
test_excluded_directory_conflict_does_not_block_squash_merge() {
    echo "---------------------------------------------------"
    log_info "Running Test: 命中 exclude 的冲突目录不阻塞 squash merge"
    local start_time=$(current_time)
    local result="FAIL"
    local note=""

    create_source_branch_with_excluded_directory_conflict
    run_script feature-excluded-directory-conflict

    if [ "$run_code" -eq 0 ] \
        && assert_file_content_equals "docs/a.md" "master-doc" \
        && assert_unmerged_not_contains "docs/a.md" \
        && assert_staged_contains "src/keep.js" \
        && assert_staged_not_contains "docs/a.md" \
        && assert_staged_not_contains ".squash-exclude"; then
        result="PASS"
        log_success "命中 exclude 的冲突目录不阻塞测试通过"
    else
        note="output=[$output], code=$run_code, docs_a=[$(cat docs/a.md 2>/dev/null)], unmerged=[$(git diff --name-only --diff-filter=U | tr '\n' ',')], staged=[$(git diff --cached --name-only | tr '\n' ',')]"
        log_fail "$note"
    fi

    local end_time=$(current_time)
    local duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_excluded_directory_conflict_does_not_block_squash_merge" "$result" "$duration" "$note"
}

# Given：同一次 squash merge 中同时存在命中 exclude 的冲突路径和未命中 exclude 的冲突路径。
# When：执行 barry-pick 脚本进行 squash merge。
# Then：命中 exclude 的冲突应自动保持当前分支状态，未命中的冲突仍保留给用户解决并导致脚本非零退出。
# 防回归：避免为了让 exclude 生效而吞掉所有冲突，或反过来让被排除冲突继续污染 unmerged 列表。
test_mixed_excluded_and_unexcluded_conflicts_keep_only_unexcluded_conflict() {
    echo "---------------------------------------------------"
    log_info "Running Test: 混合冲突时只保留未命中 exclude 的冲突"
    local start_time=$(current_time)
    local result="FAIL"
    local note=""

    create_source_branch_with_mixed_excluded_and_unexcluded_conflicts
    run_script feature-mixed-conflicts

    if [ "$run_code" -ne 0 ] \
        && assert_file_content_equals "docs/a.md" "master-doc" \
        && assert_unmerged_not_contains "docs/a.md" \
        && assert_unmerged_contains "src/app.js"; then
        result="PASS"
        log_success "混合冲突保留未命中项测试通过"
    else
        note="output=[$output], code=$run_code, docs_a=[$(cat docs/a.md 2>/dev/null)], app=[$(cat src/app.js 2>/dev/null)], unmerged=[$(git diff --name-only --diff-filter=U | tr '\n' ',')], staged=[$(git diff --cached --name-only | tr '\n' ',')]"
        log_fail "$note"
    fi

    local end_time=$(current_time)
    local duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_mixed_excluded_and_unexcluded_conflicts_keep_only_unexcluded_conflict" "$result" "$duration" "$note"
}

# Given：本次 squash merge 中所有冲突路径都命中 .squash-exclude，且没有其他未排除变更。
# When：执行 barry-pick 脚本进行 squash merge。
# Then：脚本应自动保持当前分支状态、清空暂存区并以成功状态提示没有可提交内容。
# 防回归：避免全部冲突都被 exclude 覆盖时仍要求用户处理本应被排除的冲突。
test_all_conflicts_excluded_can_finish_with_nothing_to_commit() {
    echo "---------------------------------------------------"
    log_info "Running Test: 全部冲突命中 exclude 时可成功结束"
    local start_time=$(current_time)
    local result="FAIL"
    local note=""

    create_source_branch_with_all_conflicts_excluded
    run_script feature-all-conflicts-excluded

    if [ "$run_code" -eq 0 ] \
        && [[ "$output" == *"Nothing to commit after applying excludes."* ]] \
        && assert_file_content_equals "docs/a.md" "master-doc" \
        && [ -z "$(git diff --name-only --diff-filter=U)" ] \
        && [ -z "$(git diff --cached --name-only)" ]; then
        result="PASS"
        log_success "全部冲突命中 exclude 成功结束测试通过"
    else
        note="output=[$output], code=$run_code, docs_a=[$(cat docs/a.md 2>/dev/null)], unmerged=[$(git diff --name-only --diff-filter=U | tr '\n' ',')], staged=[$(git diff --cached --name-only | tr '\n' ',')]"
        log_fail "$note"
    fi

    local end_time=$(current_time)
    local duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_all_conflicts_excluded_can_finish_with_nothing_to_commit" "$result" "$duration" "$note"
}

# Given：来源分支删除和重命名了命中 .squash-exclude 的目录内容。
# When：执行 barry-pick 脚本进行 squash merge。
# Then：命中 exclude 的删除和重命名都不应被采纳，目录应保持当前分支 HEAD 状态。
# 防回归：避免 exclude 只覆盖新增/修改场景，遗漏删除和重命名这类结构性变更。
test_excluded_delete_and_rename_keep_current_branch_state() {
    echo "---------------------------------------------------"
    log_info "Running Test: 命中 exclude 的删除和重命名保持当前分支状态"
    local start_time=$(current_time)
    local result="FAIL"
    local note=""

    create_source_branch_with_excluded_delete_and_rename
    run_script feature-excluded-delete-rename

    if [ "$run_code" -eq 0 ] \
        && assert_file_content_equals "docs/delete-me.md" "keep delete target" \
        && assert_file_content_equals "docs/old-name.md" "keep rename target" \
        && [ ! -e "docs/new-name.md" ] \
        && assert_staged_not_contains "docs/delete-me.md" \
        && assert_staged_not_contains "docs/old-name.md" \
        && assert_staged_not_contains "docs/new-name.md" \
        && assert_staged_not_contains ".squash-exclude"; then
        result="PASS"
        log_success "命中 exclude 的删除和重命名保持当前分支状态测试通过"
    else
        note="output=[$output], code=$run_code, delete_exists=[$([ -e docs/delete-me.md ] && echo yes || echo no)], old_exists=[$([ -e docs/old-name.md ] && echo yes || echo no)], new_exists=[$([ -e docs/new-name.md ] && echo yes || echo no)], staged=[$(git diff --cached --name-only | tr '\n' ',')]"
        log_fail "$note"
    fi

    local end_time=$(current_time)
    local duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_excluded_delete_and_rename_keep_current_branch_state" "$result" "$duration" "$note"
}

main() {
    setup

    test_show_help_without_arguments
    cleanup || exit 1
    setup

    test_show_help_with_short_option
    cleanup || exit 1
    setup

    test_show_help_with_long_option
    cleanup || exit 1
    setup

    test_reject_dirty_worktree
    cleanup || exit 1
    setup

    test_merge_without_exclude_config
    cleanup || exit 1
    setup

    test_apply_exclude_config
    cleanup || exit 1
    setup

    test_nothing_to_commit_after_exclude
    cleanup || exit 1
    setup

    test_apply_gitignore_like_exclude_config
    cleanup || exit 1
    setup

    test_exclude_config_comment_lines
    cleanup || exit 1
    setup

    test_restore_existing_file_to_head_when_excluded
    cleanup || exit 1
    setup

    test_restore_existing_directory_to_head_when_excluded
    cleanup || exit 1
    setup

    test_merge_conflict_without_exclude
    cleanup || exit 1
    setup

    test_excluded_file_conflict_does_not_block_squash_merge
    cleanup || exit 1
    setup

    test_excluded_directory_conflict_does_not_block_squash_merge
    cleanup || exit 1
    setup

    test_mixed_excluded_and_unexcluded_conflicts_keep_only_unexcluded_conflict
    cleanup || exit 1
    setup

    test_all_conflicts_excluded_can_finish_with_nothing_to_commit
    cleanup || exit 1
    setup

    test_excluded_delete_and_rename_keep_current_branch_state

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
