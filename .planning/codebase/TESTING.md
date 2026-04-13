# Testing Patterns

**Analysis Date:** 2026-04-13

## Test Framework

**Framework:** ShellSpec (referenced in documentation)
- Location: `.vendor/shellspec/shellspec` (submodule)
- Configuration: `.shellspec` file
- Alternative entry via `sh\exec-git-bash.bat .\.vendor\shellspec\shellspec`

**Run Commands:**
```bash
# Using shellspec directly (in Git Bash)
./.vendor/shellspec/shellspec

# Using Windows batch entry
sh\exec-git-bash.bat .\.vendor\shellspec\shellspec

# Using npm (configured in package.json)
npm test

# Legacy test runner
./test-all.sh
```

## Test File Organization

**Location:** `__test__/` directory

**Naming Convention:**
- Main pattern: `*_test.sh` (e.g., `wsh-real-ignore_test.sh`)
- Alternative: `*.test.sh` (e.g., `wsh.test.sh`, `wsha.test.sh`)

**Directory Structure:**
```
__test__/
├── test_utils.sh           # Shared test utilities
├── report/                 # Generated test reports
│   └── *.md               # Markdown reports per test
├── test_playground/        # Shared sandbox directory
├── wsh-real-ignore_test.sh
├── wsha.test.sh
├── wsh.test.sh
├── wsh-fpatch_test.sh
└── init.test.sh
```

## Test Utilities

**Shared Library:** `__test__/test_utils.sh`

**Provided Functions:**
```bash
# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Logging
log_info() { echo -e "[INFO] $1"; }
log_success() { echo -e "${GREEN}[PASS] $1${NC}"; }
log_fail() { echo -e "${RED}[FAIL] $1${NC}"; }

# Timing
current_time()    # Returns nanoseconds (or seconds fallback)
calc_duration()   # Calculates duration in seconds (3 decimal places)

# Test result tracking
record_test_result()  # Records test name, result, duration, note
PASS_COUNT            # Global pass counter
FAIL_COUNT            # Global fail counter

# Report generation
generate_report()     # Generates Markdown report to report/
```

## Test Structure Pattern

**Standard Test Template:**
```bash
#!/bin/bash

source "$(dirname "$0")/test_utils.sh"

BASE_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$BASE_DIR/.." && pwd)
SCRIPT_TO_TEST="$PROJECT_ROOT/sh/script_name.sh"
TEST_DIR="$PROJECT_ROOT/test_playground"

# Setup function - initializes test environment
setup() {
    log_info "正在设置测试环境..."
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR" || exit 1
    
    # Initialize git repo for testing
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    log_info "测试环境已准备就绪: $TEST_DIR"
}

# Cleanup function - removes test artifacts
cleanup() {
    log_info "正在清理测试环境..."
    cd "$PROJECT_ROOT" || exit 1
    rm -rf "$TEST_DIR"
}

# Individual test functions
test_example_case() {
    local start_time end_time duration result note
    start_time=$(current_time)
    result="FAIL"
    note=""
    
    # Run the script being tested
    bash "$SCRIPT_TO_TEST" arg1 arg2 > /dev/null 2>&1
    
    # Assertions
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

# Main orchestrator
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

## Test Pattern: Windows Script Testing

For testing Windows batch files:

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

## Test Pattern: Config-Based Tests

Some tests use configuration files:

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

## Test Pattern: Output Cleaning

For tests that produce time-varying output:

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

## Test Pattern: Sandboxed Git Repository

```bash
setup() {
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR" || exit 1
    
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    # Create initial commit
    touch README.md
    git add README.md
    git commit -m "Initial commit" -q
}
```

## Assertions

**Common Assertion Patterns:**
```bash
# Check exit code
if [[ $run_code -eq 0 ]]; then ...

# Check output contains string
if [[ "$output" == *"expected"* ]]; then ...

# Check output equals exact string
if [[ "$output" == "expected" ]]; then ...

# Check file exists
if [[ -f "$target_file" ]]; then ...

# Check file in git index
if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then ...

# Check string in file
if grep -qxF "$target" .gitignore; then ...
```

## Test Report Format

Reports are generated as Markdown files in `__test__/report/`:

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

**No formal mocking framework is used.** Tests typically:
- Execute scripts in isolated directories
- Use temporary git repositories
- Set environment variables for configuration
- Verify actual output and side effects

## Fixtures and Test Data

**Inline fixtures:** Test data is created within test functions using heredocs:
```bash
cat > "$TEST_DIR/init-state.env" <<EOF
Path=C:\\Tools
CLINK_PATH=C:\\Other\\Clink
EOF
```

**File-based fixtures:** Configuration files created in test directories:
```bash
write_config "$config_file" "normal"
```

## Coverage

**No coverage tool is currently used.** The project relies on:
- Manual test execution
- Test reports generated in `__test__/report/`
- Integration tests that verify end-to-end functionality

## Common Test Patterns Summary

| Pattern | Description |
|---------|-------------|
| `setup/cleanup` | Environment initialization and cleanup |
| `current_time/calc_duration` | Timing measurement |
| `record_test_result` | Test result tracking |
| `generate_report` | Markdown report generation |
| `bash "$SCRIPT"` | Script invocation |
| `strip_time_logs` | Output normalization |
| `cygpath` | Windows path conversion |
| `cmd.exe //c` | Windows command execution |

---

*Testing analysis: 2026-04-13*
