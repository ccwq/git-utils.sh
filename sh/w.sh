#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export WSHA_ENTRY="w"
exec python "$SCRIPT_DIR/wsha-core.py" -e w "$@" 