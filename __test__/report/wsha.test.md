# 测试报告: wsha.test.sh

- **测试时间**: 2026-04-22 17:42:28
- **执行环境**: Windows_NT (Git Bash)

## 测试用例详情

| 测试用例 | 结果 | 耗时 | 备注 |
| :--- | :--- | :--- | :--- |
| test_expand_ab | PASS | 2.334s |  |
| test_expand_foo_append | FAIL | 1.544s | output=[foobar open], code=0 |
| test_expand_bar_placeholder | FAIL | 2.250s | output=[barbar 40 --name ccwq], code=0 |
| test_unknown_alias_passthrough_with_args | PASS | 2.264s |  |
| test_unknown_alias_ping_passthrough | PASS | 4.836s |  |
| test_quoted_alias_expand | PASS | 1.537s |  |
| test_quoted_complex_command_passthrough | PASS | 1.547s |  |
| test_quoted_and_chain_passthrough | PASS | 1.603s |  |
| test_unknown_command_passthrough_error_code | PASS | 1.618s |  |
| test_list_long_flag | FAIL | 1.586s | output=[[自定义] /e/project/self.project/git-utils.sh/test_playground_wsha
  alias-normal.txt

别名  命令                    
--   --                        
ab   echo agent-browser        
foo  echo foobar open          
bar  echo barbar -- --name ccwq], code=0 |
| test_list_short_flag | FAIL | 1.770s | output=[[自定义] /e/project/self.project/git-utils.sh/test_playground_wsha
  alias-normal.txt

别名  命令                    
--   --                        
ab   echo agent-browser        
foo  echo foobar open          
bar  echo barbar -- --name ccwq], code=0 |
| test_list_view_flag | FAIL | 1.476s | output=[[自定义] /e/project/self.project/git-utils.sh/test_playground_wsha
  alias-normal.txt

别名  命令                    
--   --                        
ab   echo agent-browser        
foo  echo foobar open          
bar  echo barbar -- --name ccwq], code=0 |
| test_duplicate_alias | PASS | 1.258s |  |
| test_invalid_mapping | PASS | 0.874s |  |
| test_default_merge_priority | FAIL | 20.710s | foo 覆盖失败 output=[/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1057: foo: command not found], code=127 |
| test_default_missing_optional_configs_ignored | PASS | 12.240s |  |
| test_default_list_merged_aliases | FAIL | 14.772s | output=[[内置] /e/project/self.project/git-utils.sh/config/wsh-alias
  app-in.txt

别名              命令                                  
--                  --                                      
--update            cd /d %APP_HOME% && git pull            
-u                  wsha --update                           
--open              start code %APP_HOME%                   
--lazygit           cd /d %APP_HOME% && lazygit             
-lgit               wsha --lazygit                          
--edit-config       code %APP_CONFIG%/wsh-alias.txt         
-ec                 wsha --edit-config                      
--edit-config-user  code %USERPROFILE%/.config/wsh-alias.txt
-ecu                wsha --edit-config-user                 

[内置] /e/project/self.project/git-utils.sh/config/wsh-alias
  default.txt

别名            命令                                                            
--                --                                                                
fox               firefox                                                           
box               killbox                                                           
ev:edit           echo %EDITOR%                                                     
pp                ping t.cn                                                         
t-ps              tasklist | findstr                                                
t-kill            taskkill /f /im                                                   
gsd               npx -y gsd-pi                                                     
pw                playwright-cli                                                    
pw-l              npx -y playwright-cli                                             
cdp-test          wsh.bat curl http://localhost:9222/json/version                   
bu **             uvx browser-use  $$                                               
buc **            uvx browser-use --cdp-url http://localhost:9222 $$                
docker            podman                                                            
dc                wsha docker compose                                               
pc                podman compose                                                    
abc               wsha ab --cdp 9222                                                
abcc              wsha ab --cdp %CDPORT%                                            
ab-p              pnpx agent-browser@0.16.3                                         
ab-p-l            pnpx agent-browser@latest                                         
codex             pnpx @openai/codex@0.115.0                                        
codex-p           pnpx @openai/codex@0.115.0                                        
codex-l           pnpx @openai/codex@latest                                         
codex-mmx         wsha codex-l --model codex-MiniMax-M2.7                           
codex-mini        wsha codex-l --model codex-MiniMax-M2.7                           
codex-yo          wsha codex-l -- --yolo                                            
gem               gemini                                                            
gemini            pnpx @google/gemini-cli                                           
gemini-p          pnpx @google/gemini-cli@0.33.1                                    
gemini-l          pnpx @google/gemini-cli@latest                                    
gemini-yo         wsha gemini --approval-mode yolo                                  
claude            wsha claude-p                                                     
claude-p          pnpx @anthropic-ai/claude-code                                    
claude-l          pnpx @anthropic-ai/claude-code@latest                             
claude-yo         wsha claude-l --dangerously-skip-permissions                      
opencode          pnpx opencode-ai@1.2.24                                           
opencode-l        pnpx opencode-ai@latest                                           
git.sync          git pull && git push                                              
git.auto-pull     git stash && git pull && git stash pop                            
git.auto-commit   wsha codex "使用skill:git-commit提交代码按照下面的要求,母语中文,根据情况分1批或者多2,依据功能而定"
lz                lazygit                                                           
lgit              lazygit                                                           
lzgit             lazygit                                                           
tping             wsh-ping.bat                                                      
tcping            wsha tping                                                        
s**               wsh $$                                                            
ws                wsh                                                               
ls                wsh.bat ls -ah                                                    
ll                wsh.bat ls -lah                                                   
bash              wsh.bat .                                                         
show http header  wsh.bat curl -I                                                   

[项目] /e/project/self.project/git-utils.sh/test_playground_wsha/list-work/.config/wsh-alias
  default.txt

别名  命令        
--   --            
ab   echo local-ab 
bar  echo local-bar

[用户] /e/project/self.project/git-utils.sh/test_playground_wsha/list-home/.config/wsh-alias
  default.txt

别名  命令       
--   --           
foo  echo user-foo], code=0 |
| test_quoted_alias_with_space | PASS | 3.129s |  |
| test_wildcard_single_token_alias | FAIL | 2.001s | output=[pnpx $1], code=0 |
| test_wildcard_multi_token_alias | FAIL | 1.989s | output=[pnpx $1 http-server], code=0 |
| test_quoted_content_equivalence | FAIL | 2.075s | q1 执行失败 output=[/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1057: q1: command not found], code=127 |
| test_wildcard_multi_capture | FAIL | 3.422s | output=[/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1057: tool: command not found], code=127 |
| test_double_star_capture | FAIL | 2079.745s | output=[/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1060: [内置]: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1061: app-in.txt: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1063: --update: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1064: -u: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1065: --open: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1066: --lazygit: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1067: -lgit: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1068: --edit-config: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1069: -ec: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1070: --edit-config-user: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1071: -ecu: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1073: [内置]: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1074: default.txt: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1076: fox: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1077: box: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1078: ev:edit: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1079: pp: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1080: t-ps: command not found
FINDSTR: Bad command line
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1081: t-kill: command not found
[gsd] Error: Interactive mode requires a terminal (TTY) but stdin and stdout are not a TTY.
[gsd] Non-interactive alternatives:
[gsd]   gsd auto                       Auto-mode (pipeable, no TUI)
[gsd]   gsd --print "your message"     Single-shot prompt
[gsd]   gsd --web [path]               Browser-only web mode
[gsd]   gsd --mode rpc                 JSON-RPC over stdin/stdout
[gsd]   gsd --mode mcp                 MCP server over stdin/stdout
[gsd]   gsd --mode text "message"      Text output mode
[gsd]   gsd headless                   Auto-mode without TUI
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1083: pw: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1084: pw-l: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1085: cdp-test: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1086: bu: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1087: buc: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1088: docker: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1089: dc: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1090: pc: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1091: abc: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1092: abcc: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1093: ab-p: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1094: ab-p-l: command not found
error: unexpected argument '@openai/codex@0.115.0' found

Usage: codex [OPTIONS] [PROMPT]
       codex [OPTIONS] <COMMAND> [ARGS]

For more information, try '--help'.
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1096: codex-p: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1097: codex-l: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1098: codex-mmx: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1099: codex-mini: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1100: codex-yo: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1101: gem: command not found
node:internal/modules/run_main:107
    triggerUncaughtException(
    ^

Error: Cannot find package 'C:\Users\Administrator\AppData\Local\Volta\tools\image\node\24.11.0\node_modules\@google\gemini-cli\node_modules\ink\node_modules\chalk\index.js' imported from C:\Users\Administrator\AppData\Local\Volta\tools\image\node\24.11.0\node_modules\@google\gemini-cli\node_modules\ink\build\components\Text.js
Did you mean to import "chalk/source/index.js"?
    at legacyMainResolve (node:internal/modules/esm/resolve:204:26)
    at packageResolve (node:internal/modules/esm/resolve:778:12)
    at moduleResolve (node:internal/modules/esm/resolve:858:18)
    at defaultResolve (node:internal/modules/esm/resolve:990:11)
    at #cachedDefaultResolve (node:internal/modules/esm/loader:757:20)
    at ModuleLoader.resolve (node:internal/modules/esm/loader:734:38)
    at ModuleLoader.getModuleJobForImport (node:internal/modules/esm/loader:317:38)
    at #link (node:internal/modules/esm/module_job:208:49) {
  code: 'ERR_MODULE_NOT_FOUND'
}

Node.js v24.11.0
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1103: gemini-p: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1104: gemini-l: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1105: gemini-yo: command not found


**wsha** 是一个跨平台 Windows Git Bash 实用工具，实现智能命令行别名展开（通配符匹配、参数捕获、模板展开）。

**当前状态：**
- Python 实现：`py/wsha/` (主)
- Shell 版本：`sh/wsha.sh` (核心), `sh/wsha-core.py` (Python 核心)
- 配置：`config/wsh-alias.txt`

**最近修改的文件：**
- `py/wsha/expand.py`
- `sh/wsha-core.py`
- `sh/wsha.sh`
- `__test__/report/wsha.test.md`

你是想运行 wsha、查看帮助，还是有其他需求？
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1107: claude-p: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1108: claude-l: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1109: claude-yo: command not found

▄
█▀▀█ █▀▀█ █▀▀█ █▀▀▄ █▀▀▀ █▀▀█ █▀▀█ █▀▀█
█  █ █  █ █▀▀▀ █  █ █    █  █ █  █ █▀▀▀
▀▀▀▀ █▀▀▀ ▀▀▀▀ ▀▀▀▀ ▀▀▀▀ ▀▀▀▀ ▀▀▀▀ ▀▀▀▀

Commands:
  opencode completion          generate shell completion script
  opencode acp                 start ACP (Agent Client Protocol) server
  opencode mcp                 manage MCP (Model Context Protocol) servers
  opencode [project]           start opencode tui                                          [default]
  opencode attach <url>        attach to a running opencode server
  opencode run [message..]     run opencode with a message
  opencode debug               debugging and troubleshooting tools
  opencode providers           manage AI providers and credentials                   [aliases: auth]
  opencode agent               manage agents
  opencode upgrade [target]    upgrade opencode to the latest or a specific version
  opencode uninstall           uninstall opencode and remove all related files
  opencode serve               starts a headless opencode server
  opencode web                 start opencode server and open web interface
  opencode models [provider]   list all available models
  opencode stats               show token usage and cost statistics
  opencode export [sessionID]  export session data as JSON
  opencode import <file>       import session data from JSON file or URL
  opencode github              manage GitHub agent
  opencode pr <number>         fetch and checkout a GitHub PR branch, then run opencode
  opencode session             manage sessions
  opencode plugin <module>     install plugin and update config                      [aliases: plug]
  opencode db                  database tools

Positionals:
  project  path to start opencode in                                                        [string]

Options:
  -h, --help         show help                                                             [boolean]
  -v, --version      show version number                                                   [boolean]
      --print-logs   print logs to stderr                                                  [boolean]
      --log-level    log level                  [string] [choices: "DEBUG", "INFO", "WARN", "ERROR"]
      --pure         run without external plugins                                          [boolean]
      --port         port to listen on                                         [number] [default: 0]
      --hostname     hostname to listen on                           [string] [default: "127.0.0.1"]
      --mdns         enable mDNS service discovery (defaults hostname to 0.0.0.0)
                                                                          [boolean] [default: false]
      --mdns-domain  custom domain name for mDNS service (default: opencode.local)
                                                                [string] [default: "opencode.local"]
      --cors         additional domains to allow for CORS                      [array] [default: []]
  -m, --model        model to use in the format of provider/model                           [string]
  -c, --continue     continue the last session                                             [boolean]
  -s, --session      session id to continue                                                 [string]
      --fork         fork the session when continuing (use with --continue or --session)   [boolean]
      --prompt       prompt to use                                                          [string]
      --agent        agent to use                                                           [string]
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1111: opencode-l: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1112: git.sync: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1113: git.auto-pull: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1114: git.auto-commit: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1115: lz: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1116: lgit: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1117: lzgit: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1118: tping: command not found
Invalid port number: tping
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1120: scripts: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1121: ws: command not found
ls: cannot access 'wsh.bat': No such file or directory
ls: cannot access 'ls': No such file or directory
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1123: ll: command not found
/e/project/self.project/git-utils.sh/sh/wsh.bat: line 1: @echo: command not found
/e/project/self.project/git-utils.sh/sh/wsh.bat: line 2: setlocal: command not found
/e/project/self.project/git-utils.sh/sh/wsh.bat: wsh.bat: line 11: syntax error near unexpected token `newline'
/e/project/self.project/git-utils.sh/sh/wsh.bat: wsh.bat: line 11: `if "%WANT_HELP%"=="1" ('
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1125: show: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1127: [项目]: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1128: default.txt: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1130: ab: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1131: bar: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1133: [用户]: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1134: custom.txt: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1136: code-protable: command not found

[main 2026-04-22T09:09:20.496Z] update#setState idle
[main 2026-04-22T09:09:50.504Z] update#setState checking for updates
[main 2026-04-22T09:09:50.950Z] update#setState available for download
[main 2026-04-22T09:42:20.889Z] Extension host with pid 65684 exited with code: 0, signal: unknown.], code=0 |
| test_builtin_env_vars | FAIL | 3.886s | APP_HOME 注入失败 output=[E:/project/self.project/git-utils.sh], expected=[/e/project/self.project/git-utils.sh], code=0 |

## 统计汇总
- **总计**: 24
- **通过**: 11
- **失败**: 13
