# 测试报告: wsha.test.sh

- **测试时间**: 2026-07-08 15:53:15
- **执行环境**: Windows_NT (Git Bash)

## 测试用例详情

| 测试用例 | 结果 | 耗时 | 备注 |
| :--- | :--- | :--- | :--- |
| test_expand_ab | PASS | 0.762s |  |
| test_expand_foo_append | PASS | 0.802s |  |
| test_expand_bar_placeholder | PASS | 0.836s |  |
| test_unknown_alias_passthrough_with_args | PASS | 0.801s |  |
| test_unknown_alias_ping_passthrough | PASS | 4.361s |  |
| test_quoted_alias_expand | PASS | 0.770s |  |
| test_quoted_complex_command_passthrough | PASS | 0.846s |  |
| test_quoted_and_chain_passthrough | PASS | 0.807s |  |
| test_unknown_command_passthrough_error_code | PASS | 0.787s |  |
| test_list_long_flag | PASS | 0.799s |  |
| test_list_short_flag | PASS | 0.815s |  |
| test_list_tty_table_groups_and_truncates | PASS | 0.920s |  |
| test_list_non_tty_keeps_plain_output | PASS | 0.822s |  |
| test_list_view_flag | PASS | 0.801s |  |
| test_duplicate_alias | PASS | 0.841s |  |
| test_invalid_mapping | PASS | 0.859s |  |
| test_default_merge_priority | PASS | 1.564s |  |
| test_default_missing_optional_configs_ignored | PASS | 0.772s |  |
| test_default_list_merged_aliases | PASS | 0.865s |  |
| test_quoted_alias_with_space | PASS | 1.320s |  |
| test_wildcard_single_token_alias | PASS | 0.791s |  |
| test_wildcard_multi_token_alias | PASS | 0.808s |  |
| test_quoted_content_equivalence | PASS | 1.456s |  |
| test_wildcard_multi_capture | PASS | 0.772s |  |
| test_double_star_capture | PASS | 0.787s |  |
| test_recursive_alias_quoted_prompt_with_dollar_at | PASS | 0.772s |  |
| test_recursive_alias_dollar_prompt_is_literal | PASS | 0.773s |  |
| test_super_rule_plain_tokens | PASS | 1.492s |  |
| test_super_rule_quoted_command | PASS | 1.593s |  |
| test_recursive_alias_keeps_captured_w_command | PASS | 0.425s |  |
| test_block_bash_capture_placeholder | PASS | 0.823s |  |
| test_block_sh_runner | PASS | 0.808s |  |
| test_block_windows_runner_command_generation | PASS | 0.844s |  |
| test_block_embedded_double_star_empty_warn | PASS | 0.781s |  |
| test_block_extra_args_warn_and_ignore | PASS | 0.805s |  |
| test_block_double_star_requires_non_empty_warn | PASS | 0.818s |  |
| test_block_empty_warn_noop | PASS | 0.805s |  |
| test_block_list_summary | PASS | 0.791s |  |
| test_block_invalid_runner_fails | PASS | 0.784s |  |
| test_block_cache_clear | PASS | 1.443s |  |
| test_builtin_env_vars | PASS | 2.362s |  |

## 统计汇总
- **总计**: 41
- **通过**: 41
- **失败**: 0
