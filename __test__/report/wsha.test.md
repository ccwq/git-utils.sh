# 测试报告: wsha.test.sh

- **测试时间**: 2026-07-07 09:16:21
- **执行环境**: Windows_NT (Git Bash)

## 测试用例详情

| 测试用例 | 结果 | 耗时 | 备注 |
| :--- | :--- | :--- | :--- |
| test_expand_ab | PASS | 0.720s |  |
| test_expand_foo_append | PASS | 0.812s |  |
| test_expand_bar_placeholder | PASS | 0.784s |  |
| test_unknown_alias_passthrough_with_args | PASS | 0.836s |  |
| test_unknown_alias_ping_passthrough | PASS | 0.824s |  |
| test_quoted_alias_expand | PASS | 0.754s |  |
| test_quoted_complex_command_passthrough | PASS | 0.854s |  |
| test_quoted_and_chain_passthrough | PASS | 0.806s |  |
| test_unknown_command_passthrough_error_code | PASS | 0.779s |  |
| test_list_long_flag | PASS | 0.796s |  |
| test_list_short_flag | PASS | 0.825s |  |
| test_list_view_flag | PASS | 0.812s |  |
| test_duplicate_alias | PASS | 0.805s |  |
| test_invalid_mapping | PASS | 0.832s |  |
| test_default_merge_priority | PASS | 1.610s |  |
| test_default_missing_optional_configs_ignored | PASS | 0.772s |  |
| test_default_list_merged_aliases | PASS | 0.904s |  |
| test_quoted_alias_with_space | PASS | 1.293s |  |
| test_wildcard_single_token_alias | PASS | 0.830s |  |
| test_wildcard_multi_token_alias | PASS | 0.780s |  |
| test_quoted_content_equivalence | PASS | 1.475s |  |
| test_wildcard_multi_capture | PASS | 0.762s |  |
| test_double_star_capture | PASS | 0.840s |  |
| test_recursive_alias_quoted_prompt_with_dollar_at | PASS | 0.750s |  |
| test_recursive_alias_dollar_prompt_is_literal | PASS | 0.777s |  |
| test_super_rule_plain_tokens | PASS | 1.491s |  |
| test_super_rule_quoted_command | PASS | 1.476s |  |
| test_block_bash_capture_placeholder | PASS | 0.809s |  |
| test_block_sh_runner | PASS | 0.823s |  |
| test_block_windows_runner_command_generation | PASS | 0.879s |  |
| test_block_embedded_double_star_empty_warn | PASS | 0.896s |  |
| test_block_extra_args_warn_and_ignore | PASS | 0.780s |  |
| test_block_double_star_requires_non_empty_warn | PASS | 0.788s |  |
| test_block_empty_warn_noop | PASS | 0.806s |  |
| test_block_list_summary | PASS | 0.818s |  |
| test_block_invalid_runner_fails | PASS | 0.780s |  |
| test_block_cache_clear | PASS | 1.389s |  |
| test_builtin_env_vars | PASS | 2.193s |  |

## 统计汇总
- **总计**: 38
- **通过**: 38
- **失败**: 0
