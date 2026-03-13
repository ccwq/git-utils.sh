# 测试报告: wsha.test.sh

- **测试时间**: 2026-03-13 09:42:27
- **执行环境**: Windows_NT (Git Bash)

## 测试用例详情

| 测试用例 | 结果 | 耗时 | 备注 |
| :--- | :--- | :--- | :--- |
| test_expand_ab | PASS | 0.698s |  |
| test_expand_foo_append | PASS | 0.629s |  |
| test_expand_bar_placeholder | PASS | 0.962s |  |
| test_unknown_alias_passthrough_with_args | PASS | 0.589s |  |
| test_unknown_alias_ping_passthrough | PASS | 5.244s |  |
| test_quoted_alias_expand | PASS | 0.529s |  |
| test_quoted_complex_command_passthrough | PASS | 0.526s |  |
| test_quoted_and_chain_passthrough | PASS | 0.506s |  |
| test_unknown_command_passthrough_error_code | PASS | 0.517s |  |
| test_list_long_flag | PASS | 0.544s |  |
| test_list_short_flag | PASS | 0.515s |  |
| test_list_view_flag | PASS | 0.587s |  |
| test_duplicate_alias | PASS | 0.506s |  |
| test_invalid_mapping | PASS | 0.474s |  |
| test_default_merge_priority | PASS | 2.028s |  |
| test_default_missing_optional_configs_ignored | PASS | 0.694s |  |
| test_default_list_merged_aliases | PASS | 0.839s |  |
| test_quoted_alias_with_space | PASS | 1.034s |  |
| test_wildcard_single_token_alias | PASS | 0.571s |  |
| test_wildcard_multi_token_alias | PASS | 0.526s |  |
| test_quoted_content_equivalence | PASS | 1.051s |  |
| test_wildcard_multi_capture | PASS | 0.615s |  |
| test_double_star_capture | PASS | 0.563s |  |
| test_builtin_env_vars | PASS | 2.127s |  |

## 统计汇总
- **总计**: 24
- **通过**: 24
- **失败**: 0
