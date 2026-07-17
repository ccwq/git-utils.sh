#!/bin/bash

# wsha - thin alias command launcher wrapper.
# Core parsing/matching/list/cache logic lives in sh/core/wsha_core.py.

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

set_app_env() {
    local script_dir="$1"
    APP_HOME=$(cd "$script_dir/.." && pwd)
    APP_SH=$(cd "$script_dir" && pwd)
    APP_CONFIG=$(resolve_app_config_dir "$APP_HOME" "$APP_SH")
    export APP_HOME APP_SH APP_CONFIG
    export PATH="$APP_SH:$PATH"
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

invoke_via_core() {
    local entry="$1"
    shift
    local stdout_is_tty=0
    [[ -t 1 ]] && stdout_is_tty=1
    WSHA_STDOUT_IS_TTY="$stdout_is_tty" WSHA_CMDLINE_OUTPUT=sh python "$APP_SH/core/wsha_core.py" --entry "$entry" "$@"
}

invoke_cmd() {
    local cmd_text="$1"
    if [[ "$cmd_text" == "__WSHA_NOOP__" ]]; then
        exit 0
    fi
    local had_msys_arg_conv=false
    local prev_msys_arg_conv_excl="${MSYS2_ARG_CONV_EXCL-}"
    if [[ "$OSTYPE" == msys* || "$OSTYPE" == cygwin* ]]; then
        if is_complex_shell_command "$cmd_text" || [[ "$cmd_text" == *"cmd.exe "* || "$cmd_text" == *"/cmd.exe "* ]]; then
            export MSYS2_ARG_CONV_EXCL='*'
            had_msys_arg_conv=true
        fi
    fi
    if is_complex_shell_command "$cmd_text"; then
        eval -- "$cmd_text"
        local exit_code=$?
        if [[ "$had_msys_arg_conv" == true ]]; then
            if [[ -n "$prev_msys_arg_conv_excl" ]]; then
                export MSYS2_ARG_CONV_EXCL="$prev_msys_arg_conv_excl"
            else
                unset MSYS2_ARG_CONV_EXCL
            fi
        fi
        exit $exit_code
    fi
    eval -- "$cmd_text"
    local exit_code=$?
    if [[ "$had_msys_arg_conv" == true ]]; then
        if [[ -n "$prev_msys_arg_conv_excl" ]]; then
            export MSYS2_ARG_CONV_EXCL="$prev_msys_arg_conv_excl"
        else
            unset MSYS2_ARG_CONV_EXCL
        fi
    fi
    exit $exit_code
}

main() {
    if [[ $# -eq 0 ]]; then
        echo "[wsha] missing alias." >&2
        echo "" >&2
        echo "Run with --help for usage." >&2
        exit 1
    fi

    local step_start
    step_start=$(date +%s%N 2>/dev/null || date +%s000000000)
    local script_dir
    script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    set_app_env "$script_dir"
    log_test_time "set_app_env" "$step_start"

    local first="$1"
    local first_lower="${first,,}"
    if [[ "$first_lower" == "-lv" || "$first_lower" == "--list-view" ]]; then
        set -- "--list" "${@:2}"
    fi

    step_start=$(date +%s%N 2>/dev/null || date +%s000000000)
    local entry="${WSHA_ENTRY:-wsha}"
    local result
    result=$(invoke_via_core "$entry" "$@")
    local core_exit=$?
    log_test_time "invoke_via_core" "$step_start"
    if [[ $core_exit -ne 0 ]]; then
        exit $core_exit
    fi

    case "$first_lower" in
        -h|--help|-l|--list|-lv|--list-view|--clear|--cache-clear)
            [[ -n "$result" ]] && printf '%s\n' "$result"
            exit 0
            ;;
    esac

    if [[ -z "$result" ]]; then
        echo "[wsha] no command returned from wsha_core.py." >&2
        exit 1
    fi

    if [[ "$result" == "$*" ]]; then
        print_exec_cmd "$result"
    else
        print_alias_hit "$entry" "$*" "$result"
        print_exec_cmd "$result"
    fi
    invoke_cmd "$result"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
