#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "[INFO] $1"
}

log_success() {
    echo -e "${GREEN}[PASS] $1${NC}"
}

log_fail() {
    echo -e "${RED}[FAIL] $1${NC}"
}

# 报告相关变量
BASE_DIR=$(cd "$(dirname "$0")" && pwd)
REPORT_DIR="$BASE_DIR/report"
TEST_RESULTS=()
PASS_COUNT=0
FAIL_COUNT=0

# 获取当前时间 (纳秒级如果支持，否则秒级)
current_time() {
    date +%s%N 2>/dev/null || date +%s000000000
}

# 计算耗时 (秒)
calc_duration() {
    local start=$1
    local end=$2
    # 使用 awk 计算浮点数差异，保留3位小数
    awk "BEGIN {printf \"%.3fs\", ($end - $start) / 1000000000}"
}

# 记录测试结果
record_test_result() {
    local name="$1"
    local result="$2"
    local duration="$3"
    local note="$4"
    
    # 格式: "| 测试用例 | 结果 | 耗时 | 备注 |"
    TEST_RESULTS+=("| $name | $result | $duration | $note |")
    
    if [[ "$result" == "PASS" ]]; then
        ((PASS_COUNT++))
    else
        ((FAIL_COUNT++))
    fi
}

# 生成测试报告
generate_report() {
    local script_name="$(basename "$0")"
    # 报告文件名: script_name.md (例如 ignore_workspace.test.sh -> ignore_workspace.test.md)
    # 规范要求: 文件名与测试脚本相同（但后缀为 .md）
    # 如果脚本名是 ignore_workspace.test.sh，那么报告名应该是 ignore_workspace.test.md
    local report_name="${script_name%.sh}.md"
    local report_file="$REPORT_DIR/$report_name"
    
    # 确保报告目录存在
    if [ ! -d "$REPORT_DIR" ]; then
        mkdir -p "$REPORT_DIR"
    fi
    
    log_info "正在生成测试报告: $report_file"
    
    {
        echo "# 测试报告: $script_name"
        echo ""
        echo "- **测试时间**: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "- **执行环境**: ${OS:-Windows_NT} (Git Bash)"
        echo ""
        echo "## 测试用例详情"
        echo ""
        echo "| 测试用例 | 结果 | 耗时 | 备注 |"
        echo "| :--- | :--- | :--- | :--- |"
        for row in "${TEST_RESULTS[@]}"; do
            echo "$row"
        done
        echo ""
        echo "## 统计汇总"
        echo "- **总计**: $((PASS_COUNT + FAIL_COUNT))"
        echo "- **通过**: $PASS_COUNT"
        echo "- **失败**: $FAIL_COUNT"
    } > "$report_file"
    
    log_info "测试报告已生成。"
}
