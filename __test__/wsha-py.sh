#!/bin/bash
# wsha-py.sh — 测试包装脚本，将测试框架的调用转发给 Python 版本的 wsha
# 负责设置与 shell 版一致的环境变量，并处理 Git Bash 路径转换。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 设置应用环境变量（与 sh/wsha.sh 的 set_app_env 行为对齐）
export APP_HOME="$PROJECT_ROOT"
export APP_SH="$PROJECT_ROOT/sh"
export APP_CONFIG="$PROJECT_ROOT/sh/config"

# 将 Python 源码目录加入 PYTHONPATH，确保可直接导入 wsha 包
export PYTHONPATH="$PROJECT_ROOT/py${PYTHONPATH:+:$PYTHONPATH}"

# 辅助函数：将 Git Bash 路径转换为 Windows 路径
# Python 在 Windows 侧打开文件时，需要看到原生 Windows 路径
_to_win_path() {
    local input_path="$1"

    if command -v cygpath &>/dev/null; then
        cygpath -w "$input_path" 2>/dev/null || echo "$input_path"
    else
        echo "$input_path"
    fi
}

# 辅助函数：将路径转换为 Unix 风格，便于日志和调试展示
_to_unix_path() {
    local input_path="$1"

    if command -v cygpath &>/dev/null; then
        cygpath -u "$input_path" 2>/dev/null || echo "$input_path"
    else
        echo "$input_path"
    fi
}

# 处理单文件配置路径：保留显示路径，同时给 Python 使用 Windows 路径
if [[ -n "${WSHA_CONFIG_FILE:-}" ]]; then
    export WSHA_CONFIG_FILE_DISPLAY="$(_to_unix_path "$WSHA_CONFIG_FILE")"
    export WSHA_CONFIG_FILE="$(_to_win_path "$WSHA_CONFIG_FILE")"
fi

# 处理 HOME 路径：Windows Python 的 Path.home() 不能直接识别 Git Bash 风格路径
if [[ -n "${HOME:-}" ]]; then
    export WSHA_OVERRIDE_HOME="$(_to_win_path "$HOME")"
fi

# 保留约定字符串，便于测试/检查脚本结构：exec python3 -m wsha.cli
PYTHON_BIN="python3"
if ! command -v "$PYTHON_BIN" &>/dev/null || ! "$PYTHON_BIN" -V >/dev/null 2>&1; then
    PYTHON_BIN="python"
fi

exec "$PYTHON_BIN" -m wsha.cli "$@"
