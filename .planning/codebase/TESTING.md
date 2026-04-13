# 测试模式

**分析日期:** 2026-04-13

## 测试框架

**框架:** ShellSpec（文档中引用）
- 位置: `.vendor/shellspec/shellspec`（子模块）
- 配置: `.shellspec` 文件
- 通过 `sh\exec-git-bash.bat .\.vendor\shellspec\shellspec` 替代入口

**运行命令:**
```bash
# 在 Git Bash 中直接使用 shellspec
./.vendor/shellspec/shellspec

# 使用 Windows batch 入口
sh\exec-git-bash.bat .\.vendor\shellspec\shellspec

# 使用 npm（配置在 package.json）
npm test

# 旧版测试运行器
./test-all.sh
```

## 测试文件组织

**位置:** `__test__/` 目录

**命名约定:**
- 主要模式: `*_test.sh`（如 `wsh-real-ignore_test.sh`）
- 替代模式: `*.test.sh`（如 `wsh.test.sh`, `wsha.test.sh`）

**目录结构:**
```
__test__/
├── test_utils.sh           # 共享测试工具
├── report/                 # 生成的测试报告
│   └── *.md               # 每个测试的 Markdown 报告
├── test_playground/        # 共享沙盒目录
├── wsh-real-ignore_test.sh
├── wsha.test.sh
├── wsh.test.sh
├── wsh-fpatch_test.sh
└── init.test.sh
```

## 测试工具

**共享库:** `__test__/test_utils.sh`

**提供的函数:**
```bash
# 颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 日志
log_info() { echo -e "[INFO] $1"; }
log_success() { echo -e "${GREEN}[PASS] $1${NC}"; }
log_fail() { echo -e "${RED}[FAIL] $1${NC}"; }

# 计时
current_time()    # 返回纳秒（或秒回退）
calc_duration()   # 计算持续时间（3 位小数）

# 测试结果跟踪
record_test_result()  # 记录测试名称、结果、耗时、备注
PASS_COUNT            # 全局通过计数器
FAIL_COUNT            # 全局失败计数器

# 报告生成
generate_report()     # 生成 Markdown 报告到 report/
```

## 测试结构模式

**标准测试模板:**
```bash
#!/bin/bash

source "$(dirname "$0")/test_utils.sh"

BASE_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$BASE_DIR/.." && pwd)
SCRIPT_TO_TEST="$PROJECT_ROOT/sh/script_name.sh"
TEST_DIR="$PROJECT_ROOT/test_playground"

# Setup 函数 - 初始化测试环境
setup() {
    log_info "正在设置测试环境..."
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR" || exit 1
    
    # 初始化测试用 git 仓库
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    log_info "测试环境已准备就绪: $TEST_DIR"
}

# Cleanup 函数 - 移除测试产物
cleanup() {
    log_info "正在清理测试环境..."
    cd "$PROJECT_ROOT" || exit 1
    rm -rf "$TEST_DIR"
}

# 单个测试函数
test_example_case() {
    local start_time end_time duration result note
    start_time=$(current_time)
    result="FAIL"
    note=""
    
    # 运行被测试的脚本
    bash "$SCRIPT_TO_TEST" arg1 arg2 > /dev/null 2>&1
    
    # 断言
    if [[ $run_code -eq 0 ]] && [[ "$output" == *"expected"* ]]; then
        result="PASS"
        log_success "测试名称通过"
    else
        note="actual output=[$output]"
        log_fail "$note"
    fi
    
    end_time=$(current_time)
    duration=$(calc_duration "$start_time" "$end_time")
    record_test_result "test_example_case" "$result" "$duration" "$note"
}

# 主协调器
main() {
    setup
    
    test_example_case
    test_another_case
    
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
```

## 测试模式: Windows 脚本测试

测试 Windows batch 文件:
```bash
SCRIPT_WIN=""

setup() {
    SCRIPT_WIN=$(cygpath -am "$SCRIPT_TO_TEST")
}

run_wsh() {
    output=$(cmd.exe //c "$SCRIPT_WIN" "$@" 2>&1)
    run_code=$?
    output=$(printf "%s" "$output" | tr -d '\r')
}
```

## 测试模式: 基于配置的测试

某些测试使用配置文件:
```bash
write_config() {
    local file_path="$1"
    local mode="$2"
    
    if [[ "$mode" == "normal" ]]; then
        cat > "$file_path" <<'EOF'
ab echo agent-browser
foo echo foobar open
EOF
    elif [[ "$mode" == "quoted_wildcard" ]]; then
        cat > "$file_path" <<'EOF'
pcodex echo codex-default
"pcodex l" echo codex-last
EOF
    fi
}

run_wsha() {
    local config_file="$1"
    shift
    
    raw_output=$(WSHA_CONFIG_FILE="$config_file" bash "$SCRIPT_TO_TEST" "$@" 2>&1)
    run_code=$?
    output=$(printf "%s" "$raw_output" | tr -d '\r')
}
```

## 测试模式: 输出清理

对于产生时间相关输出的测试:
```bash
strip_time_logs() {
    printf "%s" "$1" | awk '
        BEGIN {
            esc = sprintf("%c", 27)
        }
        {
            gsub(esc "\\[[0-9;]*[A-Za-z]", "")
            if ($0 ~ /^\[wsha\]\[time\] /) next
            print
        }
    '
}
```

## 测试模式: 沙盒化 Git 仓库

```bash
setup() {
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR" || exit 1
    
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    # 创建初始提交
    touch README.md
    git add README.md
    git commit -m "Initial commit" -q
}
```

## 断言

**常用断言模式:**
```bash
# 检查退出码
if [[ $run_code -eq 0 ]]; then ...

# 检查输出包含字符串
if [[ "$output" == *"expected"* ]]; then ...

# 检查输出等于确切字符串
if [[ "$output" == "expected" ]]; then ...

# 检查文件存在
if [[ -f "$target_file" ]]; then ...

# 检查文件在 git 索引中
if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then ...

# 检查字符串在文件中
if grep -qxF "$target" .gitignore; then ...
```

## 测试报告格式

报告以 Markdown 文件形式生成在 `__test__/report/`:

```markdown
# 测试报告: script_name.test.sh

- **测试时间**: 2026-04-13 10:30:00
- **执行环境**: Windows_NT (Git Bash)

## 测试用例详情

| 测试用例 | 结果 | 耗时 | 备注 |
| :--- | :--- | :--- | :--- |
| test_name | PASS | 0.123s | 正常 |

## 统计汇总
- **总计**: 5
- **通过**: 5
- **失败**: 0
```

## Mocking

**没有使用正式的 mocking 框架。** 测试通常:
- 在隔离目录中执行脚本
- 使用临时 git 仓库
- 设置环境变量进行配置
- 验证实际输出和副作用

## Fixtures 和测试数据

**内联 fixtures:** 测试数据在使用 heredoc 的测试函数内创建:
```bash
cat > "$TEST_DIR/init-state.env" <<EOF
Path=C:\\Tools
CLINK_PATH=C:\\Other\\Clink
EOF
```

**基于文件的 fixtures:** 在测试目录中创建的配置文件:
```bash
write_config "$config_file" "normal"
```

## 覆盖率

**目前没有使用覆盖率工具。** 项目依赖:
- 手动测试执行
- 在 `__test__/report/` 生成的测试报告
- 验证端到端功能的集成测试

## 常见测试模式总结

| 模式 | 描述 |
|---------|-------------|
| `setup/cleanup` | 环境初始化和清理 |
| `current_time/calc_duration` | 计时测量 |
| `record_test_result` | 测试结果跟踪 |
| `generate_report` | Markdown 报告生成 |
| `bash "$SCRIPT"` | 脚本调用 |
| `strip_time_logs` | 输出规范化 |
| `cygpath` | Windows 路径转换 |
| `cmd.exe //c` | Windows 命令执行 |

---

*测试分析: 2026-04-13*
