# 测试报告: wsha.test.sh

- **测试时间**: 2026-04-23 16:48:08
- **执行环境**: Windows_NT (Git Bash)

## 测试用例详情

| 测试用例 | 结果 | 耗时 | 备注 |
| :--- | :--- | :--- | :--- |
| test_expand_ab | PASS | 1.874s |  |
| test_expand_foo_append | FAIL | 1.694s | output=[foobar open], code=0 |
| test_expand_bar_placeholder | FAIL | 1.753s | output=[barbar 40 --name ccwq], code=0 |
| test_unknown_alias_passthrough_with_args | PASS | 1.654s |  |
| test_unknown_alias_ping_passthrough | PASS | 4.786s |  |
| test_quoted_alias_expand | PASS | 1.659s |  |
| test_quoted_complex_command_passthrough | PASS | 1.862s |  |
| test_quoted_and_chain_passthrough | PASS | 1.636s |  |
| test_unknown_command_passthrough_error_code | PASS | 1.649s |  |
| test_list_long_flag | FAIL | 1.443s | output=[[自定义] /e/project/self.project/git-utils.sh/test_playground_wsha
  alias-normal.txt

别名  命令                    
--   --                        
ab   echo agent-browser        
foo  echo foobar open          
bar  echo barbar -- --name ccwq], code=0 |
| test_list_short_flag | FAIL | 1.517s | output=[[自定义] /e/project/self.project/git-utils.sh/test_playground_wsha
  alias-normal.txt

别名  命令                    
--   --                        
ab   echo agent-browser        
foo  echo foobar open          
bar  echo barbar -- --name ccwq], code=0 |
| test_list_view_flag | FAIL | 1.523s | output=[[自定义] /e/project/self.project/git-utils.sh/test_playground_wsha
  alias-normal.txt

别名  命令                    
--   --                        
ab   echo agent-browser        
foo  echo foobar open          
bar  echo barbar -- --name ccwq], code=0 |
| test_duplicate_alias | PASS | 1.070s |  |
| test_invalid_mapping | PASS | 0.903s |  |
| test_default_merge_priority | FAIL | 17.687s | ab 覆盖失败 output=[(node:90764) Warning: Setting the NODE_TLS_REJECT_UNAUTHORIZED environment variable to '0' makes TLS connections and HTTPS requests insecure by disabling certificate verification.
(Use `node --trace-warnings ...` to show where the warning was created)
Progress: resolved 1, reused 0, downloaded 0, added 0
Packages: +1
+
Progress: resolved 1, reused 1, downloaded 0, added 0
Progress: resolved 1, reused 1, downloaded 0, added 1, done
Unknown command: run], code=1 |
| test_default_missing_optional_configs_ignored | PASS | 11.983s |  |
| test_default_list_merged_aliases | FAIL | 12.617s | output=[[内置] /e/project/self.project/git-utils.sh/config/wsh-alias
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
| test_quoted_alias_with_space | PASS | 3.025s |  |
| test_wildcard_single_token_alias | FAIL | 2.147s | output=[pnpx $1], code=0 |
| test_wildcard_multi_token_alias | FAIL | 2.266s | output=[pnpx $1 http-server], code=0 |
| test_quoted_content_equivalence | FAIL | 2.095s | q1 执行失败 output=[/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1057: q1: command not found], code=127 |
| test_wildcard_multi_capture | FAIL | 2.207s | output=[/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1057: tool: command not found], code=127 |
| test_double_star_capture | FAIL | 229.600s | output=[/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1060: [内置]: command not found
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
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1091: ab: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1092: abc: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1093: abcc: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1094: ab-p: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1095: ab-p-l: command not found
error: unexpected argument '@openai/codex@0.115.0' found

Usage: codex [OPTIONS] [PROMPT]
       codex [OPTIONS] <COMMAND> [ARGS]

For more information, try '--help'.
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1097: codex-p: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1098: codex-l: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1099: codex-mmx: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1100: codex-mini: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1101: codex-yo: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1102: gem: command not found
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
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1104: gemini-p: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1105: gemini-l: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1106: gemini-yo: command not found
**wsha** 是这个项目的核心工具 — 一个命令别名展开器。

主要功能：
- 从 `config/wsh-alias/*.txt` 读取别名定义
- 支持通配符匹配 (`*` 捕获单个 token, `**` 捕获所有剩余输入)
- 模板展开，如 `"px *" pnpx $1` 表示 `w px http-server` → `pnpx http-server`
- 环境变量展开：`%APP_HOME%`, `%USERPROFILE%` 等
- 执行前缀：`&` 顺序执行, `|` 或执行

示例别名（来自 default.txt）：
```
fox firefox        # w fox → firefox
gsd npx -y gsd-pi   # w gsd → npx -y gsd-pi
"bu **" uvx browser-use  $$   # w bu foo → uvx browser-use foo
```

你想运行 `w <alias>` 还是需要其他帮助？
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1108: claude-p: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1109: claude-l: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1110: claude-yo: command not found

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
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1112: opencode-l: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1113: git.sync: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1114: git.auto-pull: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1115: git.auto-commit: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1116: lz: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1117: lgit: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1118: lzgit: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1119: tping: command not found
Invalid port number: tping
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1121: scripts: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1122: ws: command not found
ls: cannot access 'wsh.bat': No such file or directory
ls: cannot access 'ls': No such file or directory
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1124: ll: command not found
/e/project/self.project/git-utils.sh/sh/wsh.bat: line 1: @echo: command not found
/e/project/self.project/git-utils.sh/sh/wsh.bat: line 2: setlocal: command not found
/e/project/self.project/git-utils.sh/sh/wsh.bat: wsh.bat: line 11: syntax error near unexpected token `newline'
/e/project/self.project/git-utils.sh/sh/wsh.bat: wsh.bat: line 11: `if "%WANT_HELP%"=="1" ('
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1126: show: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1128: [用户]: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1129: custom.txt: command not found
/e/project/self.project/git-utils.sh/sh/wsha.sh: line 1131: code-protable: command not found

[main 2026-04-23T08:45:22.338Z] update#setState idle
[main 2026-04-23T08:45:52.350Z] update#setState checking for updates
[main 2026-04-23T08:45:53.088Z] update#setState available for download
[main 2026-04-23T08:48:05.752Z] Extension host with pid 46036 exited with code: 0, signal: unknown.], code=0 |
| test_builtin_env_vars | FAIL | 1.782s | APP_HOME 注入失败 output=[E:/project/self.project/git-utils.sh], expected=[/e/project/self.project/git-utils.sh], code=0 |

## 统计汇总
- **总计**: 24
- **通过**: 11
- **失败**: 13
