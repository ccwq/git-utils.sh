# Coding Conventions

**Analysis Date:** 2026-04-13

## Project Overview

This is a shell/bash script project containing Git utilities for Windows Git Bash, Linux, and macOS. Scripts are written in bash with some Windows batch files (.bat) for Windows integration.

## Shell Script Standards

**Shebang:**
- Use `#!/bin/bash` for bash scripts
- Windows batch files use `.bat` extension and CMD syntax

**File Naming:**
- Shell scripts: `*.sh` (e.g., `wsh-real-ignore.sh`, `wsha.sh`)
- Windows batch: `*.bat` (e.g., `wsh.bat`, `wsha.bat`)
- Test files: `*_test.sh` or `*.test.sh` in `__test__/` directory

## Code Style

**Formatting:**
- Indentation: 4 spaces (not tabs)
- Lines should not exceed 120 characters
- Use blank lines to separate logical sections
- Commands followed by Chinese comments for explanation

**Comments:**
```bash
# 这是单行注释，用于解释代码逻辑
# 函数用途说明使用中文
```

**Variable Naming:**
- Constants: UPPERCASE (e.g., `GREEN`, `NC`)
- Regular variables: lowercase with underscores (e.g., `target_file`, `output_dir`)
- Temporary variables: prefixed with underscore or descriptive names (e.g., `_CMD_TOKENS`)
- Array variables: plural or descriptive names (e.g., `input_patterns`, `exclude_patterns`)

## Function Design

**Standard Script Structure:**
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

**Function Patterns:**
- Use `local` for function-local variables
- Return codes: 0 for success, non-zero for failure
- Use `local var=$(...)` pattern for command substitution
- Pass arguments by position (`$1`, `$2`, etc.)

## Error Handling

**Return Code Checking:**
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

**Error Messages:**
```bash
echo "错误: -o 选项需要一个目录参数" >&2
return 1
```

**Suppress Errors When Appropriate:**
```bash
# 2>/dev/null suppresses stderr
git rm -r --cached --ignore-unmatch "$TARGET" 2>/dev/null

# /dev/null suppresses both stdout and stderr
pushd "$repo_root" > /dev/null
```

## String Handling

**Quoting:**
- Always quote variables containing paths or user input: `"$variable"`
- Use single quotes for literal strings that should not expand
- Use double quotes for strings with variable expansion

**Parameter Expansion:**
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

**Windows Line Ending Handling:**
```bash
# 移除 Windows 回车符
file=$(echo "$file" | tr -d '\r')

# 在 grep 检查时处理
if ! grep -qxF "$TARGET" <(tr -d '\r' < .gitignore) 2>/dev/null; then
    ...
fi
```

## Logging and Output

**Color Variables (defined in test_utils.sh and some scripts):**
```bash
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
```

**Logging Functions:**
```bash
log_info() { echo -e "[INFO] $1"; }
log_success() { echo -e "${GREEN}[PASS] $1${NC}"; }
log_fail() { echo -e "${RED}[FAIL] $1${NC}"; }
```

## Path Handling

**Cross-Platform Path Conversion:**
```bash
# Windows 下使用 cygpath 转换路径
SCRIPT_WIN=$(cygpath -am "$SCRIPT_TO_TEST")  # absolute Unix path
SCRIPT_WIN=$(cygpath -aw "$SCRIPT_TO_TEST")  # absolute Windows path
```

**Path Normalization:**
```bash
# 移除 ./ 和 / 前缀
pattern="${pattern#./}"
pattern="${pattern#/}"
pattern="${pattern%/}"
```

## Import and Include Patterns

**Test Utilities:**
```bash
# 从相对路径加载共享工具
source "$(dirname "$0")/test_utils.sh"
```

**Environment Variables for Configuration:**
```bash
# 通过环境变量传递配置
WSHA_CONFIG_FILE="$config_file" bash "$SCRIPT_TO_TEST" "$@"
```

## Pattern: Argument Parsing

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

## Pattern: Array Handling

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

## Pattern: Command Output Capture

```bash
# 捕获命令输出
output=$(command 2>&1)
run_code=$?

# 移除 Windows 回车符
output=$(printf "%s" "$output" | tr -d '\r')
```

## Shell Compatibility

**Target Environment:**
- Primary: Git Bash on Windows (bash 4.x)
- Also supports: Linux, macOS, WSL

**Portable sed Detection:**
```bash
if sed --version >/dev/null 2>&; then
    sed_cmd=(sed -i)
else
    sed_cmd=(sed -i '')
fi
```

---

*Convention analysis: 2026-04-13*
