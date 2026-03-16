-- wsh-replace-cn-punc 的 Clink 自动补全

local matcher = clink.argmatcher("wsh-replace-cn-punc")

-- 允许重复加载脚本时直接覆盖旧内容。
matcher:reset()
matcher:addflags("-h", "--help")
