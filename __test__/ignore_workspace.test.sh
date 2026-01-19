#!/bin/bash

# -----------------------------------------------------------------------------
# 测试脚本: ignore_workspace.test.sh
# 目的: 验证 ignore_workspace.sh 脚本能否正确停止 Git 追踪并添加 .gitignore
# 并生成测试报告到 __test__/report/ignore_workspace.test.md
# -----------------------------------------------------------------------------

# 配置
TEST_DIR="ignore_workspace_test_dir"
# 获取当前脚本所在目录的绝对路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
TARGET_SCRIPT="$SCRIPT_DIR/../sh/ignore_workspace.sh"
REPORT_DIR="$SCRIPT_DIR/report"
REPORT_FILE="$REPORT_DIR/ignore_workspace.test.md"

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# 确保报告目录存在
if [ ! -d "$REPORT_DIR" ]; then
    mkdir -p "$REPORT_DIR"
fi

# 初始化报告文件
{
    echo "# 测试报告: ignore_workspace.test.sh"
    echo "测试时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
} > "$REPORT_FILE"

# 辅助函数：打印章节标题
log_section() {
    echo -e "\n${YELLOW}[SECTION]${NC} $1"
    echo "" >> "$REPORT_FILE"
    echo "## $1" >> "$REPORT_FILE"
}

# 辅助函数：记录具体操作
log_op() {
    echo -e "  -> $1"
    echo "- $1" >> "$REPORT_FILE"
}

# 辅助函数：打印日志
log() {
    echo -e "${CYAN}[TEST]${NC} $1"
    echo "- **INFO**: $1" >> "$REPORT_FILE"
}

# 辅助函数：打印错误并退出
error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "- ❌ **FAIL**: $1" >> "$REPORT_FILE"
    exit 1
}

# 辅助函数：打印成功
success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    echo "- ✅ **PASS**: $1" >> "$REPORT_FILE"
}

# 检查目标脚本是否存在
if [ ! -f "$TARGET_SCRIPT" ]; then
    error "目标脚本未找到: $TARGET_SCRIPT"
fi
# 获取目标脚本的绝对路径，以便在 cd 后仍能调用
TARGET_SCRIPT_ABS=$(realpath "$TARGET_SCRIPT")

# 1. 环境准备
log_section "1. 环境准备"

log_op "清理旧的测试环境: $TEST_DIR"
if [ -d "$TEST_DIR" ]; then
    rm -rf "$TEST_DIR"
fi

log_op "创建测试目录并初始化 Git 仓库"
mkdir "$TEST_DIR"
cd "$TEST_DIR" || error "无法进入测试目录"

git init > /dev/null
git config user.email "test@example.com"
git config user.name "Test User"

log_op "创建测试文件 (file_to_ignore.txt) 和文件夹 (dir_to_ignore/file.txt)"
echo "content" > file_to_ignore.txt
mkdir dir_to_ignore
echo "content" > dir_to_ignore/file.txt

log_op "提交初始代码到 Git 仓库"
git add .
git commit -m "Initial commit" > /dev/null

log "环境准备完成。"

# -----------------------------------------------------------------------------
# 测试用例 1: 忽略单个文件
# -----------------------------------------------------------------------------
log_section "2. 测试用例 1: 忽略单个文件"

log_op "执行操作: 忽略 file_to_ignore.txt"
bash "$TARGET_SCRIPT_ABS" "file_to_ignore.txt"

log_op "验证: 检查文件是否还存在于磁盘"
if [ ! -f "file_to_ignore.txt" ]; then
    error "文件 'file_to_ignore.txt' 被错误地从磁盘删除了！"
else
    success "文件保留在磁盘"
fi

log_op "验证: 检查文件是否已从 Git 索引移除"
if git ls-files --error-unmatch "file_to_ignore.txt" &> /dev/null; then
    error "文件 'file_to_ignore.txt' 仍然在 Git 索引中 (未停止追踪)！"
else
    success "文件已从 Git 索引移除"
fi

log_op "验证: 检查 .gitignore 是否包含该文件"
if grep -q "file_to_ignore.txt" .gitignore; then
    success "文件已添加到 .gitignore"
else
    error "文件未在 .gitignore 中找到！"
fi

# -----------------------------------------------------------------------------
# 测试用例 2: 忽略文件夹
# -----------------------------------------------------------------------------
log_section "3. 测试用例 2: 忽略文件夹"

log_op "执行操作: 忽略 dir_to_ignore"
bash "$TARGET_SCRIPT_ABS" "dir_to_ignore"

log_op "验证: 检查文件夹是否还存在于磁盘"
if [ ! -d "dir_to_ignore" ]; then
    error "文件夹 'dir_to_ignore' 被错误地从磁盘删除了！"
else
    success "文件夹保留在磁盘"
fi

log_op "验证: 检查文件夹内容是否已从 Git 索引移除"
if git ls-files --error-unmatch "dir_to_ignore/file.txt" &> /dev/null; then
    error "文件夹内容仍然在 Git 索引中！"
else
    success "文件夹内容已从 Git 索引移除"
fi

log_op "验证: 检查 .gitignore 是否包含该文件夹"
if grep -q "dir_to_ignore" .gitignore; then
    success "文件夹已添加到 .gitignore"
else
    error "文件夹未在 .gitignore 中找到！"
fi

# -----------------------------------------------------------------------------
# 结束
# -----------------------------------------------------------------------------
log_section "4. 结束"

log_op "清理测试目录"
cd ..
rm -rf "$TEST_DIR"

log "所有测试通过！"
echo "" >> "$REPORT_FILE"
echo "**测试结果: ✅ 全部通过**" >> "$REPORT_FILE"

echo -e "\n${GREEN}测试报告已生成: $REPORT_FILE${NC}"
