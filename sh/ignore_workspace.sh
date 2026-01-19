#!/bin/bash

# 显示帮助信息的函数
show_help() {
    echo "使用方法: $0 [选项] <文件路径或Glob>"
    echo ""
    echo "该脚本用于停止 Git 对指定文件或文件夹的追踪，并将其添加到 .gitignore 中，同时不影响本地文件内容。"
    echo ""
    echo "参数:"
    echo "  文件路径或Glob    需要取消 Git 追踪的目标（例如：.obsidian/workspace.json 或 \"*.log\"）"
    echo ""
    echo "选项:"
    echo "  -h, --help       显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 .obsidian/workspace.json"
    echo "  $0 \"*.log\""
}


main() {
    # 如果没有参数，或者第一个参数是 -h 或 --help，则显示帮助
    if [ $# -eq 0 ] || [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        show_help
        return 0
    fi

    # 遍历所有传入的目标参数
    # 这里支持多个参数，或者单个包含 glob 的参数（建议加引号）
    for TARGET in "$@"; do
        echo "--------------------------------"
        echo "正在处理目标: $TARGET"

        # 1. 停止 Git 追踪
        # --cached: 只从索引中移除，保留工作区文件（不影响原来文件内容）
        # -r: 如果目标是目录，则递归处理
        # --ignore-unmatch: 如果文件没被追踪，也不报错
        git rm -r --cached --ignore-unmatch "$TARGET" 2>/dev/null
        
        # 检查上一个命令的执行状态
        if [ $? -eq 0 ]; then
            echo "状态: 已成功从 Git 索引中移除（本地文件已保留）。"
            
            # 2. 将目标添加到 .gitignore（如果尚未添加）
            # 确保 .gitignore 存在，避免读取报错
            touch .gitignore

            # 使用 tr -d '\r' 处理可能的 Windows 换行符，确保匹配准确
            if ! grep -qxF "$TARGET" <(tr -d '\r' < .gitignore) 2>/dev/null; then
                echo "状态: 正在将 '$TARGET' 添加到 .gitignore..."
                echo "$TARGET" >> .gitignore
            else
                echo "状态: '$TARGET' 已经存在于 .gitignore 中，跳过添加。"
            fi
        else
            echo "状态: 无法处理 '$TARGET'。请确保路径正确且当前处于 Git 仓库中。"
        fi
    done

    echo "--------------------------------"
    echo "所有操作已完成！"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
