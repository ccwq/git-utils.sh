# 测试报告: wsha.test.sh

- **测试时间**: 2026-03-16 21:56:37
- **执行环境**: Windows_NT (Git Bash)

## 测试用例详情

| 测试用例 | 结果 | 耗时 | 备注 |
| :--- | :--- | :--- | :--- |
| test_expand_ab | PASS | 0.670s |  |
| test_expand_foo_append | PASS | 0.624s |  |
| test_expand_bar_placeholder | FAIL | 0.629s | output=['bar' is not recognized as an internal or external command,
operable program or batch file.], code=1 |
| test_unknown_alias_passthrough_with_args | PASS | 0.589s |  |
| test_unknown_alias_ping_passthrough | PASS | 0.679s |  |
| test_quoted_alias_expand | PASS | 0.661s |  |
| test_quoted_complex_command_passthrough | PASS | 0.601s |  |
| test_quoted_and_chain_passthrough | PASS | 0.586s |  |
| test_unknown_command_passthrough_error_code | PASS | 0.611s |  |
| test_list_long_flag | FAIL | 0.591s | output=[[自定义] D:\tools\git-utils.sh\test_playground_wsha\alias-normal.txt



别名  命令                
--  --                
ab  echo agent-browser
foo echo foobar open], code=0 |
| test_list_short_flag | PASS | 0.603s |  |
| test_list_view_flag | PASS | 0.629s |  |
| test_duplicate_alias | PASS | 0.573s |  |
| test_invalid_mapping | PASS | 0.543s |  |
| test_default_merge_priority | FAIL | 2.212s | bar 内置映射缺失 output=[[内置] D:\tools\git-utils.sh\config\wsh-alias.txt



别名                 命令                                      
--                 --                                      
fox                firefox                                 
box                killbox                                 
--update           cd /d %APP_HOME% && git pull            
-u                 wsha --update                           
--open             code %APP_HOME%                         
--lazygit          cd /d %APP_HOME% && lazygit             
-lgit              wsha --lazygit                          
--edit-config      code %APP_CONFIG%/wsh-alias.txt         
-ec                wsha --edit-config                      
--edit-config-user code %USERPROFILE%/.config/wsh-alias.txt
-ecu               wsha --edit-config-user                 
dc                 docker compose                          
abc                wsha ab --cdp 9222                      
ab-p               pnpx agent-browser@0.16.3               
ab-p-l             pnpx agent-browser@latest               
codex              pnpx @openai/codex@0.114.0              
codex-p            pnpx @openai/codex@0.114.0              
codex-l            pnpx @openai/codex@latest               
codex-yo           wsha -- --yolo                          
gem                gemini                                  
gemini             pnpx @google/gemini-cli                 
gemini-p           pnpx @google/gemini-cli@0.33.1          
gemini-l           pnpx @google/gemini-cli@latest          
gemini-yo          wsha -- --yolo                          
claude             wsha claude-p                           
claude-p           pnpx @anthropic-ai/claude-code@2.1.74   
pclaude-l          pnpx @anthropic-ai/claude-code@latest   
claude-yo          wsha -- --dangerously-skip-permissions  
opencode           pnpx opencode-ai@1.2.24                 
opencode-l         pnpx opencode-ai@latest                 
git.sync           git pull && git push                    
tping              wsh-ping                                
s**                wsh $$                                  
ws                 wsh                                     
show http header   wsh curl -I                             
px*                pnpx $1                                 
px *               pnpx $1


[用户级] D:\tools\git-utils.sh\test_playground_wsha\default-home\.config\wsh-alias.txt



别名  命令           
--  --           
foo echo user-foo


[项目级] D:\tools\git-utils.sh\test_playground_wsha\default-work\.config\wsh-alias.txt



别名 命令           
-- --           
ab echo local-ab], code=0 |
| test_default_missing_optional_configs_ignored | PASS | 0.750s |  |
| test_default_list_merged_aliases | FAIL | 0.905s | output=[[内置] D:\tools\git-utils.sh\config\wsh-alias.txt



别名                 命令                                      
--                 --                                      
fox                firefox                                 
box                killbox                                 
--update           cd /d %APP_HOME% && git pull            
-u                 wsha --update                           
--open             code %APP_HOME%                         
--lazygit          cd /d %APP_HOME% && lazygit             
-lgit              wsha --lazygit                          
--edit-config      code %APP_CONFIG%/wsh-alias.txt         
-ec                wsha --edit-config                      
--edit-config-user code %USERPROFILE%/.config/wsh-alias.txt
-ecu               wsha --edit-config-user                 
dc                 docker compose                          
abc                wsha ab --cdp 9222                      
ab-p               pnpx agent-browser@0.16.3               
ab-p-l             pnpx agent-browser@latest               
codex              pnpx @openai/codex@0.114.0              
codex-p            pnpx @openai/codex@0.114.0              
codex-l            pnpx @openai/codex@latest               
codex-yo           wsha -- --yolo                          
gem                gemini                                  
gemini             pnpx @google/gemini-cli                 
gemini-p           pnpx @google/gemini-cli@0.33.1          
gemini-l           pnpx @google/gemini-cli@latest          
gemini-yo          wsha -- --yolo                          
claude             wsha claude-p                           
claude-p           pnpx @anthropic-ai/claude-code@2.1.74   
pclaude-l          pnpx @anthropic-ai/claude-code@latest   
claude-yo          wsha -- --dangerously-skip-permissions  
opencode           pnpx opencode-ai@1.2.24                 
opencode-l         pnpx opencode-ai@latest                 
git.sync           git pull && git push                    
tping              wsh-ping                                
s**                wsh $$                                  
ws                 wsh                                     
show http header   wsh curl -I                             
px*                pnpx $1                                 
px *               pnpx $1


[用户级] D:\tools\git-utils.sh\test_playground_wsha\list-home\.config\wsh-alias.txt



别名  命令           
--  --           
foo echo user-foo


[项目级] D:\tools\git-utils.sh\test_playground_wsha\list-work\.config\wsh-alias.txt



别名 命令           
-- --           
ab echo local-ab], code=0 |
| test_quoted_alias_with_space | PASS | 1.170s |  |
| test_wildcard_single_token_alias | PASS | 0.591s |  |
| test_wildcard_multi_token_alias | PASS | 0.612s |  |
| test_quoted_content_equivalence | PASS | 1.110s |  |
| test_wildcard_multi_capture | PASS | 0.682s |  |
| test_double_star_capture | PASS | 0.642s |  |
| test_builtin_env_vars | PASS | 2.005s |  |

## 统计汇总
- **总计**: 24
- **通过**: 20
- **失败**: 4
