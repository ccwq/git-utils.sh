-- wsh-real-ignore 的 Clink 自动补全

local matcher = clink.argmatcher("wsh-real-ignore")

-- 允许重复加载脚本时直接覆盖旧内容。
matcher:reset()
matcher:addflags("-h", "--help")
