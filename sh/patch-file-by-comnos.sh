#!/bin/bash

# 显示帮助信息的函数
show_help() {
    echo "使用方法: $0 [选项] [commit1] [commit2]"
    echo ""
    echo "该脚本用于基于 Git 提交记录提取变更文件，并将工作区中的最新版本复制到指定目录。"
    echo ""
    echo "参数:"
    echo "  commit1          Git 提交哈希值（可选）。"
    echo "                   - 如果仅提供 commit1：对比该提交与当前工作区。"
    echo "                   - 如果提供 commit1 和 commit2：对比这两个提交。"
    echo "  commit2          Git 提交哈希值（可选）。"
    echo ""
    echo "选项:"
    echo "  -h, --help       显示此帮助信息"
    echo "  -o, --output     指定输出目录 (默认: ./path-files/YYYY-MM-DD_HH-MM-SS/)"
    echo ""
    echo "示例:"
    echo "  $0 HEAD~1"
    echo "  $0 HEAD~5 HEAD~2 -o ./my-patch"
}

main() {
    local output_dir=""
    local commits=()
    local default_output_base="./path-files"

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                return 0
                ;;
            -o|--output)
                if [[ -n "$2" && "$2" != -* ]]; then
                    output_dir="$2"
                    shift 2
                else
                    echo "错误: -o 选项需要一个目录参数"
                    return 1
                fi
                ;;
            *)
                commits+=("$1")
                shift
                ;;
        esac
    done

    # 验证 commit 参数数量
    if [[ ${#commits[@]} -eq 0 ]]; then
        show_help
        return 0
    elif [[ ${#commits[@]} -gt 2 ]]; then
        echo "错误: 最多支持指定两个 commit 参数。"
        show_help
        return 1
    fi

    # 确保在 Git 根目录下运行，以便 git diff 输出的路径与 cp 路径一致
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        echo "错误: 当前不在 Git 仓库中。"
        return 1
    fi

    # 如果没有指定输出目录，使用默认时间戳目录
    # 注意：如果路径是相对路径，需要考虑它是相对于当前目录还是 repo_root
    # 通常用户期望相对于当前执行目录。但我们后续会 pushd 到 repo_root。
    # 所以需要将 output_dir 转换为绝对路径。
    if [[ -z "$output_dir" ]]; then
        local timestamp=$(date +%Y-%m-%d_%H-%M-%S)
        # 默认路径我们假设是相对于当前执行位置，还是 repo root？
        # 根据 prompt "放到 ./path-files/date-str/ 下面"，通常指当前目录。
        # 我们可以直接使用绝对路径来避免混淆。
        output_dir="$(pwd)/path-files/${timestamp}"
    else
        # 转换为绝对路径
        if [[ "$output_dir" != /* && "$output_dir" != ?:* ]]; then
            output_dir="$(pwd)/$output_dir"
        fi
    fi

    echo "--------------------------------"
    echo "输出目录: $output_dir"
    
    # 切换到 Git 根目录
    pushd "$repo_root" > /dev/null

    # 获取变更文件列表
    local files_str=""
    if [[ ${#commits[@]} -eq 1 ]]; then
        echo "模式: 对比 commit '${commits[0]}' 与当前工作区"
        local diff_files=$(git diff --name-only "${commits[0]}" 2>/dev/null)
        local untracked_files=$(git ls-files --others --exclude-standard 2>/dev/null)
        
        files_str="${diff_files}"
        if [[ -n "$untracked_files" ]]; then
            if [[ -n "$files_str" ]]; then
                files_str="${files_str}"$'\n'"${untracked_files}"
            else
                files_str="${untracked_files}"
            fi
        fi
    else
        echo "模式: 对比 commit '${commits[0]}' 与 '${commits[1]}'"
        files_str=$(git diff --name-only "${commits[0]}" "${commits[1]}" 2>/dev/null)
    fi

    if [[ $? -ne 0 ]]; then
        echo "错误: git diff 执行失败，请检查 commit hash 是否正确。"
        popd > /dev/null
        return 1
    fi

    if [[ -z "$files_str" ]]; then
        echo "没有检测到文件变更。"
        popd > /dev/null
        return 0
    fi

    # 创建输出目录
    mkdir -p "$output_dir"

    # 遍历文件并复制
    local count=0
    # 使用 while read 处理可能包含空格的文件名
    echo "$files_str" | while read -r file; do
        # 移除可能的 Windows 回车符
        file=$(echo "$file" | tr -d '\r')
        
        if [[ -z "$file" ]]; then continue; fi
        
        # 检查文件在工作区是否存在
        if [[ -f "$file" ]]; then
            # 保持目录结构
            local target_path="${output_dir}/${file}"
            local target_dir=$(dirname "$target_path")
            
            mkdir -p "$target_dir"
            cp "$file" "$target_path"
            echo "已复制: $file"
            ((count++))
        else
            echo "跳过 (不存在): $file"
        fi
    done

    echo "--------------------------------"
    echo "操作完成。"
    
    popd > /dev/null
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
