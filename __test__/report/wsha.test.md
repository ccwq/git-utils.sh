# 测试报告: wsha.test.sh

- **测试时间**: 2026-06-10 15:08:15
- **执行环境**: Windows_NT (Git Bash)

## 测试用例详情

| 测试用例 | 结果 | 耗时 | 备注 |
| :--- | :--- | :--- | :--- |
| test_expand_ab | PASS | 1.555s |  |
| test_expand_foo_append | PASS | 1.587s |  |
| test_expand_bar_placeholder | PASS | 1.577s |  |
| test_unknown_alias_passthrough_with_args | PASS | 1.571s |  |
| test_unknown_alias_ping_passthrough | PASS | 5.518s |  |
| test_quoted_alias_expand | PASS | 1.491s |  |
| test_quoted_complex_command_passthrough | PASS | 1.725s |  |
| test_quoted_and_chain_passthrough | PASS | 1.519s |  |
| test_unknown_command_passthrough_error_code | PASS | 1.575s |  |
| test_list_long_flag | PASS | 1.313s |  |
| test_list_short_flag | PASS | 1.296s |  |
| test_list_view_flag | PASS | 1.278s |  |
| test_duplicate_alias | PASS | 0.919s |  |
| test_invalid_mapping | PASS | 0.818s |  |
| test_default_merge_priority | PASS | 15.812s |  |
| test_default_missing_optional_configs_ignored | PASS | 14.007s |  |
| test_default_list_merged_aliases | PASS | 14.473s |  |
| test_quoted_alias_with_space | PASS | 2.758s |  |
| test_wildcard_single_token_alias | PASS | 1.958s |  |
| test_wildcard_multi_token_alias | PASS | 2.180s |  |
| test_quoted_content_equivalence | PASS | 2.994s |  |
| test_wildcard_multi_capture | PASS | 1.980s |  |
| test_double_star_capture | PASS | 1.840s |  |
| test_super_rule_plain_tokens | PASS | 1.921s |  |
| test_super_rule_quoted_command | PASS | 1.926s |  |
| test_builtin_env_vars | PASS | 3.550s |  |

## 统计汇总
- **总计**: 26
- **通过**: 26
- **失败**: 0
