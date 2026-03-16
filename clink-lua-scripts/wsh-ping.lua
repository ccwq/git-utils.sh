-- wsh-ping 的 Clink 自动补全

local helper = dofile((debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\][^/\\]+$") or ".") .. "\\git-utils-common.lua")

local matcher = clink.argmatcher("wsh-ping")

-- 允许重复加载脚本时直接覆盖旧内容。
matcher:reset()
matcher
    :addflags(
        "-h", "--help",
        "-4", "-6", "-D", "-I", "-c", "-i", "-j", "-r", "-t", "-u", "-v",
        "--csv", "--db", "--no-color", "--pretty",
        "--show-failures-only", "--show-source-address"
    )
    :addarg(helper.make_ping_host_callback())
    :addarg(helper.make_ping_port_callback())
