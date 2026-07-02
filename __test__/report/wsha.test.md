# 测试报告: wsha.test.sh

- **测试时间**: 2026-07-02 14:42:59
- **执行环境**: Windows_NT (Git Bash)

## 测试用例详情

| 测试用例 | 结果 | 耗时 | 备注 |
| :--- | :--- | :--- | :--- |
| test_expand_ab | FAIL | 0.052s | output=[/home/ps/cheweiqing/proj-git-utils.sh/sh/wsha.sh:行103: uv：未找到命令], code=0 |
| test_expand_foo_append | FAIL | 0.035s | output=[/home/ps/cheweiqing/proj-git-utils.sh/sh/wsha.sh:行103: uv：未找到命令], code=0 |
| test_expand_bar_placeholder | FAIL | 0.034s | output=[/home/ps/cheweiqing/proj-git-utils.sh/sh/wsha.sh:行103: uv：未找到命令], code=0 |
| test_unknown_alias_passthrough_with_args | FAIL | 0.035s | output=[/home/ps/cheweiqing/proj-git-utils.sh/sh/wsha.sh:行103: uv：未找到命令], code=0 |
| test_unknown_alias_ping_passthrough | FAIL | 0.035s | output=[/home/ps/cheweiqing/proj-git-utils.sh/sh/wsha.sh:行103: uv：未找到命令], code=0 |
| test_quoted_alias_expand | FAIL | 0.035s | output=[/home/ps/cheweiqing/proj-git-utils.sh/sh/wsha.sh:行103: uv：未找到命令], code=0 |
| test_quoted_complex_command_passthrough | FAIL | 0.036s | output=[/home/ps/cheweiqing/proj-git-utils.sh/sh/wsha.sh:行103: uv：未找到命令], code=0 |
| test_quoted_and_chain_passthrough | FAIL | 0.037s | output=[/home/ps/cheweiqing/proj-git-utils.sh/sh/wsha.sh:行103: uv：未找到命令], code=0 |
| test_unknown_command_passthrough_error_code | FAIL | 0.051s | output=[/home/ps/cheweiqing/proj-git-utils.sh/sh/wsha.sh:行103: uv：未找到命令], code=0 |
| test_list_long_flag | PASS | 0.032s |  |
| test_list_short_flag | PASS | 0.030s |  |
| test_list_view_flag | PASS | 0.031s |  |
| test_duplicate_alias | PASS | 0.033s |  |
| test_invalid_mapping | PASS | 0.031s |  |
| test_default_merge_priority | FAIL | 0.674s | ab 覆盖失败 output=[/home/ps/cheweiqing/proj-git-utils.sh/sh/wsha.sh:行103: uv：未找到命令], code=0 |
| test_default_missing_optional_configs_ignored | FAIL | 0.631s | output=[/home/ps/cheweiqing/proj-git-utils.sh/sh/wsha.sh:行103: uv：未找到命令], code=0 |
| test_default_list_merged_aliases | PASS | 0.691s |  |
| test_quoted_alias_with_space | FAIL | 0.061s | pcodex 未命中默认别名 output=[/home/ps/cheweiqing/proj-git-utils.sh/sh/wsha.sh:行103: uv：未找到命令], code=0 |
| test_wildcard_single_token_alias | FAIL | 0.036s | output=[/home/ps/cheweiqing/proj-git-utils.sh/sh/wsha.sh:行103: uv：未找到命令], code=0 |
| test_wildcard_multi_token_alias | FAIL | 0.035s | output=[/home/ps/cheweiqing/proj-git-utils.sh/sh/wsha.sh:行103: uv：未找到命令], code=0 |
| test_quoted_content_equivalence | FAIL | 0.065s | q1=[/home/ps/cheweiqing/proj-git-utils.sh/sh/wsha.sh:行103: uv：未找到命令], q2=[/home/ps/cheweiqing/proj-git-utils.sh/sh/wsha.sh:行103: uv：未找到命令], code=0 |
| test_wildcard_multi_capture | FAIL | 0.034s | output=[/home/ps/cheweiqing/proj-git-utils.sh/sh/wsha.sh:行103: uv：未找到命令], code=0 |
| test_double_star_capture | FAIL | 0.036s | output=[/home/ps/cheweiqing/proj-git-utils.sh/sh/wsha.sh:行103: uv：未找到命令], code=0 |
| test_super_rule_plain_tokens | FAIL | 0.042s | output=[/home/ps/cheweiqing/proj-git-utils.sh/sh/wsha.sh:行103: uv：未找到命令], code=0 |
| test_super_rule_quoted_command | FAIL | 0.034s | output=[/home/ps/cheweiqing/proj-git-utils.sh/sh/wsha.sh:行103: uv：未找到命令], code=0 |
| test_builtin_env_vars | PASS | 0.110s |  |

## 统计汇总
- **总计**: 26
- **通过**: 7
- **失败**: 19
