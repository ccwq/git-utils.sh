# 测试报告: wsha.test.sh

- **测试时间**: 2026-03-06 11:07:43
- **执行环境**: Windows_NT (Git Bash)

## 测试用例详情

| 测试用例 | 结果 | 耗时 | 备注 |
| :--- | :--- | :--- | :--- |
| test_expand_ab | PASS | 0.219s |  |
| test_expand_foo_append | PASS | 0.246s |  |
| test_expand_bar_placeholder | PASS | 0.206s |  |
| test_unknown_alias_passthrough_with_args | PASS | 0.289s |  |
| test_unknown_alias_ping_passthrough | PASS | 0.341s |  |
| test_quoted_alias_expand | PASS | 0.228s |  |
| test_quoted_complex_command_passthrough | PASS | 0.217s |  |
| test_quoted_and_chain_passthrough | PASS | 0.247s |  |
| test_unknown_command_passthrough_error_code | PASS | 0.206s |  |
| test_duplicate_alias | PASS | 0.208s |  |
| test_invalid_mapping | PASS | 0.200s |  |

## 统计汇总
- **总计**: 11
- **通过**: 11
- **失败**: 0
