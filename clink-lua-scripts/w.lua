-- w / wsha 的 Clink 自动补全

local helper = dofile((debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\][^/\\]+$") or ".") .. "\\git-utils-common.lua")

local function configure_matcher(matcher)
    -- 允许重复加载脚本时覆盖旧定义，而不是累计叠加。
    matcher:reset()
    matcher:addflags("-h", "--help", "-l", "--list", "-lv", "--list-view")
    matcher:setdelayinit(function(current_matcher)
        local max_tokens = helper.get_max_alias_token_count(helper.load_w_aliases())
        max_tokens = math.max(1, math.min(max_tokens, 8))

        for i = 1, max_tokens do
            current_matcher:addarg(helper.make_w_alias_arg_callback(i))
        end
    end)
end

configure_matcher(clink.argmatcher("w"))
configure_matcher(clink.argmatcher("wsha"))
