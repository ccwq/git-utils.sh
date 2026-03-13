# 测试报告: wsha.test.sh

- **测试时间**: 2026-03-13 09:14:33
- **执行环境**: Windows_NT (Git Bash)

## 测试用例详情

| 测试用例 | 结果 | 耗时 | 备注 |
| :--- | :--- | :--- | :--- |
| test_expand_ab | PASS | 0.527s |  |
| test_expand_foo_append | PASS | 0.528s |  |
| test_expand_bar_placeholder | PASS | 0.495s |  |
| test_unknown_alias_passthrough_with_args | PASS | 0.491s |  |
| test_unknown_alias_ping_passthrough | PASS | 4.188s |  |
| test_quoted_alias_expand | PASS | 0.479s |  |
| test_quoted_complex_command_passthrough | PASS | 0.484s |  |
| test_quoted_and_chain_passthrough | PASS | 0.503s |  |
| test_unknown_command_passthrough_error_code | PASS | 0.488s |  |
| test_list_long_flag | PASS | 0.483s |  |
| test_list_short_flag | PASS | 0.424s |  |
| test_duplicate_alias | PASS | 0.469s |  |
| test_invalid_mapping | PASS | 0.428s |  |
| test_default_merge_priority | PASS | 1.899s |  |
| test_default_missing_optional_configs_ignored | PASS | 0.737s |  |
| test_default_list_merged_aliases | PASS | 0.693s |  |
| test_quoted_alias_with_space | PASS | 1.014s |  |
| test_wildcard_single_token_alias | PASS | 0.519s |  |
| test_wildcard_multi_token_alias | PASS | 0.500s |  |
| test_quoted_content_equivalence | PASS | 1.034s |  |
| test_wildcard_multi_capture | PASS | 0.608s |  |
| test_double_star_capture | PASS | 0.532s |  |
| test_builtin_env_vars | PASS | 1.526s |  |

## 统计汇总
- **总计**: 23
- **通过**: 23
- **失败**: 0
