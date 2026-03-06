# 测试报告: wsha.test.sh

- **测试时间**: 2026-03-06 14:01:30
- **执行环境**: Windows_NT (Git Bash)

## 测试用例详情

| 测试用例 | 结果 | 耗时 | 备注 |
| :--- | :--- | :--- | :--- |
| test_expand_ab | PASS | 0.228s |  |
| test_expand_foo_append | PASS | 0.254s |  |
| test_expand_bar_placeholder | PASS | 0.230s |  |
| test_unknown_alias_passthrough_with_args | PASS | 0.245s |  |
| test_unknown_alias_ping_passthrough | PASS | 0.286s |  |
| test_quoted_alias_expand | PASS | 0.264s |  |
| test_quoted_complex_command_passthrough | PASS | 0.227s |  |
| test_quoted_and_chain_passthrough | PASS | 0.245s |  |
| test_unknown_command_passthrough_error_code | PASS | 0.212s |  |
| test_list_long_flag | PASS | 0.245s |  |
| test_list_short_flag | PASS | 0.198s |  |
| test_duplicate_alias | PASS | 0.195s |  |
| test_invalid_mapping | PASS | 0.196s |  |
| test_default_merge_priority | PASS | 0.608s |  |
| test_default_missing_optional_configs_ignored | PASS | 0.208s |  |
| test_default_list_merged_aliases | PASS | 0.287s |  |

## 统计汇总
- **总计**: 16
- **通过**: 16
- **失败**: 0
