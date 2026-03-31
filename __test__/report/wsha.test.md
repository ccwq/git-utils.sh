# 测试报告: wsha.test.sh

- **测试时间**: 2026-03-31 18:54:48
- **执行环境**: Windows_NT (Git Bash)

## 测试用例详情

| 测试用例 | 结果 | 耗时 | 备注 |
| :--- | :--- | :--- | :--- |
| test_expand_ab | PASS | 2.065s |  |
| test_expand_foo_append | PASS | 1.937s |  |
| test_expand_bar_placeholder | PASS | 1.984s |  |
| test_unknown_alias_passthrough_with_args | PASS | 1.689s |  |
| test_unknown_alias_ping_passthrough | PASS | 1.701s |  |
| test_quoted_alias_expand | PASS | 1.857s |  |
| test_quoted_complex_command_passthrough | PASS | 1.702s |  |
| test_quoted_and_chain_passthrough | PASS | 1.719s |  |
| test_unknown_command_passthrough_error_code | PASS | 1.719s |  |
| test_list_long_flag | PASS | 1.417s |  |
| test_list_short_flag | PASS | 1.453s |  |
| test_list_view_flag | PASS | 1.530s |  |
| test_duplicate_alias | PASS | 1.069s |  |
| test_invalid_mapping | PASS | 0.890s |  |
| test_default_merge_priority | PASS | 12.542s |  |
| test_default_missing_optional_configs_ignored | PASS | 11.807s |  |
| test_default_list_merged_aliases | PASS | 10.286s |  |
| test_quoted_alias_with_space | PASS | 3.843s |  |
| test_wildcard_single_token_alias | PASS | 2.429s |  |
| test_wildcard_multi_token_alias | PASS | 2.480s |  |
| test_quoted_content_equivalence | PASS | 4.657s |  |
| test_wildcard_multi_capture | PASS | 2.802s |  |
| test_double_star_capture | PASS | 2.351s |  |
| test_builtin_env_vars | PASS | 4.570s |  |

## 统计汇总
- **总计**: 24
- **通过**: 24
- **失败**: 0
