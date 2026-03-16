-- wsh-fpatch 的 Clink 自动补全

local helper = dofile((debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\][^/\\]+$") or ".") .. "\\git-utils-common.lua")

local matcher = clink.argmatcher("wsh-fpatch")

-- 允许重复加载脚本时直接覆盖旧内容。
matcher:reset()
matcher
    :addflags("-h", "--help", "-o", "--output", "-i", "--input", "-e", "--exclude")
    :addarg(helper.make_fpatch_ref_callback(1))
    :addarg(helper.make_fpatch_ref_callback(2))
