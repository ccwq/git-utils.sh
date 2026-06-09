# 测试报告: wsha.test.sh

- **测试时间**: 2026-06-09 12:00:59
- **执行环境**: Windows_NT (Git Bash)

## 测试用例详情

| 测试用例 | 结果 | 耗时 | 备注 |
| :--- | :--- | :--- | :--- |
| test_expand_ab | PASS | 1.643s |  |
| test_expand_foo_append | PASS | 1.619s |  |
| test_expand_bar_placeholder | PASS | 1.562s |  |
| test_unknown_alias_passthrough_with_args | PASS | 1.519s |  |
| test_unknown_alias_ping_passthrough | PASS | 5.347s |  |
| test_quoted_alias_expand | PASS | 1.555s |  |
| test_quoted_complex_command_passthrough | PASS | 1.497s |  |
| test_quoted_and_chain_passthrough | PASS | 1.472s |  |
| test_unknown_command_passthrough_error_code | PASS | 1.511s |  |
| test_list_long_flag | FAIL | 1.325s | output=[[自定义] /e/project/self.project/git-utils.sh/test_playground_wsha
  alias-normal.txt

别名  命令                    
--   --                        
ab   echo agent-browser        
foo  echo foobar open          
bar  echo barbar -- --name ccwq], code=0 |
| test_list_short_flag | FAIL | 1.389s | output=[[自定义] /e/project/self.project/git-utils.sh/test_playground_wsha
  alias-normal.txt

别名  命令                    
--   --                        
ab   echo agent-browser        
foo  echo foobar open          
bar  echo barbar -- --name ccwq], code=0 |
| test_list_view_flag | FAIL | 1.425s | output=[[自定义] /e/project/self.project/git-utils.sh/test_playground_wsha
  alias-normal.txt

别名  命令                    
--   --                        
ab   echo agent-browser        
foo  echo foobar open          
bar  echo barbar -- --name ccwq], code=0 |
| test_duplicate_alias | PASS | 0.992s |  |
| test_invalid_mapping | PASS | 0.815s |  |
| test_default_merge_priority | FAIL | 16.216s | foo 覆盖失败 output=[[wsha] exec: foo ping
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1089: foo: command not found], code=127 |
| test_default_missing_optional_configs_ignored | PASS | 14.181s |  |
| test_default_list_merged_aliases | PASS | 14.301s |  |
| test_quoted_alias_with_space | PASS | 2.830s |  |
| test_wildcard_single_token_alias | FAIL | 1.838s | output=[[wsha] alias hit: w pxhttp-server -> echo pnpx $1
[wsha] exec: echo pnpx $1
pnpx $1], code=0 |
| test_wildcard_multi_token_alias | FAIL | 1.803s | output=[[wsha] alias hit: w px http-server -> echo pnpx $1 http-server
[wsha] exec: echo pnpx $1 http-server
pnpx $1 http-server], code=0 |
| test_quoted_content_equivalence | FAIL | 1.862s | q1 执行失败 output=[[wsha] exec: q1 http-server
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1089: q1: command not found], code=127 |
| test_wildcard_multi_capture | FAIL | 1.954s | output=[[wsha] exec: tool alpha beta
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1089: tool: command not found], code=127 |
| test_double_star_capture | PASS | 1.939s |  |
| test_builtin_env_vars | FAIL | 1.542s | APP_HOME 注入失败 output=[[wsha] alias hit: w show-home -> echo E:/project/self.project/git-utils.sh
[wsha] exec: echo E:/project/self.project/git-utils.sh
E:/project/self.project/git-utils.sh], expected=[/e/project/self.project/git-utils.sh], code=0 |

## 统计汇总
- **总计**: 24
- **通过**: 15
- **失败**: 9
