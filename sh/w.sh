#!/bin/bash

# w - wsha 的快捷入口，设置 WSHA_ENTRY=w 后调用 wsha.sh

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export WSHA_ENTRY="w"
exec bash "$SCRIPT_DIR/wsha.sh" 