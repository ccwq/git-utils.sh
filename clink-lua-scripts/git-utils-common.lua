-- git-utils.sh 的 Clink 自动补全公共函数

local M = {}

local function get_source_dir()
    local source = debug.getinfo(1, "S").source
    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end
    return source:match("^(.*)[/\\][^/\\]+$") or "."
end

local ROOT_DIR = (function()
    local dir = get_source_dir()
    return dir:gsub("[/\\]clink%-lua%-scripts$", "")
end)()

local function join_path(...)
    local parts = {...}
    local normalized = table.concat(parts, "\\")
    return (normalized:gsub("[/\\]+", "\\"))
end

local function file_exists(path)
    local handle = io.open(path, "r")
    if handle then
        handle:close()
        return true
    end
    return false
end

local function trim(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function starts_with(text, prefix)
    return text:sub(1, #prefix) == prefix
end

local function split_command_text(text)
    local tokens = {}
    local current = {}
    local in_quote = false

    for i = 1, #text do
        local ch = text:sub(i, i)
        if ch == '"' then
            in_quote = not in_quote
        elseif ch:match("%s") and not in_quote then
            if #current > 0 then
                tokens[#tokens + 1] = table.concat(current)
                current = {}
            end
        else
            current[#current + 1] = ch
        end
    end

    if #current > 0 then
        tokens[#tokens + 1] = table.concat(current)
    end

    return tokens
end

local function each_line(path, fn)
    local handle = io.open(path, "r")
    if not handle then
        return
    end

    for line in handle:lines() do
        fn(line:gsub("\r$", ""))
    end

    handle:close()
end

local function parse_alias_line(line)
    local content = trim(line)
    if content == "" or starts_with(content, "#") then
        return nil
    end

    if starts_with(content, '"') then
        local alias_name, template = content:match('^"([^"]+)"%s+(.+)$')
        if alias_name and template then
            return alias_name, trim(template)
        end
        return nil
    end

    local alias_name, template = content:match("^(%S+)%s+(.+)$")
    if alias_name and template then
        return alias_name, trim(template)
    end

    return nil
end

local function get_w_alias_config_paths()
    local cwd = os.getcwd()
    local user_profile = os.getenv("USERPROFILE") or ""

    return {
        join_path(ROOT_DIR, "config", "wsh-alias.txt"),
        user_profile ~= "" and join_path(user_profile, ".config", "wsh-alias.txt") or nil,
        cwd and join_path(cwd, ".config", "wsh-alias.txt") or nil,
    }
end

function M.load_w_aliases()
    local alias_order = {}
    local alias_map = {}

    for _, path in ipairs(get_w_alias_config_paths()) do
        if path and file_exists(path) then
            each_line(path, function(line)
                local alias_name, template = parse_alias_line(line)
                if not alias_name then
                    return
                end

                if not alias_map[alias_name] then
                    alias_order[#alias_order + 1] = alias_name
                end

                alias_map[alias_name] = {
                    alias = alias_name,
                    template = template,
                    tokens = split_command_text(alias_name),
                    source = path,
                }
            end)
        end
    end

    local aliases = {}
    for _, alias_name in ipairs(alias_order) do
        aliases[#aliases + 1] = alias_map[alias_name]
    end

    return aliases
end

function M.get_max_alias_token_count(aliases)
    local max_count = 1
    for _, entry in ipairs(aliases) do
        if #entry.tokens > max_count then
            max_count = #entry.tokens
        end
    end
    return max_count
end

local function escape_lua_pattern(text)
    return (text:gsub("([%%%^%$%(%)%.%[%]%+%-%?])", "%%%1"))
end

local function token_matches(pattern, value)
    if not value or value == "" then
        return false
    end

    if not pattern:find("%*") then
        return pattern == value
    end

    local lua_pattern = "^" .. escape_lua_pattern(pattern)
        :gsub("%*%*", ".+")
        :gsub("%*", "[^%s]+") .. "$"
    return value:match(lua_pattern) ~= nil
end

local function token_suggestion(pattern)
    if not pattern:find("%*") then
        return pattern
    end

    local literal_prefix = pattern:match("^([^*]+)")
    if literal_prefix and literal_prefix ~= "" then
        return literal_prefix
    end

    return nil
end

local function collect_words(line_state)
    local command_index = 1
    if line_state and line_state.getcommandwordindex then
        command_index = line_state:getcommandwordindex()
    end

    local words = {}
    local word_count = line_state and line_state.getwordcount and line_state:getwordcount() or 0
    for i = command_index, word_count do
        words[#words + 1] = line_state:getword(i)
    end

    return command_index, words
end

local function extract_callback_context(...)
    local ctx = {
        word_index = nil,
        line_state = nil,
        match_builder = nil,
        current_word = "",
    }

    for _, value in ipairs({...}) do
        local value_type = type(value)
        if value_type == "number" and not ctx.word_index then
            ctx.word_index = value
        elseif value_type == "string" and ctx.current_word == "" then
            ctx.current_word = value
        elseif (value_type == "table" or value_type == "userdata") and not ctx.line_state then
            local ok, has_method = pcall(function()
                return value.getwordcount ~= nil
            end)
            if ok and has_method then
                ctx.line_state = value
            end
        end

        if (value_type == "table" or value_type == "userdata") and not ctx.match_builder then
            local ok, has_method = pcall(function()
                return value.addmatch ~= nil
            end)
            if ok and has_method then
                ctx.match_builder = value
            end
        end
    end

    if ctx.current_word == "" and ctx.line_state and ctx.word_index and ctx.line_state.getword then
        local ok, word = pcall(function()
            return ctx.line_state:getword(ctx.word_index)
        end)
        if ok and type(word) == "string" then
            ctx.current_word = word
        end
    end

    return ctx
end

local function emit_matches(matches, match_builder)
    if match_builder and match_builder.addmatch then
        for _, item in ipairs(matches) do
            match_builder:addmatch(item)
        end
        return true
    end

    return matches
end

function M.make_w_alias_arg_callback(position)
    return function(...)
        local ctx = extract_callback_context(...)
        local aliases = M.load_w_aliases()
        local _, words = collect_words(ctx.line_state)
        local args = {}
        for i = 2, math.min(#words, position) do
            args[#args + 1] = words[i]
        end

        local current_word = ctx.current_word or ""
        local known = {}
        local matches = {}

        for _, value in ipairs(args) do
            if type(value) == "string" and starts_with(value, "-") then
                return emit_matches({}, ctx.match_builder)
            end
        end

        for _, entry in ipairs(aliases) do
            local ok = true
            for idx = 1, position - 1 do
                local input_value = args[idx]
                local alias_token = entry.tokens[idx]
                if not input_value or not alias_token or not token_matches(alias_token, input_value) then
                    ok = false
                    break
                end
            end

            if ok then
                local candidate = entry.tokens[position]
                candidate = candidate and token_suggestion(candidate) or nil
                if candidate and starts_with(candidate:lower(), current_word:lower()) and not known[candidate] then
                    known[candidate] = true
                    matches[#matches + 1] = candidate
                end
            end
        end

        table.sort(matches)
        return emit_matches(matches, ctx.match_builder)
    end
end

function M.load_ping_presets()
    local path = join_path(ROOT_DIR, "config", "wsh-ping.txt")
    local presets = {}
    if not file_exists(path) then
        return presets
    end

    each_line(path, function(line)
        local content = trim(line)
        if content == "" or starts_with(content, "#") then
            return
        end

        local name, host, port = content:match("^(%S+)%s+(%S+)%s+(%S+)$")
        if name and host and port then
            presets[#presets + 1] = {
                name = name,
                host = host,
                port = port,
            }
        end
    end)

    return presets
end

function M.make_ping_host_callback()
    return function(...)
        local ctx = extract_callback_context(...)
        local current_word = (ctx.current_word or ""):lower()
        local matches = {}
        local known = {}

        for _, preset in ipairs(M.load_ping_presets()) do
            for _, value in ipairs({preset.name, preset.host}) do
                if not known[value] and starts_with(value:lower(), current_word) then
                    known[value] = true
                    matches[#matches + 1] = value
                end
            end
        end

        table.sort(matches)
        return emit_matches(matches, ctx.match_builder)
    end
end

function M.make_ping_port_callback()
    return function(...)
        local ctx = extract_callback_context(...)
        local _, words = collect_words(ctx.line_state)
        local host_value = words[2]
        if not host_value then
            return emit_matches({}, ctx.match_builder)
        end

        local current_word = ctx.current_word or ""
        local matches = {}
        local known = {}

        for _, preset in ipairs(M.load_ping_presets()) do
            if preset.name == host_value or preset.host == host_value then
                if not known[preset.port] and starts_with(preset.port, current_word) then
                    known[preset.port] = true
                    matches[#matches + 1] = preset.port
                end
            end
        end

        table.sort(matches)
        return emit_matches(matches, ctx.match_builder)
    end
end

local function run_command_lines(command)
    local pipe = io.popen(command)
    if not pipe then
        return {}
    end

    local result = {}
    for line in pipe:lines() do
        line = trim(line:gsub("\r$", ""))
        if line ~= "" then
            result[#result + 1] = line
        end
    end
    pipe:close()

    return result
end

function M.load_git_refs()
    local refs = {}
    local known = {}

    local commands = {
        'git branch --format="%(refname:short)" 2>nul',
        'git tag --sort=-creatordate 2>nul',
    }

    for _, command in ipairs(commands) do
        for _, line in ipairs(run_command_lines(command)) do
            if not known[line] then
                known[line] = true
                refs[#refs + 1] = line
            end
        end
    end

    return refs
end

function M.make_fpatch_ref_callback(position)
    local option_requires_value = {
        ["-o"] = true,
        ["--output"] = true,
        ["-i"] = true,
        ["--input"] = true,
        ["-e"] = true,
        ["--exclude"] = true,
    }

    return function(...)
        local ctx = extract_callback_context(...)
        local _, words = collect_words(ctx.line_state)
        local positional_index = 0
        local skip_next = false

        for idx = 2, #words do
            local value = words[idx]
            if idx == #words then
                break
            end

            if skip_next then
                skip_next = false
            elseif option_requires_value[value] then
                skip_next = true
            elseif not starts_with(value, "-") then
                positional_index = positional_index + 1
            end
        end

        if skip_next then
            return emit_matches({}, ctx.match_builder)
        end

        positional_index = positional_index + 1
        if positional_index ~= position then
            return emit_matches({}, ctx.match_builder)
        end

        local current_word = (ctx.current_word or ""):lower()
        local matches = {}
        for _, ref in ipairs(M.load_git_refs()) do
            if starts_with(ref:lower(), current_word) then
                matches[#matches + 1] = ref
            end
        end

        table.sort(matches)
        return emit_matches(matches, ctx.match_builder)
    end
end

M.ROOT_DIR = ROOT_DIR
M.join_path = join_path

return M
