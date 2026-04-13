# 编码规范

**分析日期:** 2026-04-13

## 项目概述

这是一个包含 Windows Git Bash、Linux 和 macOS Git 实用工具的 shell/bash 脚本项目。脚本使用 bash 编写，部分 Windows 批处理文件（.bat）用于 Windows 集成。

## Shell 脚本标准

**Shebang:**
- Bash 脚本使用 `#!/bin/bash`
- Windows batch 文件使用 `.bat` 扩展名和 CMD 语法

**文件命名:**
- Shell 脚本: `*.sh`（如 `wsh-real-ignore.sh`, `wsha.sh`）
- Windows batch: `*.bat`（如 `wsh.bat`, `wsha.bat`）
- 测试文件: `__test__/` 目录中的 `*_test.sh` 或 `*.test.sh`

## 代码风格

**格式化:**
- 缩进: 4 个空格（不是 Tab）
- 行不应超过 120 个字符
- 使用空行分隔逻辑部分
- 命令后跟中文注释进行解释

**注释:**
```bash
# 这是单行注释，用于解释代码逻辑
# 函数用途说明使用中文
```

**变量命名:**
- 常量: 大写（如 `GREEN`, `NC`）
- 常规变量: 小写加下划线（如 `target_file`, `output_dir`）
- 临时变量: 带下划线前缀或描述性名称（如 `_CMD_TOKENS`）
- 数组变量: 复数或描述性名称（如 `input_patterns`, `exclude_patterns`）

## 函数设计

**标准脚本结构:**
```bash
#!/bin/bash

# 显示帮助信息的函数
show_help() {
    echo "使用方法: $0 [选项] <参数>"
    echo "..."
}

# 主函数
main() {
    # 参数检查
    if [ $# -eq 0 ] || [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        show_help
        return 0
    fi
    
    # 业务逻辑
    ...
}

# 入口守卫 - 确保脚本被直接执行时才调用 main
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

**函数模式:**
- 函数局部变量使用 `local`
- 返回码: 0 表示成功，非零表示失败
- 使用 `local var=$(...)` 模式进行命令替换
- 按位置传递参数 (`$1`, `$2` 等)

## 错误处理

**返回码检查:**
```bash
# 检查上一个命令执行状态
if [ $? -eq 0 ]; then
    # success
else
    # failure
fi

# 或使用 if 直接检查
if git rm -r --cached "$TARGET" 2>/dev/null; then
    # success
fi
```

**错误消息:**
```bash
echo "错误: -o 选项需要一个目录参数" >&2
return 1
```

**适当时候抑制错误:**
```bash
# 2>/dev/null 抑制 stderr
git rm -r --cached --ignore-unmatch "$TARGET" 2>/dev/null

# /dev/null 抑制 stdout 和 stderr
pushd "$repo_root" > /dev/null
```

## 字符串处理

**引号:**
- 包含路径或用户输入的变量始终加引号: `"$variable"`
- 不应展开的字符串使用单引号
- 有变量展开的字符串使用双引号

**参数展开:**
```bash
# 去除首尾空白
value="${value#"${value%%[![:space:]]*}"}"
value="${value%"${value##*[![:space:]]}"}"

# 去除路径前缀
token="${token##*\\}"
token="${token##*/}"

# 小写转换
printf '%s' "${token,,}"
```

**Windows 行尾处理:**
```bash
# 移除 Windows 回车符
file=$(echo "$file" | tr -d '\r')

# 在 grep 检查时处理
if ! grep -qxF "$TARGET" <(tr -d '\r' < .gitignore) 2>/dev/null; then
    ...
fi
```

## 日志和输出

**颜色变量（定义在 test_utils.sh 和某些脚本中）:**
```bash
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
```

**日志函数:**
```bash
log_info() { echo -e "[INFO] $1"; }
log_success() { echo -e "${GREEN}[PASS] $1${NC}"; }
log_fail() { echo -e "${RED}[FAIL] $1${NC}"; }
```

## 路径处理

**跨平台路径转换:**
```bash
# Windows 下使用 cygpath 转换路径
SCRIPT_WIN=$(cygpath -am "$SCRIPT_TO_TEST")  # 绝对 Unix 路径
SCRIPT_WIN=$(cygpath -aw "$SCRIPT_TO_TEST")  # 绝对 Windows 路径
```

**路径规范化:**
```bash
# 移除 ./ 和 / 前缀
pattern="${pattern#./}"
pattern="${pattern#/}"
pattern="${pattern%/}"
```

## 导入和包含模式

**测试工具:**
```bash
# 从相对路径加载共享工具
source "$(dirname "$0")/test_utils.sh"
```

**环境变量配置:**
```bash
# 通过环境变量传递配置
WSHA_CONFIG_FILE="$config_file" bash "$SCRIPT_TO_TEST" "$@"
```

## 模式: 参数解析

```bash
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
                echo "错误: -o 选项需要一个目录参数" >&2
                return 1
            fi
            ;;
        *)
            commits+=("$1")
            shift
            ;;
    esac
done
```

## 模式: 数组处理

```bash
# 声明关联数组引用
local -n target_array="$2"

# 遍历数组
for item in "${pattern_items[@]}"; do
    ...
done

# 追加元素
target_array+=("$item")

# 检查数组长度
if [[ ${#input_patterns_ref[@]} -gt 0 ]]; then
    ...
fi
```

## 模式: 命令输出捕获

```bash
# 捕获命令输出
output=$(command 2>&1)
run_code=$?

# 移除 Windows 回车符
output=$(printf "%s" "$output" | tr -d '\r')
```

## Shell 兼容性

**目标环境:**
- 主要: Windows Git Bash (bash 4.x)
- 也支持: Linux, macOS, WSL

**便携式 sed 检测:**
```bash
if sed --version >/dev/null 2>&; then
    sed_cmd=(sed -i)
else
    sed_cmd=(sed -i '')
fi
```

---

*规范分析: 2026-04-13*
