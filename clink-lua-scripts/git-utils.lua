-- git-utils.sh 的 Clink 自动补全聚合入口

local script_dir = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\][^/\\]+$") or "."

dofile(script_dir .. "\\w.lua")
dofile(script_dir .. "\\wsh.lua")
dofile(script_dir .. "\\wsh-ping.lua")
dofile(script_dir .. "\\wsh-fpatch.lua")
dofile(script_dir .. "\\wsh-real-ignore.lua")
dofile(script_dir .. "\\wsh-replace-cn-punc.lua")
