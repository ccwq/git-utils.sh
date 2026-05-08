# 测试报告: wsha.test.sh

- **测试时间**: 2026-05-08 10:55:26
- **执行环境**: Windows_NT (Git Bash)

## 测试用例详情

| 测试用例 | 结果 | 耗时 | 备注 |
| :--- | :--- | :--- | :--- |
| test_expand_ab | PASS | 1.676s |  |
| test_expand_foo_append | PASS | 1.555s |  |
| test_expand_bar_placeholder | PASS | 1.586s |  |
| test_unknown_alias_passthrough_with_args | PASS | 1.454s |  |
| test_unknown_alias_ping_passthrough | PASS | 1.583s |  |
| test_quoted_alias_expand | PASS | 1.462s |  |
| test_quoted_complex_command_passthrough | PASS | 1.418s |  |
| test_quoted_and_chain_passthrough | PASS | 1.412s |  |
| test_unknown_command_passthrough_error_code | PASS | 1.392s |  |
| test_list_long_flag | FAIL | 1.236s | output=[[自定义] /e/project/self.project/git-utils.sh/test_playground_wsha
  alias-normal.txt

别名  命令                    
--   --                        
ab   echo agent-browser        
foo  echo foobar open          
bar  echo barbar -- --name ccwq], code=0 |
| test_list_short_flag | FAIL | 1.230s | output=[[自定义] /e/project/self.project/git-utils.sh/test_playground_wsha
  alias-normal.txt

别名  命令                    
--   --                        
ab   echo agent-browser        
foo  echo foobar open          
bar  echo barbar -- --name ccwq], code=0 |
| test_list_view_flag | FAIL | 1.235s | output=[[自定义] /e/project/self.project/git-utils.sh/test_playground_wsha
  alias-normal.txt

别名  命令                    
--   --                        
ab   echo agent-browser        
foo  echo foobar open          
bar  echo barbar -- --name ccwq], code=0 |
| test_duplicate_alias | PASS | 0.831s |  |
| test_invalid_mapping | PASS | 0.784s |  |
| test_default_merge_priority | FAIL | 21.530s | ab 覆盖失败 output=[[wsha] alias hit: w ab run -> pnpx agent-browser run
[wsha] exec: pnpx agent-browser run
(node:16536) Warning: Setting the NODE_TLS_REJECT_UNAUTHORIZED environment variable to '0' makes TLS connections and HTTPS requests insecure by disabling certificate verification.
(Use `node --trace-warnings ...` to show where the warning was created)
Progress: resolved 1, reused 0, downloaded 0, added 0
Packages: +1
+
Progress: resolved 1, reused 0, downloaded 1, added 0
Progress: resolved 1, reused 0, downloaded 1, added 1, done
.../node_modules/agent-browser postinstall$ node scripts/postinstall.js
.../node_modules/agent-browser postinstall: ✓ Native binary ready: agent-browser-win32-x64.exe
.../node_modules/agent-browser postinstall: npm warn Unknown env config "dir". This will stop working in the next major version of npm.
.../node_modules/agent-browser postinstall: npm warn Unknown env config "npm-globalconfig". This will stop working in the next major version of npm.
.../node_modules/agent-browser postinstall: npm warn Unknown env config "store-dir". This will stop working in the next major version of npm.
.../node_modules/agent-browser postinstall: npm warn Unknown env config "verify-deps-before-run". This will stop working in the next major version of npm.
.../node_modules/agent-browser postinstall: npm warn Unknown env config "virtual-store-dir-max-length". This will stop working in the next major version of npm.
.../node_modules/agent-browser postinstall: npm warn Unknown env config "_jsr-registry". This will stop working in the next major version of npm.
.../node_modules/agent-browser postinstall: npm warn Unknown global config "virtual-store-dir-max-length". This will stop working in the next major version of npm.
.../node_modules/agent-browser postinstall: npm warn Unknown global config "store-dir". This will stop working in the next major version of npm.
.../node_modules/agent-browser postinstall:   ✓ System Chrome found: C:\Users\Administrator\AppData\Local\Google\Chrome\Application\chrome.exe
.../node_modules/agent-browser postinstall:     agent-browser will use it automatically.
.../node_modules/agent-browser postinstall: Done
Unknown command: run], code=1 |
| test_default_missing_optional_configs_ignored | PASS | 11.888s |  |
| test_default_list_merged_aliases | PASS | 12.739s |  |
| test_quoted_alias_with_space | PASS | 2.656s |  |
| test_wildcard_single_token_alias | FAIL | 1.810s | output=[[wsha] alias hit: w pxhttp-server -> echo pnpx $1
[wsha] exec: echo pnpx $1
pnpx $1], code=0 |
| test_wildcard_multi_token_alias | FAIL | 1.774s | output=[[wsha] alias hit: w px http-server -> echo pnpx $1 http-server
[wsha] exec: echo pnpx $1 http-server
pnpx $1 http-server], code=0 |
| test_quoted_content_equivalence | FAIL | 1.821s | q1 执行失败 output=[[wsha] exec: q1 http-server
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1089: q1: command not found], code=127 |
| test_wildcard_multi_capture | FAIL | 1.829s | output=[[wsha] exec: tool alpha beta
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1089: tool: command not found], code=127 |
| test_double_star_capture | PASS | 1.743s |  |
| test_builtin_env_vars | FAIL | 1.392s | APP_HOME 注入失败 output=[[wsha] alias hit: w show-home -> echo E:/project/self.project/git-utils.sh
[wsha] exec: echo E:/project/self.project/git-utils.sh
E:/project/self.project/git-utils.sh], expected=[/e/project/self.project/git-utils.sh], code=0 |

## 统计汇总
- **总计**: 24
- **通过**: 15
- **失败**: 9
