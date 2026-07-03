# 测试报告: wsha.test.sh

- **测试时间**: 2026-07-03 11:31:59
- **执行环境**: Windows_NT (Git Bash)

## 测试用例详情

| 测试用例 | 结果 | 耗时 | 备注 |
| :--- | :--- | :--- | :--- |
| test_expand_ab | PASS | 1.835s |  |
| test_expand_foo_append | PASS | 1.493s |  |
| test_expand_bar_placeholder | PASS | 1.903s |  |
| test_unknown_alias_passthrough_with_args | PASS | 1.695s |  |
| test_unknown_alias_ping_passthrough | PASS | 1.721s |  |
| test_quoted_alias_expand | PASS | 1.691s |  |
| test_quoted_complex_command_passthrough | PASS | 1.557s |  |
| test_quoted_and_chain_passthrough | PASS | 1.459s |  |
| test_unknown_command_passthrough_error_code | PASS | 1.515s |  |
| test_list_long_flag | PASS | 1.298s |  |
| test_list_short_flag | PASS | 1.297s |  |
| test_list_view_flag | PASS | 1.227s |  |
| test_duplicate_alias | PASS | 0.832s |  |
| test_invalid_mapping | PASS | 0.781s |  |
| test_default_merge_priority | PASS | 19.471s |  |
| test_default_missing_optional_configs_ignored | PASS | 18.829s |  |
| test_default_list_merged_aliases | PASS | 18.199s |  |
| test_quoted_alias_with_space | PASS | 2.941s |  |
| test_wildcard_single_token_alias | PASS | 1.991s |  |
| test_wildcard_multi_token_alias | PASS | 3.224s |  |
| test_quoted_content_equivalence | PASS | 3.233s |  |
| test_wildcard_multi_capture | PASS | 2.067s |  |
| test_double_star_capture | PASS | 2.415s |  |
| test_super_rule_plain_tokens | PASS | 2.492s |  |
| test_super_rule_quoted_command | PASS | 2.486s |  |
| test_builtin_env_vars | PASS | 9.318s |  |

## 统计汇总
- **总计**: 26
- **通过**: 26
- **失败**: 0
