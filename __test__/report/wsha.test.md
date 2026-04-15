# 测试报告: wsha.test.sh

- **测试时间**: 2026-04-14 19:17:19
- **执行环境**: Windows_NT (Git Bash)

## 测试用例详情

| 测试用例 | 结果 | 耗时 | 备注 |
| :--- | :--- | :--- | :--- |
| test_expand_ab | PASS | 1.906s |  |
| test_expand_foo_append | PASS | 1.999s |  |
| test_expand_bar_placeholder | PASS | 2.137s |  |
| test_unknown_alias_passthrough_with_args | PASS | 1.827s |  |
| test_unknown_alias_ping_passthrough | PASS | 1.841s |  |
| test_quoted_alias_expand | PASS | 2.263s |  |
| test_quoted_complex_command_passthrough | PASS | 1.820s |  |
| test_quoted_and_chain_passthrough | PASS | 1.744s |  |
| test_unknown_command_passthrough_error_code | PASS | 1.918s |  |
| test_list_long_flag | FAIL | 1.504s | output=[[自定义] /e/project/self.project/git-utils.sh/test_playground_wsha
  alias-normal.txt

别名  命令                    
--   --                        
ab   echo agent-browser        
foo  echo foobar open          
bar  echo barbar -- --name ccwq], code=0 |
| test_list_short_flag | FAIL | 1.564s | output=[[自定义] /e/project/self.project/git-utils.sh/test_playground_wsha
  alias-normal.txt

别名  命令                    
--   --                        
ab   echo agent-browser        
foo  echo foobar open          
bar  echo barbar -- --name ccwq], code=0 |
| test_list_view_flag | FAIL | 1.545s | output=[[自定义] /e/project/self.project/git-utils.sh/test_playground_wsha
  alias-normal.txt

别名  命令                    
--   --                        
ab   echo agent-browser        
foo  echo foobar open          
bar  echo barbar -- --name ccwq], code=0 |
| test_duplicate_alias | PASS | 1.165s |  |
| test_invalid_mapping | PASS | 1.010s |  |
| test_default_merge_priority | PASS | 14.913s |  |
| test_default_missing_optional_configs_ignored | PASS | 12.091s |  |
| test_default_list_merged_aliases | PASS | 12.527s |  |
| test_quoted_alias_with_space | PASS | 3.985s |  |
| test_wildcard_single_token_alias | PASS | 3.264s |  |
| test_wildcard_multi_token_alias | PASS | 4.268s |  |
| test_quoted_content_equivalence | PASS | 4.651s |  |
| test_wildcard_multi_capture | PASS | 2.946s |  |
| test_double_star_capture | PASS | 2.641s |  |
| test_builtin_env_vars | PASS | 4.621s |  |

## 统计汇总
- **总计**: 24
- **通过**: 21
- **失败**: 3
