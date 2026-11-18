# 测试报告: wsha.test.sh

- **测试时间**: 2026-11-18 20:07:12
- **执行环境**: Windows_NT (Git Bash)

## 测试用例详情

| 测试用例 | 结果 | 耗时 | 备注 |
| :--- | :--- | :--- | :--- |
| test_expand_ab | PASS | 2.608s |  |
| test_expand_foo_append | PASS | 1.492s |  |
| test_expand_bar_placeholder | PASS | 1.972s |  |
| test_unknown_alias_passthrough_with_args | PASS | 1.532s |  |
| test_unknown_alias_ping_passthrough | PASS | 5.973s |  |
| test_quoted_alias_expand | PASS | 1.314s |  |
| test_quoted_complex_command_passthrough | PASS | 1.696s |  |
| test_quoted_and_chain_passthrough | PASS | 1.771s |  |
| test_unknown_command_passthrough_error_code | PASS | 2.003s |  |
| test_prefix_aliases_match_without_prefix_marker | PASS | 3.170s |  |
| test_list_long_flag | PASS | 2.069s |  |
| test_list_short_flag | PASS | 1.627s |  |
| test_list_tty_table_groups_and_truncates | PASS | 2.849s |  |
| test_list_non_tty_keeps_plain_output | PASS | 1.963s |  |
| test_list_view_flag | PASS | 1.707s |  |
| test_duplicate_alias | PASS | 2.230s |  |
| test_invalid_mapping | PASS | 1.428s |  |
| test_default_merge_priority | PASS | 4.615s |  |
| test_default_missing_optional_configs_ignored | PASS | 1.580s |  |
| test_default_list_merged_aliases | PASS | 2.485s |  |
| test_quoted_alias_with_space | PASS | 4.538s |  |
| test_wildcard_single_token_alias | PASS | 1.535s |  |
| test_wildcard_multi_token_alias | PASS | 2.166s |  |
| test_quoted_content_equivalence | PASS | 3.480s |  |
| test_wildcard_multi_capture | PASS | 2.534s |  |
| test_double_star_capture | PASS | 1.406s |  |
| test_double_star_word_boundary_space_token | PASS | 3.921s |  |
| test_double_star_word_boundary_default_config | PASS | 1.131s |  |
| test_double_star_word_boundary_literal_head | PASS | 2.237s |  |
| test_default_process_aliases_support_optional_args | PASS | 3.049s |  |
| test_recursive_alias_quoted_prompt_with_dollar_at | PASS | 1.615s |  |
| test_recursive_alias_dollar_prompt_is_literal | PASS | 1.378s |  |
| test_recursive_alias_git_up_p_keeps_prompt_argument | FAIL | 1.657s | output=[echo codex --yolo --model gpt-5.4 "$git-up -p"], code=0 |
| test_super_rule_plain_tokens | FAIL | 2.515s | output=[[wsha] alias hit: w grcmd tasklist chrome -> tasklist | findstr chrome
[wsha] exec: tasklist | findstr chrome], code=1 |
| test_super_rule_quoted_command | PASS | 2.667s |  |
| test_recursive_alias_keeps_captured_w_command | PASS | 0.958s |  |
| test_tping_qq_keeps_script_path_separators | PASS | 0.257s |  |
| test_block_bash_capture_placeholder | PASS | 1.167s |  |
| test_block_sh_runner | PASS | 1.500s |  |
| test_block_windows_runner_command_generation | PASS | 1.181s |  |
| test_block_embedded_double_star_empty_warn | PASS | 1.405s |  |
| test_block_extra_args_warn_and_ignore | PASS | 1.672s |  |
| test_block_double_star_requires_non_empty_warn | PASS | 1.259s |  |
| test_block_unclosed_fails | PASS | 1.040s |  |
| test_multiple_double_star_alias_is_skipped | PASS | 0.684s |  |
| test_block_empty_warn_noop | PASS | 2.334s |  |
| test_block_list_summary | PASS | 1.253s |  |
| test_block_invalid_runner_fails | PASS | 1.233s |  |
| test_block_cache_clear | PASS | 3.787s |  |
| test_block_no_cache_uses_temp_script | PASS | 1.126s |  |
| test_corrupt_alias_cache_falls_back_to_config | PASS | 2.031s |  |
| test_builtin_env_vars | PASS | 4.112s |  |

## 统计汇总
- **总计**: 52
- **通过**: 50
- **失败**: 2
