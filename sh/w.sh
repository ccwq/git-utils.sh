#!/bin/bash

# w.sh 只是 wsha.sh 的语法糖入口：
# 仅注入入口名，然后把原始参数无损转发给统一实现。
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export WSHA_ENTRY="w"
exec bash "$SCRIPT_DIR/wsha.sh" "$@"
