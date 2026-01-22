#!/bin/bash

# Git Utils Script - Replace Chinese Punctuation
# 此脚本用于将文件中的中文标点符号替换为英文标点符号

# 帮助信息函数
# 显示脚本的使用方法和说明
show_help() {
    echo "使用方法: $0 [文件或通配符...]"
    echo ""
    echo "说明:"
    echo "  该脚本将指定文件中的中文标点符号替换为对应的英文标点符号。"
    echo "  支持传入多个文件或使用通配符 (例如: *.txt, src/*.md)。"
    echo ""
    echo "选项:"
    echo "  -h, --help    显示此帮助信息并退出"
    echo ""
    echo "替换列表:"
    echo "  ， -> ,    。 -> .    ！ -> !    ？ -> ?"
    echo "  ： -> :    ； -> ;    “ ” -> \"    ‘ ’ -> '"
    echo "  （ ） -> ( )  【 】 -> [ ]  《 》 -> < >  、 -> ,"
}

# 处理单个文件
# 参数: $1 - 文件路径
#       $2 - sed 命令前缀数组 (通过引用传递，但在 bash 中通常传名字或重新构造)
# 注意：数组传递在 bash 中较繁琐，这里我们简化处理，将 sed 命令逻辑放在循环内或使用全局/上层定义的数组
process_file() {
    local file="$1"
    # 这里的 "${sed_cmd[@]}" 依赖于父作用域的变量，或者我们需要重新判断
    # 为保持函数纯度，我们可以传入 sed 命令的方式。
    # 但由于 bash 传递数组复杂，这里我们假设 sed_cmd 是在 main 中定义并可见的 (local 变量对子函数可见)
    
    if [ -f "$file" ]; then
        # 使用 sed 进行批量替换
        "${sed_cmd[@]}" \
            -e 's/，/,/g' \
            -e 's/。/./g' \
            -e 's/！/!/g' \
            -e 's/？/?/g' \
            -e 's/：/:/g' \
            -e 's/；/;/g' \
            -e 's/“/"/g' \
            -e 's/”/"/g' \
            -e 's/‘/'\''/g' \
            -e 's/’/'\''/g' \
            -e 's/（/(/g' \
            -e 's/）/)/g' \
            -e 's/【/[/g' \
            -e 's/】/]/g' \
            -e 's/《/</g' \
            -e 's/》/>/g' \
            -e 's/、/,/g' \
            "$file"
        echo "[INFO] 已处理: $file"
        return 0
    else
        echo "[WARN] 跳过不存在的文件 '$file'" >&2
        return 1
    fi
}

# 主函数
main() {
    # 检查参数
    if [ "$#" -eq 0 ] || [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        show_help
        exit 0
    fi

    echo "--------------------------------"
    echo "[INFO] 开始执行标点符号替换任务..."

    # 检查 sed 是否支持 -i (GNU sed 常见于 Linux/Git Bash)
    # macOS 的 sed -i 需要空的扩展名参数
    # 使用数组来正确处理空字符串参数
    local sed_cmd
    if sed --version >/dev/null 2>&1; then
        sed_cmd=(sed -i)
    else
        sed_cmd=(sed -i '')
    fi

    local count=0
    
    # 遍历所有传入的文件参数
    for file in "$@"; do
        if process_file "$file"; then
            ((count++))
        fi
    done

    echo "--------------------------------"
    echo "[INFO] 任务完成，共处理 $count 个文件。"
}

# 入口守卫
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
