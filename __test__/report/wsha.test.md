# 测试报告: wsha.test.sh

- **测试时间**: 2026-03-06 15:12:29
- **执行环境**: Windows_NT (Git Bash)

## 测试用例详情

| 测试用例 | 结果 | 耗时 | 备注 |
| :--- | :--- | :--- | :--- |
| test_expand_ab | PASS | 0.438s |  |
| test_expand_foo_append | PASS | 0.475s |  |
| test_expand_bar_placeholder | PASS | 0.455s |  |
| test_unknown_alias_passthrough_with_args | PASS | 0.431s |  |
| test_unknown_alias_ping_passthrough | PASS | 0.446s |  |
| test_quoted_alias_expand | PASS | 0.529s |  |
| test_quoted_complex_command_passthrough | PASS | 0.497s |  |
| test_quoted_and_chain_passthrough | PASS | 0.555s |  |
| test_unknown_command_passthrough_error_code | PASS | 0.440s |  |
| test_list_long_flag | PASS | 0.422s |  |
| test_list_short_flag | PASS | 0.441s |  |
| test_duplicate_alias | PASS | 0.463s |  |
| test_invalid_mapping | PASS | 0.438s |  |
| test_default_merge_priority | PASS | 1.793s |  |
| test_default_missing_optional_configs_ignored | PASS | 0.682s |  |
| test_default_list_merged_aliases | PASS | 0.642s |  |
| test_quoted_alias_with_space | PASS | 0.846s |  |
| test_wildcard_single_token_alias | PASS | 0.586s |  |
| test_wildcard_multi_token_alias | PASS | 0.476s |  |
| test_quoted_content_equivalence | PASS | 0.896s |  |
| test_wildcard_multi_capture | PASS | 0.520s |  |

## 统计汇总
- **总计**: 21
- **通过**: 21
- **失败**: 0
