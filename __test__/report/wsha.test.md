# 测试报告: wsha.test.sh

- **测试时间**: 2026-03-06 10:09:15
- **执行环境**: Windows_NT (Git Bash)

## 测试用例详情

| 测试用例 | 结果 | 耗时 | 备注 |
| :--- | :--- | :--- | :--- |
| test_expand_ab | PASS | 0.200s |  |
| test_expand_foo_append | PASS | 0.233s |  |
| test_expand_bar_placeholder | PASS | 0.200s |  |
| test_unknown_alias_passthrough_with_args | PASS | 0.244s |  |
| test_unknown_alias_ping_passthrough | PASS | 0.365s |  |
| test_quoted_complex_command_passthrough | PASS | 0.279s |  |
| test_quoted_and_chain_passthrough | PASS | 0.199s |  |
| test_unknown_command_passthrough_error_code | PASS | 0.283s |  |
| test_duplicate_alias | PASS | 0.196s |  |
| test_invalid_mapping | PASS | 0.208s |  |

## 统计汇总
- **总计**: 10
- **通过**: 10
- **失败**: 0
