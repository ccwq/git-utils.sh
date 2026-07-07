# 发现与决策

## 需求
- 修复 `w coyo --model gpt-5.4 "git-up -p"` 在 Windows wrapper 报 `-p""=="__WSHA_NOOP__" was unexpected at this time.` 的问题。
- 同时补充类似 `w coyo --model gpt-5.4 "$git-up -p"` / `git-up -p` 的回归测试，保证可用和参数正确。

## 调查发现
- `sh/config/wsh-alias/default.txt` 当前链路已迁移为：`coyo -> wsha codex-yo -> wsha codex-l --yolo $@ -> wsh npx -y @openai/codex@latest ...`。
- `sh/wsha.bat` 当前先调用 `wsha_core.py` 输出单行 `FINAL_CMD`，再执行最终命令。
- 当 `FINAL_CMD` 中包含双引号参数（例如 `"git-up -p"`）时，`if /i "%FINAL_CMD%"=="__WSHA_NOOP__"` 会破坏 CMD 引号结构。
- `sh/core/wsha_core.py` 已将 standalone `--` 释放给目标 CLI；`$@` 是运行时参数插入点。
- `sh/wsha.sh` 也通过 core 输出单行命令并 `eval` 执行；Unix 侧仍可依赖 shell quote，但语义应与 core 保持一致。
- `py/wsha/expand.py` 已同步 `$@` 插入点语义，并把 standalone `--` 当作目标 CLI 字面参数。

## 技术决策
| 决策 | 理由 |
|------|------|
| 默认 argv，复杂命令才降级字符串 | prompt、路径、自然语言指令中出现空格/引号/`-p` 是常态，不应由 shell/cmd 重解析。 |
| Python core 内递归展开 alias 链 | 减少 Windows batch/cmd 边界次数，降低 quote 风险。 |
| `$@` 表示用户剩余 argv 插入点 | 与 shell 习惯接近，同时释放 `--` 给目标 CLI。 |
| 立即破坏旧 `--` 插入点 | 用户确认接受 breaking change，避免长期双轨语义。 |
| Windows wrapper 仍需安全处理含引号 `FINAL_CMD` | 即使 core 内递归减少层数，最终命令仍可能包含带空格参数。 |

## 待验证假设
- 将 `codex-yo` 改为 `wsha codex-l --yolo $@` 后，`w coyo --model gpt-5.4 "git-up -p"` 展开为 `exec-git-bash.bat -lc "npx -y @openai/codex@latest --yolo --model gpt-5.4 'git-up -p'"`，不再触发 batch IF 引号错误。
- `w coyo --model gpt-5.4 "$git-up -p"` 展开为 `exec-git-bash.bat -lc "... '$git-up -p'"`，`$git-up` 通过单引号作为 prompt 字面量传给目标 CLI，不再被 Git Bash 展开成空字符串。

## 视觉/浏览器发现
- 不适用。本次 wrapper/CLI 设计修复没有使用浏览器或图片信息。
