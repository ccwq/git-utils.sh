#!/bin/bash

# wsha - alias command launcher (bash 版本)
# 将 wsha.ps1 的功能移植为 bash 脚本，支持 Git Bash 和系统 bash

# 显示帮助信息
show_help() {
    cat <<'EOF'
wsha - alias command launcher

Usage:
  w <alias> [args...]
  w --list | -l
  w --list-view | -lv

Config priority:
  1. sh/config/wsh-alias/*.txt  (APP_HOME)
  2. $HOME/.config/wsh-alias/*.txt
  3. $PWD/.config/wsh-alias/*.txt

Rules:
  - Ignore empty lines and lines starting with '#'
  - Files starting with '_' are ignored (e.g. _disabled.txt)
  - Same alias: first wins (loaded alphabetically within each dir)
  - Prefix & for sequential execution (stop on error)
  - Prefix | for or execution (stop on success)
  - Inject env vars: %APP_HOME%, %APP_SH%, %APP_CONFIG%
  - Alias can be quoted to include spaces, like "pcodex l"
  - Alias supports '*' wildcard (single token capture), map to $1..$N
  - Alias supports '**' wildcard (match all remaining input), map to $$
  - If template contains '--', runtime args are inserted there
  - Otherwise runtime args are appended at the end
  - '-l' uses table view in console
  - '-lv' opens table view (fallback to table in non-GUI env)
  - If alias not found, run original command directly

Example:
  pcodex pnpx @openai/codex
  "pcodex l" pnpx @openai/codex@latest
  "px*" pnpx $1
  "px *" "pnpx $1"
  "s**" wsh $$

  w pcodex               > pnpx @openai/codex
  w pcodex l             > pnpx @openai/codex@latest
  w pxhttp-server        > pnpx http-server
  w px http-server       > pnpx http-server
  w sls -l               > wsh ls -l
EOF
}

resolve_app_config_dir() {
    local app_home="$1"
    local app_sh="$2"
    local new_dir="$app_sh/config"
    local old_dir="$app_home/config"

    # 新布局优先，旧布局仅作为兼容 fallback。
    if [[ -d "$new_dir" || ! -d "$old_dir" ]]; then
        printf '%s' "$new_dir"
    else
        printf '%s' "$old_dir"
    fi
}

# 设置应用环境变量（精简版：不再遍历 sh 目录生成 wrapper）
set_app_env() {
    local script_dir="$1"
    APP_HOME=$(cd "$script_dir/.." && pwd)
    APP_SH=$(cd "$script_dir" && pwd)
    APP_CONFIG=$(resolve_app_config_dir "$APP_HOME" "$APP_SH")
    export APP_HOME APP_SH APP_CONFIG
    export PATH="$APP_SH:$PATH"
    wsha() { bash "$APP_SH/wsha.sh" "$@"; }
    w() { bash "$APP_SH/w.sh" "$@"; }
    export -f wsha w
}

token_basename_lower() {
    local token="$1"
    token="${token##*\\}"
    token="${token##*/}"
    printf '%s' "${token,,}"
}

is_complex_shell_command() {
    local text="$1"
    [[ "$text" == *"&&"* ]] && return 0
    [[ "$text" == *"||"* ]] && return 0
    [[ "$text" == *"|"* ]] && return 0
    [[ "$text" == *";"* ]] && return 0
    [[ "$text" == *">"* ]] && return 0
    [[ "$text" == *"<"* ]] && return 0
    [[ "$text" == *'$('* ]] && return 0
    [[ "$text" == *'`'* ]] && return 0
    return 1
}

# 调用 wsha-core.py 获取展开后的命令
invoke_via_core() {
    local entry="$1"
    shift
    uv run python "$APP_SH/wsha-core.py" -e "$entry" "$@"
}

should_print_exec() {
    [[ "${WSHA_PRINT_EXEC:-1}" != "0" ]]
}

print_exec_cmd() {
    local cmd_text="$1"
    if should_print_exec; then
        echo "[wsha] exec: $cmd_text" >&2
    fi
}

print_alias_hit() {
    local entry="$1"
    local raw_input="$2"
    local final_cmd="$3"
    echo "[wsha] alias hit: $entry $raw_input -> $final_cmd" >&2
}

normalize_runtime_tokens() {
    local -a tokens=("$@")
    _CMD_TOKENS=("${tokens[@]}")
    [[ ${#_CMD_TOKENS[@]} -gt 0 ]] || return 0

    local first_lower
    first_lower=$(token_basename_lower "${_CMD_TOKENS[0]}")

    case "$first_lower" in
        wsha.bat)
            _CMD_TOKENS=(bash "$APP_SH/wsha.sh" "${_CMD_TOKENS[@]:1}")
            ;;
        w.bat)
            _CMD_TOKENS=(env WSHA_ENTRY=w bash "$APP_SH/wsha.sh" "${_CMD_TOKENS[@]:1}")
            ;;
        wsh.bat)
            if [[ ${#_CMD_TOKENS[@]} -ge 2 && "${_CMD_TOKENS[1]}" == "." ]]; then
                _CMD_TOKENS=(/usr/bin/bash -i)
            else
                _CMD_TOKENS=("${_CMD_TOKENS[@]:1}")
            fi
            ;;
    esac

    [[ ${#_CMD_TOKENS[@]} -gt 0 ]] || return 0

    first_lower=$(token_basename_lower "${_CMD_TOKENS[0]}")
    if [[ "$first_lower" == "docker" || "$first_lower" == "podman" ]]; then
        _CMD_TOKENS=(env MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*" "${_CMD_TOKENS[@]}")
    fi
}

log_test_time() {
    [[ "${WSHA_TEST_TIME_LABEL:-}" == "1" ]] || return 0
    local label="$1"
    local start_ns="$2"
    local end_ns
    end_ns=$(date +%s%N 2>/dev/null || date +%s000000000)
    awk -v label="$label" -v start="$start_ns" -v end="$end_ns" 'BEGIN {
        printf("[wsha][time] %s: %.3fs\n", label, (end - start) / 1000000000)
    }' >&2
}

# 规范化路径字符串
normalize_path() {
    local p="$1"
    if [[ -z "$p" ]]; then
        echo ""
        return
    fi
    # 尝试获取绝对路径
    if [[ -e "$p" ]]; then
        cd "$(dirname "$p")" && echo "$(pwd)/$(basename "$p")"
        cd - > /dev/null
    else
        echo "$p"
    fi
}

# ============================================================
# 配置解析相关
# ============================================================

# 全局数据结构：用并行数组模拟 alias map
# ALIAS_KEYS[i] = alias 名称（按插入顺序，不重复）
# ALIAS_TEMPLATES[i] = 对应的模板
# ALIAS_CONFIG_PATHS[i] = 来源配置文件路径
# ALIAS_SOURCE_NAMES[i] = 来源名称
# ALIAS_TOKEN_DATA[i] = 预解析后的 token，使用 Unit Separator 分隔
# ALIAS_TOKEN_COUNTS[i] = token 数量
# ALIAS_DOUBLE_INDEXES[i] = ** token 位置，-1 表示无
# ALIAS_LITERAL_CHARS[i] = 去掉空格和通配符后的字面量长度
# ALIAS_STATIC_WILDCARDS[i] = 固定通配符权重，用于评分
# ALIAS_FIRST_TOKEN_MODE[i] = literal / wildcard
# ALIAS_FIRST_TOKEN_LOWER[i] = 首 token 小写值（仅 literal 模式有效）
declare -a ALIAS_KEYS=()
declare -a ALIAS_TEMPLATES=()
declare -a ALIAS_CONFIG_PATHS=()
declare -a ALIAS_SOURCE_NAMES=()
declare -a ALIAS_TOKEN_DATA=()
declare -a ALIAS_TOKEN_COUNTS=()
declare -a ALIAS_DOUBLE_INDEXES=()
declare -a ALIAS_LITERAL_CHARS=()
declare -a ALIAS_STATIC_WILDCARDS=()
declare -a ALIAS_FIRST_TOKEN_MODE=()
declare -a ALIAS_FIRST_TOKEN_LOWER=()
declare -a ALIAS_PREFIX_TYPES=()   # normal / sequential(&) / or(|)

# 首 token 分桶索引：literal 首 token 走按 key 分桶，wildcard 首 token 走公共桶
declare -A ALIAS_BUCKETS_BY_FIRST=()
declare -a ALIAS_BUCKETS_WILDCARD_FIRST=()

ALIAS_TOKEN_SEP=$'\x1f'
WSHA_CACHE_VERSION='v4'

# 重置 alias 数据结构
reset_alias_data() {
    ALIAS_KEYS=()
    ALIAS_TEMPLATES=()
    ALIAS_CONFIG_PATHS=()
    ALIAS_SOURCE_NAMES=()
    ALIAS_TOKEN_DATA=()
    ALIAS_TOKEN_COUNTS=()
    ALIAS_DOUBLE_INDEXES=()
    ALIAS_LITERAL_CHARS=()
    ALIAS_STATIC_WILDCARDS=()
    ALIAS_FIRST_TOKEN_MODE=()
    ALIAS_FIRST_TOKEN_LOWER=()
    ALIAS_PREFIX_TYPES=()
    ALIAS_BUCKETS_BY_FIRST=()
    ALIAS_BUCKETS_WILDCARD_FIRST=()
}

# 将 token 数组序列化为单字符串
serialize_tokens() {
    local -a tokens=("$@")
    local serialized=""
    local token
    for token in "${tokens[@]}"; do
        if [[ -n "$serialized" ]]; then
            serialized+="$ALIAS_TOKEN_SEP"
        fi
        serialized+="$token"
    done
    printf '%s' "$serialized"
}

# 反序列化 token 字符串到全局 _TOKENS
deserialize_tokens() {
    local serialized="$1"
    _TOKENS=()
    [[ -n "$serialized" ]] || return 0
    IFS="$ALIAS_TOKEN_SEP" read -r -a _TOKENS <<< "$serialized"
}

# 为单个 alias 构建预解析元数据
build_alias_metadata() {
    local idx="$1"
    local alias_name="${ALIAS_KEYS[$idx]}"
    get_tokens "$alias_name"
    local -a alias_tokens=("${_TOKENS[@]}")
    local alias_count=${#alias_tokens[@]}
    local double_token_index=-1
    local wildcard_weight=0
    local literal_chars=0
    local first_mode="wildcard"
    local first_lower=""
    local token
    local ti

    if [[ $alias_count -gt 0 ]]; then
        if [[ "${alias_tokens[0]}" != *'*'* ]]; then
            first_mode="literal"
            first_lower="${alias_tokens[0],,}"
        fi
    fi

    for ((ti = 0; ti < alias_count; ti++)); do
        token="${alias_tokens[$ti]}"
        if [[ "$token" == *'**'* ]]; then
            if [[ $double_token_index -eq -1 ]]; then
                double_token_index=$ti
            else
                double_token_index=-2
            fi
            wildcard_weight=$((wildcard_weight + 1000))
        elif [[ "$token" == *'*'* ]]; then
            local tmp="$token"
            while [[ "$tmp" == *'*'* ]]; do
                tmp="${tmp#*\*}"
                wildcard_weight=$((wildcard_weight + 1))
            done
        fi
    done

    local stripped="${alias_name//\*\*/}"
    stripped="${stripped//\*/}"
    stripped="${stripped// /}"
    literal_chars=${#stripped}

    ALIAS_TOKEN_DATA[$idx]="$(serialize_tokens "${alias_tokens[@]}")"
    ALIAS_TOKEN_COUNTS[$idx]="$alias_count"
    ALIAS_DOUBLE_INDEXES[$idx]="$double_token_index"
    ALIAS_LITERAL_CHARS[$idx]="$literal_chars"
    ALIAS_STATIC_WILDCARDS[$idx]="$wildcard_weight"
    ALIAS_FIRST_TOKEN_MODE[$idx]="$first_mode"
    ALIAS_FIRST_TOKEN_LOWER[$idx]="$first_lower"
}

# 重建分桶索引，降低匹配时的候选集规模
rebuild_alias_buckets() {
    ALIAS_BUCKETS_BY_FIRST=()
    ALIAS_BUCKETS_WILDCARD_FIRST=()

    local i
    for ((i = 0; i < ${#ALIAS_KEYS[@]}; i++)); do
        local first_mode="${ALIAS_FIRST_TOKEN_MODE[$i]}"
        if [[ "$first_mode" == "literal" ]]; then
            local bucket_key="${ALIAS_FIRST_TOKEN_LOWER[$i]}"
            if [[ -n "${ALIAS_BUCKETS_BY_FIRST[$bucket_key]:-}" ]]; then
                ALIAS_BUCKETS_BY_FIRST[$bucket_key]+=",$i"
            else
                ALIAS_BUCKETS_BY_FIRST[$bucket_key]="$i"
            fi
        else
            ALIAS_BUCKETS_WILDCARD_FIRST+=("$i")
        fi
    done
}

# 返回配置文件的版本戳，用于缓存命中判断
get_file_stamp() {
    local file_path="$1"
    if [[ ! -f "$file_path" ]]; then
        printf 'missing'
        return 0
    fi
    local mtime
    local size
    mtime=$(stat -c '%Y' "$file_path" 2>/dev/null || echo 0)
    size=$(stat -c '%s' "$file_path" 2>/dev/null || echo 0)
    printf '%s:%s' "$mtime" "$size"
}

# 生成缓存 key
build_cache_key() {
    local mode="$1"
    shift
    local key="version=$WSHA_CACHE_VERSION|mode=$mode"
    local config_path
    for config_path in "$@"; do
        key+="|$config_path|$(get_file_stamp "$config_path")"
    done
    printf '%s' "$key"
}

# 生成短缓存文件名，避免 Windows 路径过长
hash_cache_key() {
    local cache_key="$1"
    if command -v sha1sum >/dev/null 2>&1; then
        printf '%s' "$cache_key" | sha1sum | awk '{print $1}'
        return 0
    fi
    printf '%s' "$cache_key" | cksum | awk '{print $1 "-" $2}'
}

# 获取缓存文件路径
get_cache_file_path() {
    local scope_key="$1"
    local cache_dir="$HOME/.cache/wsha"
    mkdir -p "$cache_dir"
    printf '%s/%s.cache.sh' "$cache_dir" "$scope_key"
}

# 从缓存文件恢复解析结果
load_alias_cache() {
    local cache_file="$1"
    local expected_key="$2"
    [[ -f "$cache_file" ]] || return 1
    reset_alias_data
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == KEY$'\t'* ]]; then
            [[ "${line#KEY$'\t'}" == "$expected_key" ]] || return 1
            continue
        fi
        [[ "$line" == DATA$'\t'* ]] || continue
        local first_lower
        IFS=$'\t' read -r _tag key template config_path source_name token_data token_count double_index literal_chars static_wildcards first_mode first_lower prefix_type <<< "$line"
        ALIAS_KEYS+=("$key")
        ALIAS_TEMPLATES+=("$template")
        ALIAS_CONFIG_PATHS+=("$config_path")
        ALIAS_SOURCE_NAMES+=("$source_name")
        ALIAS_TOKEN_DATA+=("$token_data")
        ALIAS_TOKEN_COUNTS+=("$token_count")
        ALIAS_DOUBLE_INDEXES+=("$double_index")
        ALIAS_LITERAL_CHARS+=("$literal_chars")
        ALIAS_STATIC_WILDCARDS+=("$static_wildcards")
        ALIAS_FIRST_TOKEN_MODE+=("$first_mode")
        ALIAS_FIRST_TOKEN_LOWER+=("$first_lower")
        ALIAS_PREFIX_TYPES+=("${prefix_type:-normal}")
    done < "$cache_file"
    rebuild_alias_buckets
    return 0
}

# 将解析结果写入缓存文件
write_alias_cache() {
    local cache_file="$1"
    local cache_key="$2"
    local temp_file="${cache_file}.tmp"
    mkdir -p "$(dirname "$cache_file")"
    {
        printf 'KEY\t%s\n' "$cache_key"
        local i
        for ((i = 0; i < ${#ALIAS_KEYS[@]}; i++)); do
            printf 'DATA\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                "${ALIAS_KEYS[$i]}" \
                "${ALIAS_TEMPLATES[$i]}" \
                "${ALIAS_CONFIG_PATHS[$i]}" \
                "${ALIAS_SOURCE_NAMES[$i]}" \
                "${ALIAS_TOKEN_DATA[$i]}" \
                "${ALIAS_TOKEN_COUNTS[$i]}" \
                "${ALIAS_DOUBLE_INDEXES[$i]}" \
                "${ALIAS_LITERAL_CHARS[$i]}" \
                "${ALIAS_STATIC_WILDCARDS[$i]}" \
                "${ALIAS_FIRST_TOKEN_MODE[$i]}" \
                "${ALIAS_FIRST_TOKEN_LOWER[$i]}" \
                "${ALIAS_PREFIX_TYPES[$i]:-normal}"
        done
    } > "$temp_file" && mv -f "$temp_file" "$cache_file"
}

# 查找 alias 在 ALIAS_KEYS 中的索引，找不到返回 -1
find_alias_index() {
    local target="$1"
    local i
    for ((i = 0; i < ${#ALIAS_KEYS[@]}; i++)); do
        if [[ "${ALIAS_KEYS[$i]}" == "$target" ]]; then
            echo "$i"
            return
        fi
    done
    echo "-1"
}

# 解析配置文件的一行，输出 "alias<TAB>template" 或空
parse_config_line() {
    local line="$1"
    local config_path="$2"
    local line_no="$3"

    # 去除前导空白
    local trimmed="${line#"${line%%[![:space:]]*}"}"
    # 空行或注释行跳过
    if [[ -z "$trimmed" ]] || [[ "$trimmed" == \#* ]]; then
        return 0
    fi

    local alias_name=""
    local template=""

    if [[ "$trimmed" == \"* ]]; then
        # 引号包裹的 alias
        if [[ "$trimmed" =~ ^\"([^\"]+)\"[[:space:]]+(.*)$ ]]; then
            alias_name="${BASH_REMATCH[1]}"
            template="${BASH_REMATCH[2]}"
            # 去除 template 前导空白
            template="${template#"${template%%[![:space:]]*}"}"
        else
            echo "[wsha] invalid config at line $line_no in \"$config_path\": missing alias" >&2
            return 1
        fi
    else
        # 非引号 alias
        if [[ "$trimmed" =~ ^([^[:space:]]+)[[:space:]]+(.*)$ ]]; then
            alias_name="${BASH_REMATCH[1]}"
            template="${BASH_REMATCH[2]}"
            template="${template#"${template%%[![:space:]]*}"}"
        elif [[ "$trimmed" =~ ^[^[:space:]]+$ ]]; then
            echo "[wsha] invalid config at line $line_no in \"$config_path\": alias \"$trimmed\" has no target command" >&2
            return 1
        else
            echo "[wsha] invalid config at line $line_no in \"$config_path\": missing alias" >&2
            return 1
        fi
    fi

    if [[ -z "$alias_name" ]]; then
        echo "[wsha] invalid config at line $line_no in \"$config_path\": missing alias" >&2
        return 1
    fi
    if [[ -z "$template" ]]; then
        echo "[wsha] invalid config at line $line_no in \"$config_path\": alias \"$alias_name\" has no target command" >&2
        return 1
    fi

    # 去除 template 外层引号（如果首尾都是双引号）
    if [[ ${#template} -ge 2 && "$template" == \"*\" ]]; then
        template="${template:1:${#template}-2}"
    fi

    # 检查 & 或 | 前缀，设置执行模式
    _PARSED_PREFIX="normal"
    if [[ "$alias_name" == \&* ]]; then
        _PARSED_PREFIX="sequential"
        alias_name="${alias_name:1}"
    elif [[ "$alias_name" == \|* ]]; then
        _PARSED_PREFIX="or"
        alias_name="${alias_name:1}"
    fi

    # 通过全局变量返回
    _PARSED_ALIAS="$alias_name"
    _PARSED_TEMPLATE="$template"
    return 0
}

# 加载目录中的所有 *.txt 文件，跳过 _ 前缀文件，按字母序排序
load_config_dir() {
    local dir_path="$1"
    local fail_on_duplicate="$2"
    local source_name="$3"

    if [[ -z "$dir_path" ]] || [[ ! -d "$dir_path" ]]; then return 0; fi

    # glob 获取 *.txt 文件（1层深）
    local -a txt_files=()
    for f in "$dir_path"/*.txt; do
        [[ -f "$f" ]] && txt_files+=("$f")
    done

    if [[ ${#txt_files[@]} -eq 0 ]]; then return 0; fi

    # 冒泡排序（按字母序，避免外部依赖）
    local sorted=false
    local n=${#txt_files[@]}
    while [[ "$sorted" == false ]]; do
        sorted=true
        local i
        for ((i=0; i<n-1; i++)); do
            if [[ "${txt_files[$i]}" > "${txt_files[$((i+1))]}" ]]; then
                local tmp="${txt_files[$i]}"
                txt_files[$i]="${txt_files[$((i+1))]}"
                txt_files[$((i+1))]="$tmp"
                sorted=false
            fi
        done
        ((n--))
    done

    local file
    for file in "${txt_files[@]}"; do
        local basename="${file##*/}"
        # 跳过 _ 前缀文件
        [[ "$basename" == _* ]] && continue
        load_single_config_file "$file" "$fail_on_duplicate" "$source_name" || return 1
    done
    return 0
}

# 加载单个配置文件到全局 alias map
load_single_config_file() {
    local config_path="$1"
    local fail_on_duplicate="$2"
    local source_name="$3"

    if [[ -z "$config_path" ]]; then return 0; fi
    if [[ ! -f "$config_path" ]]; then return 0; fi

    local line_no=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        line=$(printf '%s' "$line" | tr -d '\r')
        ((line_no++))

        _PARSED_ALIAS=""
        _PARSED_TEMPLATE=""
        if ! parse_config_line "$line" "$config_path" "$line_no"; then
            return 1
        fi
        if [[ -z "$_PARSED_ALIAS" ]]; then
            continue
        fi

        local idx
        idx=$(find_alias_index "$_PARSED_ALIAS")

        if [[ "$fail_on_duplicate" == "true" && "$idx" -ge 0 ]]; then
            echo "[wsha] duplicate alias \"$_PARSED_ALIAS\" at line $line_no in \"$config_path\"" >&2
            return 1
        fi

        if [[ "$idx" -ge 0 ]]; then
            # 多源目录合并使用后加载覆盖前加载；单文件重复已在上方拦截。
            ALIAS_TEMPLATES[$idx]="$_PARSED_TEMPLATE"
            ALIAS_CONFIG_PATHS[$idx]="$config_path"
            ALIAS_SOURCE_NAMES[$idx]="$source_name"
            build_alias_metadata "$idx"
            ALIAS_PREFIX_TYPES[$idx]="$_PARSED_PREFIX"
        else
            ALIAS_KEYS+=("$_PARSED_ALIAS")
            ALIAS_TEMPLATES+=("$_PARSED_TEMPLATE")
            ALIAS_CONFIG_PATHS+=("$config_path")
            ALIAS_SOURCE_NAMES+=("$source_name")
            idx=$((${#ALIAS_KEYS[@]} - 1))
            build_alias_metadata "$idx"
            ALIAS_PREFIX_TYPES[$idx]="$_PARSED_PREFIX"
        fi
    done < "$config_path"

    return 0
}

# 按当前配置集合加载 alias，优先命中缓存
load_config() {
    local mode="$1"
    shift
    local -a config_specs=("$@")
    local -a cache_paths=()
    local spec

    # 为 dir 类型展开文件列表，用于构建精确缓存 key
    for spec in "${config_specs[@]}"; do
        IFS='|' read -r _spec_path _spec_dup _spec_source _spec_dir <<< "$spec"
        if [[ "$_spec_dir" == "dir" ]]; then
            if [[ -d "$_spec_path" ]]; then
                for f in "$_spec_path"/*.txt; do
                    [[ -f "$f" ]] && cache_paths+=("$f")
                done
            else
                cache_paths+=("$_spec_path")  # 目录不存在时记为 missing
            fi
        else
            cache_paths+=("$_spec_path")
        fi
    done

    local cache_key
    local cache_scope
    local cache_file
    cache_key=$(build_cache_key "$mode" "${cache_paths[@]}")
    cache_scope=$(hash_cache_key "$cache_key")
    cache_file=$(get_cache_file_path "$cache_scope")

    reset_alias_data
    if load_alias_cache "$cache_file" "$cache_key"; then
        return 0
    fi

    for spec in "${config_specs[@]}"; do
        local config_path
        local fail_on_duplicate
        local source_name
        local spec_dir
        IFS='|' read -r config_path fail_on_duplicate source_name spec_dir <<< "$spec"
        if [[ "$spec_dir" == "dir" ]]; then
            if ! load_config_dir "$config_path" "$fail_on_duplicate" "$source_name"; then
                return 1
            fi
        else
            if ! load_single_config_file "$config_path" "$fail_on_duplicate" "$source_name"; then
                return 1
            fi
        fi
    done

    rebuild_alias_buckets
    write_alias_cache "$cache_file" "$cache_key"
    return 0
}

# ============================================================
# 列表显示相关
# ============================================================

# ANSI 颜色码（支持 Git Bash / Linux / macOS）
if [[ -t 1 || -n "${FORCE_COLOR:-}" ]]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_GREEN=$'\033[32m'     # 别名
    C_CYAN=$'\033[36m'      # 表头
    C_YELLOW=$'\033[33m'    # 来源路径
    C_DIM=$'\033[2m'        # 分隔线
else
    C_RESET=''
    C_BOLD=''
    C_GREEN=''
    C_CYAN=''
    C_YELLOW=''
    C_DIM=''
fi

# 来源描述符数组
declare -a SOURCE_NAMES=()
declare -a SOURCE_PATHS=()

# 显示列表（表格模式）
show_list_table() {
    local found_any=false
    local -a group_paths=()
    local i

    # 按配置文件路径分组，保留首次出现顺序
    for ((i = 0; i < ${#ALIAS_CONFIG_PATHS[@]}; i++)); do
        local config_path="${ALIAS_CONFIG_PATHS[$i]}"
        local seen=false
        local existing
        for existing in "${group_paths[@]}"; do
            if [[ "$existing" == "$config_path" ]]; then
                seen=true
                break
            fi
        done
        if [[ "$seen" == false ]]; then
            group_paths+=("$config_path")
        fi
    done

    for config_path in "${group_paths[@]}"; do
        local -a group_aliases=()
        local -a group_templates=()
        local source_name=""
        local display_path=""
        local display_dir=""
        local display_file=""

        # 收集属于该配置文件的条目
        for ((i = 0; i < ${#ALIAS_KEYS[@]}; i++)); do
            if [[ "${ALIAS_CONFIG_PATHS[$i]}" == "$config_path" ]]; then
                group_aliases+=("${ALIAS_KEYS[$i]}")
                group_templates+=("${ALIAS_TEMPLATES[$i]}")
                [[ -z "$source_name" ]] && source_name="${ALIAS_SOURCE_NAMES[$i]}"
            fi
        done

        if [[ ${#group_aliases[@]} -eq 0 ]]; then
            continue
        fi
        found_any=true

        # 自定义单文件展示完整路径；多源目录模式展示来源目录，保持与现有测试一致。
        display_path="$config_path"
        if [[ "$source_name" == "自定义" ]]; then
            display_dir="$display_path"
        else
            local src_index=-1
            case "$source_name" in
                "内置") src_index=0 ;;
                "用户") src_index=1 ;;
                "项目") src_index=2 ;;
            esac
            if [[ $src_index -ge 0 && -n "${SOURCE_PATHS[$src_index]:-}" ]]; then
                display_dir="${SOURCE_PATHS[$src_index]}"
            else
                display_dir=$(dirname "$display_path")
            fi
        fi

        if [[ -z "$source_name" ]]; then
            source_name="unknown"
        fi
        printf "%s[%s] %s%s\n" "$C_YELLOW$C_BOLD" "$source_name" "$display_dir" "$C_RESET"
        echo ""

        # 按当前文件组计算双列宽度，保证别名列和命令列持续对齐。
        local max_alias_len=0
        local max_command_len=0
        local j
        for ((j = 0; j < ${#group_aliases[@]}; j++)); do
            local alen=${#group_aliases[$j]}
            local clen=${#group_templates[$j]}
            if [[ $alen -gt $max_alias_len ]]; then
                max_alias_len=$alen
            fi
            if [[ $clen -gt $max_command_len ]]; then
                max_command_len=$clen
            fi
        done

        local header_alias="别名"
        local header_command="命令"
        if [[ ${#header_alias} -gt $max_alias_len ]]; then
            max_alias_len=${#header_alias}
        fi
        if [[ ${#header_command} -gt $max_command_len ]]; then
            max_command_len=${#header_command}
        fi

        # 表头、分隔线和数据行统一使用同一列宽。
        printf "%s%-${max_alias_len}s  %-${max_command_len}s%s\n" "$C_CYAN$C_BOLD" "$header_alias" "$header_command" "$C_RESET"
        printf "%s%-${max_alias_len}s  %-${max_command_len}s%s\n" "$C_DIM" "${header_alias//?/-}" "${header_command//?/-}" "$C_RESET"
        for ((j = 0; j < ${#group_aliases[@]}; j++)); do
            printf "%s%-${max_alias_len}s  %-${max_command_len}s%s\n" "$C_GREEN" "${group_aliases[$j]}" "${group_templates[$j]}" "$C_RESET"
        done
        echo ""
    done

    if [[ "$found_any" == false ]]; then
        printf "%s[wsha] no alias found.%s\n" "$C_DIM" "$C_RESET"
    fi
}

# 显示列表视图（在非 GUI 环境下回退到表格）
show_list_grid_view() {
    # bash 环境下直接使用表格输出
    show_list_table
}

# ============================================================
# 通配符匹配相关
# ============================================================

# 将文本按空白分割为 token 数组，结果存入全局 _TOKENS
declare -a _TOKENS=()
get_tokens() {
    local text="$1"
    _TOKENS=()
    if [[ -z "$text" ]]; then return; fi
    # 禁用 glob 展开，防止 * 被展开为文件名
    set -f
    local word
    for word in $text; do
        if [[ -n "$word" ]]; then
            _TOKENS+=("$word")
        fi
    done
    set +f
}

# 将 glob 模式转换为正则表达式（单 token 匹配）
# 结果存入 _MATCH_OK, _MATCH_CAPTURES[], _MATCH_WILDCARDS
_MATCH_OK=false
declare -a _MATCH_CAPTURES=()
_MATCH_WILDCARDS=0

match_token_pattern() {
    local pattern="$1"
    local token="$2"
    _MATCH_OK=false
    _MATCH_CAPTURES=()
    _MATCH_WILDCARDS=0

    # 不含通配符，直接比较（忽略大小写）
    if [[ "$pattern" != *'*'* ]]; then
        local pat_lower="${pattern,,}"
        local tok_lower="${token,,}"
        if [[ "$pat_lower" == "$tok_lower" ]]; then
            _MATCH_OK=true
        fi
        return
    fi

    # 含通配符，构建正则
    # 按 * 分割 pattern
    local regex="^"
    local remaining="$pattern"
    local first=true
    local wildcard_count=0

    while [[ "$remaining" == *'*'* ]]; do
        local before="${remaining%%\**}"
        remaining="${remaining#*\*}"
        # 转义 before 中的正则特殊字符
        local escaped_before
        escaped_before=$(printf '%s' "$before" | sed 's/[.[\^$+?{}|()]/\\&/g')
        if [[ "$first" == true ]]; then
            regex+="$escaped_before"
            first=false
        else
            regex+="$escaped_before"
        fi
        regex+="(.*?)"
        ((wildcard_count++))
    done
    # 追加剩余部分
    local escaped_remaining
    escaped_remaining=$(printf '%s' "$remaining" | sed 's/[.[\^$+?{}|()]/\\&/g')
    regex+="$escaped_remaining"
    regex+='$'

    _MATCH_WILDCARDS=$wildcard_count

    # 使用 bash 的 =~ 进行匹配（不支持 lazy，但单 token 通常够用）
    # 将 (.*?) 替换为 (.*)，bash 不支持 lazy
    regex="${regex//\(.\*\?\)/(.*)}"

    local tok_lower="${token,,}"
    local pat_test
    if [[ "$tok_lower" =~ $regex ]]; then
        _MATCH_OK=true
        local g
        for ((g = 1; g < ${#BASH_REMATCH[@]}; g++)); do
            _MATCH_CAPTURES+=("${BASH_REMATCH[$g]}")
        done
    fi
}

# 双星号匹配：匹配 pattern 中 ** 之前的前缀，捕获剩余部分
# 结果存入 _DSTAR_OK, _DSTAR_CAPTURES[], _DSTAR_REST
_DSTAR_OK=false
declare -a _DSTAR_CAPTURES=()
_DSTAR_REST=""

match_double_star_remainder() {
    local pattern="$1"
    local input_text="$2"
    _DSTAR_OK=false
    _DSTAR_CAPTURES=()
    _DSTAR_REST=""

    # 查找 ** 的位置
    local idx=-1
    local tmp="$pattern"
    local pos=0
    while [[ -n "$tmp" ]]; do
        if [[ "$tmp" == \*\** ]]; then
            idx=$pos
            break
        fi
        tmp="${tmp:1}"
        ((pos++))
    done

    if [[ $idx -lt 0 ]]; then return; fi

    local head="${pattern:0:$idx}"
    local tail="${pattern:$((idx + 2))}"

    # 构建正则
    local head_regex
    head_regex=$(printf '%s' "$head" | sed 's/[.[\^$+?{}|()]/\\&/g')
    head_regex="${head_regex//\\\*/(.*?)}"

    local tail_regex
    tail_regex=$(printf '%s' "$tail" | sed 's/[.[\^$+?{}|()]/\\&/g')
    tail_regex="${tail_regex//\\\*/(.*?)}"

    local full_regex="^${head_regex}(.*?)${tail_regex}\$"
    # bash 不支持 lazy，替换为 greedy
    full_regex="${full_regex//\(.\*\?\)/(.*)}"

    local input_lower="${input_text,,}"
    if [[ "$input_lower" =~ $full_regex ]]; then
        _DSTAR_OK=true
        local total_groups=$(( ${#BASH_REMATCH[@]} - 1 ))
        # 最后一个捕获组之前的是 head 的捕获，最后一个是 rest（** 捕获的部分）
        # 实际上 ** 对应的捕获组位置取决于 head 中 * 的数量
        # head 中的 * 数量
        local head_stars=0
        local htmp="$head"
        while [[ "$htmp" == *'*'* ]]; do
            htmp="${htmp#*\*}"
            ((head_stars++))
        done

        local g
        for ((g = 1; g <= head_stars; g++)); do
            _DSTAR_CAPTURES+=("${BASH_REMATCH[$g]}")
        done
        # ** 对应的捕获组
        _DSTAR_REST="${BASH_REMATCH[$((head_stars + 1))]}"
    fi
}

# ============================================================
# 最佳匹配查找
# ============================================================

# 结果存入全局变量
_BEST_ALIAS=""
_BEST_TEMPLATE=""
declare -a _BEST_CAPTURES=()
_BEST_REST_CAPTURE=""
_BEST_ARGS_START=0

find_best_match() {
    local -a input_tokens=("$@")
    local input_count=${#input_tokens[@]}

    _BEST_ALIAS=""
    _BEST_TEMPLATE=""
    _BEST_CAPTURES=()
    _BEST_REST_CAPTURE=""
    _BEST_ARGS_START=0

    local best_score=-1
    local -a candidate_indexes=()
    local first_token_lower=""
    if [[ $input_count -gt 0 ]]; then
        first_token_lower="${input_tokens[0],,}"
    fi

    if [[ -n "$first_token_lower" && -n "${ALIAS_BUCKETS_BY_FIRST[$first_token_lower]:-}" ]]; then
        IFS=',' read -r -a candidate_indexes <<< "${ALIAS_BUCKETS_BY_FIRST[$first_token_lower]}"
    fi
    candidate_indexes+=("${ALIAS_BUCKETS_WILDCARD_FIRST[@]}")

    local ai
    for ai in "${candidate_indexes[@]}"; do
        [[ -n "$ai" ]] || continue

        local alias="${ALIAS_KEYS[$ai]}"
        local template="${ALIAS_TEMPLATES[$ai]}"
        local alias_count="${ALIAS_TOKEN_COUNTS[$ai]}"
        local double_token_index="${ALIAS_DOUBLE_INDEXES[$ai]}"
        [[ $alias_count -gt 0 ]] || continue
        [[ $double_token_index -ne -2 ]] || continue
        if [[ $double_token_index -ge 0 && $double_token_index -ne $((alias_count - 1)) ]]; then
            continue
        fi
        if [[ $double_token_index -lt 0 && $input_count -lt $alias_count ]]; then
            continue
        fi
        if [[ $double_token_index -ge 0 && $input_count -lt $((double_token_index + 1)) ]]; then
            continue
        fi

        deserialize_tokens "${ALIAS_TOKEN_DATA[$ai]}"
        local -a alias_tokens=("${_TOKENS[@]}")
        local ok=true
        local wildcard_count=0
        local -a captures=()
        local rest_capture=""
        local input_consumed=0
        local ti
        for ((ti = 0; ti < alias_count; ti++)); do
            if [[ $ti -eq $double_token_index ]]; then
                local remain_text="${input_tokens[$ti]}"
                local ri
                for ((ri = ti + 1; ri < input_count; ri++)); do
                    remain_text+=" ${input_tokens[$ri]}"
                done

                match_double_star_remainder "${alias_tokens[$ti]}" "$remain_text"
                if [[ "$_DSTAR_OK" != true || -z "$_DSTAR_REST" ]]; then
                    ok=false
                    break
                fi
                captures+=("${_DSTAR_CAPTURES[@]}")
                rest_capture="$_DSTAR_REST"
                wildcard_count=$((wildcard_count + 1000))
                input_consumed=$input_count
                continue
            fi

            match_token_pattern "${alias_tokens[$ti]}" "${input_tokens[$ti]}"
            if [[ "$_MATCH_OK" != true ]]; then
                ok=false
                break
            fi
            wildcard_count=$((wildcard_count + _MATCH_WILDCARDS))
            captures+=("${_MATCH_CAPTURES[@]}")
            input_consumed=$((ti + 1))
        done

        [[ "$ok" == true ]] || continue

        local score=$(( alias_count * 10000 + ALIAS_LITERAL_CHARS[$ai] * 100 - wildcard_count ))
        if [[ $score -gt $best_score ]]; then
            best_score=$score
            _BEST_ALIAS="$alias"
            _BEST_TEMPLATE="$template"
            _BEST_CAPTURES=("${captures[@]}")
            _BEST_REST_CAPTURE="$rest_capture"
            _BEST_ARGS_START=$input_consumed
        fi
    done
}

# ============================================================
# 命令执行
# ============================================================

# 展开字符串中的 %VAR% 风格环境变量
expand_env_vars() {
    local text="$1"
    local result="$text"
    # 循环匹配 %VAR_NAME% 并替换为对应环境变量值
    while [[ "$result" =~ %([A-Za-z_][A-Za-z0-9_]*)% ]]; do
        local var_name="${BASH_REMATCH[1]}"
        local var_value="${!var_name:-}"
        result="${result//%${var_name}%/$var_value}"
    done
    echo "$result"
}

# 执行最终命令
invoke_cmd() {
    local cmd_text="$1"
    # 展开 %VAR% 风格的环境变量
    cmd_text=$(expand_env_vars "$cmd_text")
    if ! is_complex_shell_command "$cmd_text"; then
        get_tokens "$cmd_text"
        local -a cmd_tokens=("${_TOKENS[@]}")
        normalize_runtime_tokens "${cmd_tokens[@]}"
        "${_CMD_TOKENS[@]}"
        exit $?
    fi
    local had_msys_arg_conv=false
    local prev_msys_arg_conv_excl="${MSYS2_ARG_CONV_EXCL-}"
    if [[ "$OSTYPE" == msys* || "$OSTYPE" == cygwin* ]]; then
        export MSYS2_ARG_CONV_EXCL='*'
        had_msys_arg_conv=true
    fi

    set -f
    eval -- "$cmd_text"
    local exit_code=$?
    set +f

    if [[ $exit_code -eq 1 && "$cmd_text" == tasklist*" | findstr "* ]]; then
        exit_code=0
    fi

    if [[ "$had_msys_arg_conv" == true ]]; then
        if [[ -n "$prev_msys_arg_conv_excl" ]]; then
            export MSYS2_ARG_CONV_EXCL="$prev_msys_arg_conv_excl"
        else
            unset MSYS2_ARG_CONV_EXCL
        fi
    fi

    exit $exit_code
}

# ============================================================
# 主入口
# ============================================================
main() {
    if [[ $# -eq 0 ]]; then
        echo "[wsha] missing alias." >&2
        echo "" >&2
        echo "Run with --help for usage." >&2
        exit 1
    fi

    local step_start
    local first="$1"
    # 帮助信息
    local first_lower="${first,,}"
    if [[ "$first_lower" == "-h" || "$first_lower" == "--help" ]]; then
        show_help
        exit 0
    fi

    # 设置环境变量
    local script_dir
    step_start=$(date +%s%N 2>/dev/null || date +%s000000000)
    script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    set_app_env "$script_dir"
    log_test_time "set_app_env" "$step_start"

    # 配置目录路径（支持目录 glob 加载）
    local builtin_config_dir="$APP_CONFIG/wsh-alias"
    local user_config_dir="$HOME/.config/wsh-alias"
    local local_config_dir="$(pwd)/.config/wsh-alias"

    # 加载配置
    local single_config="${WSHA_CONFIG_FILE:-}"
    if [[ -z "$single_config" ]]; then
        step_start=$(date +%s%N 2>/dev/null || date +%s000000000)
        SOURCE_NAMES=("内置" "用户" "项目")
        SOURCE_PATHS=("$builtin_config_dir" "$user_config_dir" "$local_config_dir")

        if ! load_config "multi" \
            "$builtin_config_dir|false|内置|dir" \
            "$user_config_dir|false|用户|dir" \
            "$local_config_dir|false|项目|dir"; then exit 1; fi
        log_test_time "load_config" "$step_start"
    else
        step_start=$(date +%s%N 2>/dev/null || date +%s000000000)
        SOURCE_NAMES=("自定义")
        SOURCE_PATHS=("$single_config")

        if ! load_config "single" "$single_config|true|自定义"; then exit 1; fi
        log_test_time "load_config" "$step_start"
    fi

    # 列表模式
    if [[ "$first_lower" == "-l" || "$first_lower" == "--list" ]]; then
        show_list_table
        exit 0
    fi

    if [[ "$first_lower" == "-lv" || "$first_lower" == "--list-view" ]]; then
        if [[ "${WSHA_TEST_GRID_CAPTURE:-}" == "1" ]]; then
            show_list_table
        else
            show_list_grid_view
        fi
        exit 0
    fi

    # 调用 wsha-core.py
    step_start=$(date +%s%N 2>/dev/null || date +%s000000000)
    local entry="${WSHA_ENTRY:-wsha}"
    local result
    result=$(invoke_via_core "$entry" "$@")
    log_test_time "invoke_via_core" "$step_start"

    if [[ -n "$result" ]]; then
        # 判断是否为透传（原样返回）还是展开结果
        if [[ "$result" == "$*" ]]; then
            print_exec_cmd "$result"
            # 透传，直接执行原始命令
            if is_complex_shell_command "$result"; then
                eval -- "$result"
            else
                invoke_cmd "$result"
            fi
        else
            # 展开后的命令，执行它
            print_alias_hit "${WSHA_ENTRY:-wsha}" "$*" "$result"
            print_exec_cmd "$result"
            invoke_cmd "$result"
        fi
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
