#!/usr/bin/env python3
"""为 CMD 执行器传递无法安全嵌入 set 链的环境值，不解释配置内容。"""

import base64
import json
import os
import subprocess
import sys


def main() -> int:
    payload = json.loads(base64.b64decode(sys.argv[1]).decode("utf-8"))
    child_env = os.environ.copy()
    for name, value in payload["assignments"]:
        child_env[name] = value
    return subprocess.call(
        [os.environ.get("COMSPEC", "cmd.exe"), "/d", "/s", "/c", payload["command"]],
        env=child_env,
    )


if __name__ == "__main__":
    sys.exit(main())
