#!/bin/bash

# 显示帮助信息的函数
show_help() {
    echo "使用方法: $0 [选项] [commit1] [commit2]"
    echo ""
    echo "该脚本用于基于 Git 提交记录提取变更文件，并将工作区中的最新版本复制到指定目录。"
    echo ""
    echo "参数:"
    echo "  commit1          Git 提交哈希值(ex: head~1 或 1234567, breach1name)。"
    echo "                   - 如果仅提供 commit1:对比该提交与当前工作区。"
    echo "                   - 如果提供 commit1 和 commit2:对比这两个提交。"
    echo "  commit2          Git 提交哈希值（可选）。"
    echo ""
    echo "选项:"
    echo "  -h, --help       [可选]显示此帮助信息"
    echo "  -o, --output     [可选]指定输出目录 (默认: ./patch-files/YYYY-MM-DD_HH-MM-SS/)"
    echo "  -i, --input      [可选]指定检查目录, 只包含该目录下的文件, 其他文件不处理, 支持多个目录,逗号分割, 支持glob (默认: ./)"
    echo "                   以 repo 根目录为基准, 大小写敏感"
    echo "  -e, --exclude    [可选]指定排除目录, 不包含该目录下的文件, 其他文件不处理, 支持多个目录,逗号分割, 支持glob (默认: 无)"
    echo "                   以 repo 根目录为基准, 大小写敏感"
    echo ""
    echo "示例:"
    echo "  $0 head #抽取当前未提交的内容" 
    echo "  $0 head -i ./notes #只抽取和 ./notes 目录下的文件"
    echo "  $0 head -i ./notes,src -e ./notes/tmp #抽取 notes 与 src, 排除 notes/tmp"
    echo "  $0 head~3 #第3(时间逆序)个提交和当前工作区的差异"
    echo "  $0 c0ccf16d39d229954023921efecf18fb5adc025c #指定提交和当前工作区的差异"
    echo "  $0 c0ccf1 #使用提交id的缩写"
    echo "  $0 HEAD~5 HEAD~2 -o ./my-patch #第5个提交和第2个提交的差异，放到 ./my-patch/ 下面" 
}

# 去掉字符串首尾空白
trim_whitespace() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    echo "$value"
}

# 规范化匹配模式，统一基于 repo 根目录
normalize_pattern() {
    local pattern="$1"
    pattern="${pattern#./}"
    pattern="${pattern#/}"
    pattern="${pattern%/}"
    if [[ "$pattern" == "." ]]; then
        pattern=""
    fi
    echo "$pattern"
}

# 解析逗号分割的模式列表，追加到目标数组
parse_patterns() {
    local pattern_list="$1"
    local -n target_array="$2"
    local item=""

    IFS=',' read -ra pattern_items <<< "$pattern_list"
    for item in "${pattern_items[@]}"; do
        item=$(echo "$item" | tr -d '\r')
        item=$(trim_whitespace "$item")
        item=$(normalize_pattern "$item")
        if [[ -n "$item" ]]; then
            target_array+=("$item")
        fi
    done
}

# 判断模式是否包含 glob 元字符
has_glob() {
    case "$1" in
        *[\*\?\[]* ) return 0 ;;
        * ) return 1 ;;
    esac
}

# 检查文件路径是否匹配指定模式
match_pattern() {
    local file_path="$1"
    local pattern="$2"

    if has_glob "$pattern"; then
        [[ "$file_path" == $pattern ]]
        return $?
    fi

    [[ "$file_path" == "$pattern" || "$file_path" == "$pattern/"* ]]
}

# 判断文件是否在模式列表中命中
match_any_pattern() {
    local file_path="$1"
    local -n patterns="$2"
    local pattern=""

    for pattern in "${patterns[@]}"; do
        if match_pattern "$file_path" "$pattern"; then
            return 0
        fi
    done
    return 1
}

# 根据 input 与 exclude 规则判断是否纳入
should_include_file() {
    local file_path="$1"
    local -n input_patterns_ref="$2"
    local -n exclude_patterns_ref="$3"

    if [[ ${#input_patterns_ref[@]} -gt 0 ]]; then
        if ! match_any_pattern "$file_path" input_patterns_ref; then
            return 1
        fi
    fi

    if [[ ${#exclude_patterns_ref[@]} -gt 0 ]]; then
        if match_any_pattern "$file_path" exclude_patterns_ref; then
            return 1
        fi
    fi

    return 0
}

main() {
    local output_dir=""
    local commits=()
    local default_output_base="./patch-files"
    local -a input_patterns=()
    local -a exclude_patterns=()

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
            -i|--input)
                if [[ -n "$2" && "$2" != -* ]]; then
                    parse_patterns "$2" input_patterns
                    shift 2
                else
                    echo "错误: -i 选项需要一个目录参数"
                    return 1
                fi
                ;;
            -e|--exclude)
                if [[ -n "$2" && "$2" != -* ]]; then
                    parse_patterns "$2" exclude_patterns
                    shift 2
                else
                    echo "错误: -e 选项需要一个目录参数"
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
        # 根据 prompt "放到 ./patch-files/date-str/ 下面"，通常指当前目录。
        # 我们可以直接使用绝对路径来避免混淆。
        output_dir="$(pwd)/patch-files/${timestamp}"
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
        if ! should_include_file "$file" input_patterns exclude_patterns; then
            continue
        fi
        
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
