# 测试报告: wsha.test.sh

- **测试时间**: 2026-04-12 12:02:22
- **执行环境**: Windows_NT (Git Bash)

## 测试用例详情

| 测试用例 | 结果 | 耗时 | 备注 |
| :--- | :--- | :--- | :--- |
| test_expand_ab | PASS | 2.984s |  |
| test_expand_foo_append | PASS | 2.793s |  |
| test_expand_bar_placeholder | PASS | 2.273s |  |
| test_unknown_alias_passthrough_with_args | PASS | 2.086s |  |
| test_unknown_alias_ping_passthrough | PASS | 2.211s |  |
| test_quoted_alias_expand | PASS | 2.299s |  |
| test_quoted_complex_command_passthrough | PASS | 2.748s |  |
| test_quoted_and_chain_passthrough | PASS | 2.402s |  |
| test_unknown_command_passthrough_error_code | PASS | 2.729s |  |
| test_list_long_flag | PASS | 2.135s |  |
| test_list_short_flag | PASS | 2.318s |  |
| test_list_view_flag | PASS | 2.320s |  |
| test_duplicate_alias | PASS | 1.520s |  |
| test_invalid_mapping | PASS | 1.553s |  |
| test_default_merge_priority | PASS | 21.912s |  |
| test_default_missing_optional_configs_ignored | PASS | 19.266s |  |
| test_default_list_merged_aliases | PASS | 18.071s |  |
| test_quoted_alias_with_space | PASS | 6.578s |  |
| test_wildcard_single_token_alias | PASS | 4.210s |  |
| test_wildcard_multi_token_alias | PASS | 5.121s |  |
| test_quoted_content_equivalence | PASS | 7.258s |  |
| test_wildcard_multi_capture | PASS | 4.647s |  |
| test_double_star_capture | PASS | 4.188s |  |
| test_builtin_env_vars | PASS | 7.417s |  |

## 统计汇总
- **总计**: 24
- **通过**: 24
- **失败**: 0
