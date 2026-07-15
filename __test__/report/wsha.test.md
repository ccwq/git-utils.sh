# 测试报告: wsha.test.sh

- **测试时间**: 2026-07-15 16:56:14
- **执行环境**: Windows_NT (Git Bash)

## 测试用例详情

| 测试用例 | 结果 | 耗时 | 备注 |
| :--- | :--- | :--- | :--- |
| test_expand_ab | PASS | 0.881s |  |
| test_expand_foo_append | PASS | 0.819s |  |
| test_expand_bar_placeholder | PASS | 0.849s |  |
| test_unknown_alias_passthrough_with_args | PASS | 0.791s |  |
| test_unknown_alias_ping_passthrough | PASS | 0.879s |  |
| test_quoted_alias_expand | PASS | 0.875s |  |
| test_quoted_complex_command_passthrough | PASS | 0.904s |  |
| test_quoted_and_chain_passthrough | PASS | 0.821s |  |
| test_unknown_command_passthrough_error_code | PASS | 0.844s |  |
| test_prefix_aliases_match_without_prefix_marker | PASS | 1.516s |  |
| test_list_long_flag | PASS | 0.791s |  |
| test_list_short_flag | PASS | 0.815s |  |
| test_list_tty_table_groups_and_truncates | PASS | 1.091s |  |
| test_list_non_tty_keeps_plain_output | PASS | 0.838s |  |
| test_list_view_flag | PASS | 0.885s |  |
| test_duplicate_alias | PASS | 0.788s |  |
| test_invalid_mapping | PASS | 0.848s |  |
| test_default_merge_priority | PASS | 1.827s |  |
| test_default_missing_optional_configs_ignored | PASS | 0.844s |  |
| test_default_list_merged_aliases | PASS | 0.963s |  |
| test_quoted_alias_with_space | PASS | 1.417s |  |
| test_wildcard_single_token_alias | PASS | 0.817s |  |
| test_wildcard_multi_token_alias | PASS | 0.878s |  |
| test_quoted_content_equivalence | PASS | 1.693s |  |
| test_wildcard_multi_capture | PASS | 0.815s |  |
| test_double_star_capture | PASS | 0.841s |  |
| test_default_process_aliases_support_optional_args | PASS | 1.567s |  |
| test_recursive_alias_quoted_prompt_with_dollar_at | PASS | 0.799s |  |
| test_recursive_alias_dollar_prompt_is_literal | PASS | 0.924s |  |
| test_recursive_alias_git_up_p_keeps_prompt_argument | PASS | 0.483s |  |
| test_super_rule_plain_tokens | PASS | 1.994s |  |
| test_super_rule_quoted_command | PASS | 1.773s |  |
| test_recursive_alias_keeps_captured_w_command | PASS | 0.449s |  |
| test_tping_qq_keeps_script_path_separators | PASS | 0.260s |  |
| test_block_bash_capture_placeholder | PASS | 0.958s |  |
| test_block_sh_runner | PASS | 0.957s |  |
| test_block_windows_runner_command_generation | PASS | 0.907s |  |
| test_block_embedded_double_star_empty_warn | PASS | 0.875s |  |
| test_block_extra_args_warn_and_ignore | PASS | 0.848s |  |
| test_block_double_star_requires_non_empty_warn | PASS | 0.851s |  |
| test_block_unclosed_fails | PASS | 0.872s |  |
| test_multiple_double_star_alias_is_skipped | PASS | 0.537s |  |
| test_block_empty_warn_noop | PASS | 0.812s |  |
| test_block_list_summary | PASS | 0.841s |  |
| test_block_invalid_runner_fails | PASS | 0.802s |  |
| test_block_cache_clear | PASS | 1.491s |  |
| test_block_no_cache_uses_temp_script | PASS | 0.910s |  |
| test_corrupt_alias_cache_falls_back_to_config | PASS | 1.055s |  |
| test_builtin_env_vars | PASS | 2.404s |  |

## 统计汇总
- **总计**: 49
- **通过**: 49
- **失败**: 0
