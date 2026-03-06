# 测试报告: wsha.test.sh

- **测试时间**: 2026-03-06 16:02:59
- **执行环境**: Windows_NT (Git Bash)

## 测试用例详情

| 测试用例 | 结果 | 耗时 | 备注 |
| :--- | :--- | :--- | :--- |
| test_expand_ab | PASS | 0.650s |  |
| test_expand_foo_append | PASS | 0.546s |  |
| test_expand_bar_placeholder | PASS | 0.516s |  |
| test_unknown_alias_passthrough_with_args | PASS | 0.486s |  |
| test_unknown_alias_ping_passthrough | PASS | 0.652s |  |
| test_quoted_alias_expand | PASS | 0.980s |  |
| test_quoted_complex_command_passthrough | PASS | 0.639s |  |
| test_quoted_and_chain_passthrough | PASS | 0.669s |  |
| test_unknown_command_passthrough_error_code | PASS | 0.824s |  |
| test_list_long_flag | PASS | 0.630s |  |
| test_list_short_flag | PASS | 0.579s |  |
| test_duplicate_alias | PASS | 0.529s |  |
| test_invalid_mapping | PASS | 0.492s |  |
| test_default_merge_priority | PASS | 2.011s |  |
| test_default_missing_optional_configs_ignored | PASS | 0.868s |  |
| test_default_list_merged_aliases | PASS | 0.908s |  |
| test_quoted_alias_with_space | PASS | 1.269s |  |
| test_wildcard_single_token_alias | PASS | 0.576s |  |
| test_wildcard_multi_token_alias | PASS | 0.519s |  |
| test_quoted_content_equivalence | PASS | 1.078s |  |
| test_wildcard_multi_capture | PASS | 0.499s |  |
| test_double_star_capture | PASS | 0.568s |  |

## 统计汇总
- **总计**: 22
- **通过**: 22
- **失败**: 0
