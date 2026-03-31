# 测试报告: wsha.test.sh

- **测试时间**: 2026-03-31 17:59:58
- **执行环境**: Windows_NT (Git Bash)

## 测试用例详情

| 测试用例 | 结果 | 耗时 | 备注 |
| :--- | :--- | :--- | :--- |
| test_expand_ab | PASS | 1.599s |  |
| test_expand_foo_append | PASS | 1.542s |  |
| test_expand_bar_placeholder | PASS | 1.528s |  |
| test_unknown_alias_passthrough_with_args | PASS | 1.459s |  |
| test_unknown_alias_ping_passthrough | PASS | 1.496s |  |
| test_quoted_alias_expand | PASS | 1.551s |  |
| test_quoted_complex_command_passthrough | PASS | 1.461s |  |
| test_quoted_and_chain_passthrough | PASS | 1.519s |  |
| test_unknown_command_passthrough_error_code | PASS | 1.477s |  |
| test_list_long_flag | PASS | 1.254s |  |
| test_list_short_flag | PASS | 1.202s |  |
| test_list_view_flag | PASS | 1.301s |  |
| test_duplicate_alias | PASS | 0.938s |  |
| test_invalid_mapping | PASS | 0.850s |  |
| test_default_merge_priority | PASS | 26.307s |  |
| test_default_missing_optional_configs_ignored | PASS | 9.113s |  |
| test_default_list_merged_aliases | FAIL | 8.717s | output=[[内置] /e/project/self.project/git-utils.sh/config/wsh-alias.txt

别名              命令
----                ----
fox                 firefox
box                 killbox
ev:edit             echo %EDITOR%
--update            cd /d %APP_HOME% && git pull
-u                  wsha --update
--open              start code %APP_HOME%
--lazygit           cd /d %APP_HOME% && lazygit
-lgit               wsha --lazygit
--edit-config       code %APP_CONFIG%/wsh-alias.txt
-ec                 wsha --edit-config
--edit-config-user  code %USERPROFILE%/.config/wsh-alias.txt
-ecu                wsha --edit-config-user
docker              podman
dc                  wsha docker compose
pc                  podman compose
abc                 wsha ab --cdp 9222
abcc                wsha ab --cdp %CDPORT%
ab-p                pnpx agent-browser@0.16.3
ab-p-l              pnpx agent-browser@latest
codex               pnpx @openai/codex@0.115.0
codex-p             pnpx @openai/codex@0.115.0
codex-l             pnpx @openai/codex@latest
codex-yo            wsha -- --yolo
gem                 gemini
gemini              pnpx @google/gemini-cli
gemini-p            pnpx @google/gemini-cli@0.33.1
gemini-l            pnpx @google/gemini-cli@latest
gemini-yo           wsha gemini --approval-mode yolo
claude              wsha claude-p
claude-p            pnpx @anthropic-ai/claude-code
claude-l            pnpx @anthropic-ai/claude-code@latest
claude-yo           wsha claude-l --dangerously-skip-permissions
opencode            pnpx opencode-ai@1.2.24
opencode-l          pnpx opencode-ai@latest
git.sync            git pull && git push
git.auto-pull       git stash && git pull && git stash pop
git.auto-commit     wsha codex "使用skill:git-commit提交代码按照下面的要求,母语中文,根据情况分1批或者多2,依据功能而定"
lz                  lazygit
lgit                lazygit
lzgit               lazygit
tping               wsh-ping.bat
tcping              wsha tping
s**                 wsh $$
ws                  wsh
show http header    wsh curl -I

[用户级] /e/project/self.project/git-utils.sh/test_playground_wsha/list-home/.config/wsh-alias.txt

别名  命令
----  ----
foo   echo user-foo

[项目级] /e/project/self.project/git-utils.sh/test_playground_wsha/list-work/.config/wsh-alias.txt

别名  命令
----  ----
ab    echo local-ab
bar   echo local-bar], code=0 |
| test_quoted_alias_with_space | PASS | 3.936s |  |
| test_wildcard_single_token_alias | PASS | 2.148s |  |
| test_wildcard_multi_token_alias | PASS | 2.191s |  |
| test_quoted_content_equivalence | PASS | 4.452s |  |
| test_wildcard_multi_capture | PASS | 2.320s |  |
| test_double_star_capture | PASS | 2.095s |  |
| test_builtin_env_vars | FAIL | 1.550s | APP_HOME 注入失败 output=[[wsha] alias hit: wsha show-home -> echo %APP_HOME%
/e/project/self.project/git-utils.sh], expected=[E:\project\self.project\git-utils.sh], code=0 |

## 统计汇总
- **总计**: 24
- **通过**: 22
- **失败**: 2
