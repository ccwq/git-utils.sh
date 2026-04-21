当前通过 pip install -e . 安装之后, list是这样的"当前list是这样的",我希望输出的格式是"预期格式", 请参考其内容, 缺失的内容留空

"""当前list是这样的
> w -l
# 环境变量:
# APP_HOME=E:/project/self.project/git-utils.sh
# APP_SH=E:/project/self.project/git-utils.sh/sh
# APP_CONFIG=E:/project/self.project/git-utils.sh/config

[内置] E:/project/self.project/git-utils.sh/config/wsh-alias
  app-in.txt

别名                  命令                                                                
------------------  ----------------------------------------------------------------------
--update            cd /d %APP_HOME% && git pull
-u                  wsha.bat --update
--open              start code %APP_HOME%
--lazygit           cd /d %APP_HOME% && lazygit
-lgit               wsha.bat --lazygit
--edit-config       code %APP_CONFIG%/wsh-alias.txt
-ec                 wsha.bat --edit-config
--edit-config-user  code %USERPROFILE%/.config/wsh-alias.txt
-ecu                wsha.bat --edit-config-user
fox                 firefox
box                 killbox
ev:edit             echo %EDITOR%
pp                  ping t.cn
gsd                 npx -y gsd-pi
pw                  playwright-cli
pw-l                npx -y playwright-cli
cdp-test            wsh.bat curl http://localhost:9222/json/version
bu **               uvx browser-use  $$
buc **              uvx browser-use --cdp-url http://localhost:9222 $$
docker              podman
dc                  wsha.bat docker compose
pc                  podman compose
ab                  pnpx agent-browser
abc                 wsha.bat ab --cdp 9222
abcc                wsha.bat ab --cdp %CDPORT%
ab-p                pnpx agent-browser@0.16.3
ab-p-l              pnpx agent-browser@latest
codex               pnpx @openai/codex@0.115.0
codex-p             pnpx @openai/codex@0.115.0
codex-l             pnpx @openai/codex@latest
codex-yo            wsha.bat codex-l -- --yolo
gem                 gemini
gemini              pnpx @google/gemini-cli
gemini-p            pnpx @google/gemini-cli@0.33.1
gemini-l            pnpx @google/gemini-cli@latest
gemini-yo           wsha.bat gemini --approval-mode yolo
claude              wsha.bat claude-p
claude-p            pnpx @anthropic-ai/claude-code
claude-l            pnpx @anthropic-ai/claude-code@latest
claude-yo           wsha.bat claude-l --dangerously-skip-permissions
opencode            pnpx opencode-ai@1.2.24
"""


"""预期格式

> w -l
# 环境变量:
# APP_HOME=E:/project/self.project/git-utils.sh
# APP_SH=E:/project/self.project/git-utils.sh/sh
# APP_CONFIG=E:/project/self.project/git-utils.sh/config

[内置] path/to/foo1.txt

别名                  命令                                                                
------------------  ----------------------------------------------------------------------
--update            cd /d %APP_HOME% && git pull
-u                  wsha.bat --update
--open              start code %APP_HOME%
--lazygit           cd /d %APP_HOME% && lazygit

============
[内置] 
path/to/foo2.txt

别名                  命令                                                                
------------------  ----------------------------------------------------------------------
--update            cd /d %APP_HOME% && git pull
-u                  wsha.bat --update
--open              start code %APP_HOME%
--lazygit           cd /d %APP_HOME% && lazygit

============
[用户] path/to/foo3.txt

别名                  命令                                                                
------------------  ----------------------------------------------------------------------
--update            cd /d %APP_HOME% && git pull
-u                  wsha.bat --update
--open              start code %APP_HOME%
--lazygit           cd /d %APP_HOME% && lazygit

============

[项目] path/to/foo4.txt

别名                  命令                                                                
------------------  ----------------------------------------------------------------------
--update            cd /d %APP_HOME% && git pull
-u                  wsha.bat --update
--open              start code %APP_HOME%
--lazygit           cd /d %APP_HOME% && lazygit

"""
