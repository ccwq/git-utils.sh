#!/bin/bash

# 显示帮助信息
show_help() {
    echo "使用方法: $0 [选项] <文件路径或Glob> [更多目标...]"
    echo ""
    echo "该脚本用于从当前索引和 Git 历史中彻底移除指定文件或文件夹，并将其添加到 .gitignore。"
    echo "默认会改写 Git 历史、清理 reflog/gc 以释放本地 .git 空间，同时尽量保留本地工作区文件内容。"
    echo ""
    echo "参数:"
    echo "  文件路径或Glob        需要彻底忽略的目标，例如 .obsidian/workspace.json、.vscode 或 \"*.log\""
    echo ""
    echo "选项:"
    echo "  -h, --help           显示此帮助信息"
    echo "  -y, --yes            跳过历史改写确认提示"
    echo "  --cached-only        使用旧行为：仅从当前索引移除并写入 .gitignore，不改写历史"
    echo ""
    echo "示例:"
    echo "  $0 .obsidian/workspace.json"
    echo "  $0 .vscode"
    echo "  $0 \"cpa/bin/CLIProxyAPI - copy\""
    echo "  $0 \"*.log\""
    echo "  $0 --cached-only .env.local"
}

# 将路径统一为仓库相对路径，避免 .gitignore 中出现 ./foo 和 foo 两种写法
normalize_target() {
    local target="$1"
    target="${target//\\//}"
    target="${target#./}"
    printf '%s\n' "$target"
}

# 检查当前目录是否位于 Git 仓库中
ensure_git_repo() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "错误: 当前目录不在 Git 仓库中。"
        return 1
    fi
}

# 历史改写前必须保持工作区干净，避免用户已有改动被 checkout/rewrite 流程干扰
ensure_clean_worktree() {
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "错误: 工作区或暂存区存在未提交改动。"
        echo "请先提交/暂存处理这些改动后再运行默认历史清理模式。"
        echo "如果只想使用旧行为，可运行: $0 --cached-only <目标>"
        return 1
    fi
}

# 向 .gitignore 添加目标，已存在时跳过
append_gitignore() {
    local target="$1"

    touch .gitignore
    if ! grep -qxF "$target" <(tr -d '\r' < .gitignore) 2>/dev/null; then
        echo "状态: 正在将 '$target' 添加到 .gitignore..."
        echo "$target" >> .gitignore
    else
        echo "状态: '$target' 已经存在于 .gitignore 中，跳过添加。"
    fi
}

# 旧行为：只停止当前索引追踪，不改写历史
process_cached_only() {
    local target="$1"

    git rm -r --cached --ignore-unmatch -- "$target" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "状态: 无法处理 '$target'。请确保路径正确且当前处于 Git 仓库中。"
        return 1
    fi

    echo "状态: 已从 Git 索引中移除（本地文件已保留）。"
    append_gitignore "$target"
}

# 记录需要备份的本地路径，历史改写后再恢复到工作区
collect_backup_paths() {
    local backup_list="$1"
    shift
    local target
    local path

    : > "$backup_list"
    for target in "$@"; do
        if [ -e "$target" ]; then
            printf '%s\n' "$target" >> "$backup_list"
        fi

        while IFS= read -r -d '' path; do
            printf '%s\n' "$path" >> "$backup_list"
        done < <(git ls-files -z -- "$target")
    done

    sort -u "$backup_list" -o "$backup_list"
}

# 备份目标文件，避免 filter-branch 更新工作区时把本地副本带走
backup_worktree_paths() {
    local backup_list="$1"
    local backup_tar="$2"

    if [ ! -s "$backup_list" ]; then
        echo "状态: 未发现需要备份的本地目标文件。"
        return 0
    fi

    tar -cf "$backup_tar" -T "$backup_list"
    echo "状态: 已备份本地目标文件，历史清理后会恢复。"
}

# 为传给 shell 的路径做单引号转义
shell_quote() {
    local value="$1"
    printf "'%s'" "${value//\'/\'\\\'\'}"
}

# 构造 git filter-branch 的 index-filter 命令
build_index_filter() {
    local cmd="git rm -r --cached --ignore-unmatch --"
    local target
    local quoted

    for target in "$@"; do
        quoted=$(shell_quote "$target")
        cmd="$cmd $quoted"
    done

    printf '%s\n' "$cmd"
}

# 展示目标在历史中的对象情况，帮助用户确认要清理的内容
show_history_matches() {
    local target

    echo "状态: 历史中匹配到的目标对象:"
    for target in "$@"; do
        git rev-list --objects --all |
            grep -F -- "$target" |
            git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize:disk) %(rest)' 2>/dev/null
    done
}

# 默认行为：改写历史并释放本地 .git 空间
purge_history() {
    local yes="$1"
    shift
    local targets=("$@")
    local temp_dir
    local backup_list
    local backup_tar
    local index_filter
    local answer
    local old_head

    ensure_clean_worktree || return 1

    if git remote | grep -q .; then
        echo "警告: 当前仓库存在 remote。历史改写后如需同步远端，通常需要 git push --force-with-lease。"
        echo "警告: 其他克隆需要重新同步，否则可能把大对象再次推回历史。"
    fi

    show_history_matches "${targets[@]}"

    if [ "$yes" -ne 1 ]; then
        echo "--------------------------------"
        echo "即将改写所有 refs 的 Git 历史，并立即执行 gc 释放本地 .git 空间。"
        read -r -p "确认继续? 输入 yes 继续: " answer
        if [ "$answer" != "yes" ]; then
            echo "状态: 用户取消操作。"
            return 1
        fi
    fi

    old_head=$(git rev-parse --short HEAD)
    echo "状态: 当前 HEAD 为 $old_head。默认释放空间模式不会保留旧历史引用。"

    temp_dir=$(mktemp -d)
    backup_list="$temp_dir/backup-list.txt"
    backup_tar="$temp_dir/worktree-backup.tar"

    collect_backup_paths "$backup_list" "${targets[@]}"
    backup_worktree_paths "$backup_list" "$backup_tar" || return 1

    index_filter=$(build_index_filter "${targets[@]}")
    FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch --force \
        --index-filter "$index_filter" \
        --prune-empty \
        --tag-name-filter cat \
        -- --all || return 1

    # filter-branch 会保留 refs/original；删除后再 expire/gc 才能真正释放对象空间
    git for-each-ref --format='%(refname)' refs/original/ |
        while IFS= read -r ref; do
            git update-ref -d "$ref"
        done

    git reflog expire --expire=now --all || return 1
    git gc --prune=now --aggressive || return 1

    if [ -f "$backup_tar" ]; then
        tar -xf "$backup_tar"
        echo "状态: 已恢复本地工作区目标文件。"
    fi

    for target in "${targets[@]}"; do
        append_gitignore "$target"
    done

    rm -rf "$temp_dir"
    echo "状态: 历史清理与本地 .git 空间释放流程已完成。"
}

main() {
    local cached_only=0
    local yes=0
    local raw
    local target
    local targets=()

    if [ $# -eq 0 ]; then
        show_help
        return 0
    fi

    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                show_help
                return 0
                ;;
            -y|--yes)
                yes=1
                shift
                ;;
            --cached-only)
                cached_only=1
                shift
                ;;
            *)
                raw="$1"
                target=$(normalize_target "$raw")
                targets+=("$target")
                shift
                ;;
        esac
    done

    if [ ${#targets[@]} -eq 0 ]; then
        show_help
        return 1
    fi

    ensure_git_repo || return 1

    echo "--------------------------------"
    if [ "$cached_only" -eq 1 ]; then
        echo "模式: 仅停止当前索引追踪，不改写历史。"
        for target in "${targets[@]}"; do
            echo "正在处理目标: $target"
            process_cached_only "$target" || return 1
        done
    else
        echo "模式: 默认历史清理，会从当前索引和所有历史提交中移除目标并释放 .git 空间。"
        printf '目标: %s\n' "${targets[@]}"
        purge_history "$yes" "${targets[@]}" || return 1
    fi

    echo "--------------------------------"
    echo "所有操作已完成！"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
