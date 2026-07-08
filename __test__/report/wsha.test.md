# 测试报告: wsha.test.sh

- **测试时间**: 2026-07-08 18:02:34
- **执行环境**: Windows_NT (Git Bash)

## 测试用例详情

| 测试用例 | 结果 | 耗时 | 备注 |
| :--- | :--- | :--- | :--- |
| test_expand_ab | PASS | 0.745s |  |
| test_expand_foo_append | PASS | 0.713s |  |
| test_expand_bar_placeholder | PASS | 0.768s |  |
| test_unknown_alias_passthrough_with_args | PASS | 0.715s |  |
| test_unknown_alias_ping_passthrough | PASS | 0.807s |  |
| test_quoted_alias_expand | PASS | 0.808s |  |
| test_quoted_complex_command_passthrough | PASS | 0.780s |  |
| test_quoted_and_chain_passthrough | PASS | 0.733s |  |
| test_unknown_command_passthrough_error_code | PASS | 0.727s |  |
| test_prefix_aliases_match_without_prefix_marker | PASS | 1.404s |  |
| test_list_long_flag | PASS | 0.739s |  |
| test_list_short_flag | PASS | 0.745s |  |
| test_list_tty_table_groups_and_truncates | PASS | 0.907s |  |
| test_list_non_tty_keeps_plain_output | PASS | 0.728s |  |
| test_list_view_flag | PASS | 0.762s |  |
| test_duplicate_alias | PASS | 0.706s |  |
| test_invalid_mapping | PASS | 0.730s |  |
| test_default_merge_priority | PASS | 1.467s |  |
| test_default_missing_optional_configs_ignored | PASS | 0.738s |  |
| test_default_list_merged_aliases | PASS | 0.792s |  |
| test_quoted_alias_with_space | PASS | 1.275s |  |
| test_wildcard_single_token_alias | PASS | 0.724s |  |
| test_wildcard_multi_token_alias | PASS | 0.748s |  |
| test_quoted_content_equivalence | PASS | 1.377s |  |
| test_wildcard_multi_capture | PASS | 0.719s |  |
| test_double_star_capture | PASS | 0.713s |  |
| test_recursive_alias_quoted_prompt_with_dollar_at | PASS | 0.739s |  |
| test_recursive_alias_dollar_prompt_is_literal | PASS | 0.762s |  |
| test_recursive_alias_git_up_p_keeps_prompt_argument | PASS | 0.399s |  |
| test_super_rule_plain_tokens | PASS | 1.655s |  |
| test_super_rule_quoted_command | PASS | 1.609s |  |
| test_recursive_alias_keeps_captured_w_command | PASS | 0.412s |  |
| test_tping_qq_keeps_script_path_separators | PASS | 0.235s |  |
| test_block_bash_capture_placeholder | PASS | 0.748s |  |
| test_block_sh_runner | PASS | 0.748s |  |
| test_block_windows_runner_command_generation | PASS | 0.796s |  |
| test_block_embedded_double_star_empty_warn | PASS | 0.787s |  |
| test_block_extra_args_warn_and_ignore | PASS | 0.760s |  |
| test_block_double_star_requires_non_empty_warn | PASS | 0.739s |  |
| test_block_unclosed_fails | PASS | 0.729s |  |
| test_multiple_double_star_alias_is_skipped | PASS | 0.385s |  |
| test_block_empty_warn_noop | PASS | 0.703s |  |
| test_block_list_summary | PASS | 0.724s |  |
| test_block_invalid_runner_fails | PASS | 0.735s |  |
| test_block_cache_clear | PASS | 1.311s |  |
| test_block_no_cache_uses_temp_script | PASS | 0.693s |  |
| test_corrupt_alias_cache_falls_back_to_config | PASS | 0.804s |  |
| test_builtin_env_vars | PASS | 2.157s |  |

## 统计汇总
- **总计**: 48
- **通过**: 48
- **失败**: 0
