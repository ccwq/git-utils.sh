#!/bin/bash

set -euo pipefail

is_windows_host() {
    [[ "${OS:-}" == "Windows_NT" ]] || [[ "$(uname -s)" =~ (MINGW|MSYS|CYGWIN) ]]
}

require_supported_shell() {
    if is_windows_host && [[ -z "${MSYSTEM:-}" ]]; then
        echo "[install] Windows 下请在 Git Bash 中执行安装脚本。" >&2
        exit 1
    fi
}

json_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\t'/\\t}"
    printf '%s' "$value"
}

json_array() {
    local -n ref=$1
    local first=1
    printf '['
    local item
    for item in "${ref[@]}"; do
        [[ $first -eq 1 ]] || printf ','
        printf '"%s"' "$(json_escape "$item")"
        first=0
    done
    printf ']'
}

record_file_copy() {
    local src_path="$1"
    local dst_path="$2"
    local rel_path="$3"

    mkdir -p "$(dirname "$dst_path")"
    if [[ -e "$dst_path" ]]; then
        FILES_OVERWRITTEN+=("$dst_path")
        rm -f "$dst_path"
    else
        FILES_WRITTEN+=("$dst_path")
    fi
    cp "$src_path" "$dst_path"
    COPIED_REL_PATHS+=("$rel_path")
}

write_shell_launcher() {
    local name="$1"
    local target_path="$BIN_DIR/$name"
    local target_cmd="$2"

    mkdir -p "$BIN_DIR"
    if [[ -e "$target_path" ]]; then
        FILES_OVERWRITTEN+=("$target_path")
    else
        FILES_WRITTEN+=("$target_path")
    fi
    cat > "$target_path" <<EOF
#!/bin/bash
export APP_HOME="$INSTALL_ROOT"
export APP_SH="$INSTALL_ROOT/sh"
export APP_CONFIG="$INSTALL_ROOT/sh/config"
exec $target_cmd "\$@"
EOF
    chmod +x "$target_path"
    LAUNCHERS_CREATED+=("$target_path")
}

write_wsh_launcher() {
    local target_path="$BIN_DIR/wsh"
    mkdir -p "$BIN_DIR"
    if [[ -e "$target_path" ]]; then
        FILES_OVERWRITTEN+=("$target_path")
    else
        FILES_WRITTEN+=("$target_path")
    fi
    cat > "$target_path" <<EOF
#!/bin/bash
export APP_HOME="$INSTALL_ROOT"
export APP_SH="$INSTALL_ROOT/sh"
export APP_CONFIG="$INSTALL_ROOT/sh/config"
if [[ \$# -eq 0 || ( \$# -eq 1 && "\$1" == "." ) ]]; then
    exec /usr/bin/bash -i
fi
exec "\$@"
EOF
    chmod +x "$target_path"
    LAUNCHERS_CREATED+=("$target_path")
}

write_windows_launcher() {
    local name="$1"
    local target="$INSTALL_ROOT/bin/$name.bat"

    mkdir -p "$INSTALL_ROOT/bin"
    if [[ -e "$target" ]]; then
        FILES_OVERWRITTEN+=("$target")
    else
        FILES_WRITTEN+=("$target")
    fi
    cat > "$target" <<EOF
@echo off
setlocal EnableExtensions
set "SCRIPT_DIR=%~dp0"
set "APP_HOME=%SCRIPT_DIR%.."
set "APP_SH=%APP_HOME%\\sh"
set "APP_CONFIG=%APP_SH%\\config"
if /i "%~n0"=="w" (
  set "WSHA_ENTRY=w"
  call "%APP_SH%\\core\\exec-git-bash.bat" "%APP_SH%\\wsha.sh" %*
) else if /i "%~n0"=="wsha" (
  call "%APP_SH%\\core\\exec-git-bash.bat" "%APP_SH%\\wsha.sh" %*
) else (
  call "%APP_SH%\\core\\exec-git-bash.bat" %*
)
EOF
}

detect_legacy_layout() {
    if [[ -d "$HOME/.config/wsh-alias" ]]; then
        LEGACY_DETECTED+=("$HOME/.config/wsh-alias")
    fi
}

write_report() {
    local report_path="$INSTALL_ROOT/install-report.json"
    local next_steps_json
    local legacy_json

    next_steps_json=$(json_array NEXT_STEPS)
    legacy_json=$(json_array LEGACY_DETECTED)

    cat > "$report_path" <<EOF
{
  "install_time": "$(date -Iseconds)",
  "platform": "$(is_windows_host && printf 'windows-git-bash' || printf 'unix')",
  "install_root": "$(json_escape "$INSTALL_ROOT")",
  "launchers_created": $(json_array LAUNCHERS_CREATED),
  "files_written": $(json_array FILES_WRITTEN),
  "files_overwritten": $(json_array FILES_OVERWRITTEN),
  "dirs_created": $(json_array DIRS_CREATED),
  "legacy_detected": $legacy_json,
  "migration_suggested": $( [[ ${#LEGACY_DETECTED[@]} -gt 0 ]] && printf 'true' || printf 'false' ),
  "next_steps": $next_steps_json
}
EOF
}

print_summary() {
    echo "--------------------------------"
    echo "[install] 安装完成"
    echo "[install] install_root: $INSTALL_ROOT"
    echo "[install] launchers:"
    local launcher
    for launcher in "${LAUNCHERS_CREATED[@]}"; do
        echo "  - $launcher"
    done
    if [[ ${#LEGACY_DETECTED[@]} -gt 0 ]]; then
        echo "[install] 检测到旧布局，建议人工迁移:"
        local legacy
        for legacy in "${LEGACY_DETECTED[@]}"; do
            echo "  - $legacy"
        done
    fi
    echo "[install] report: $INSTALL_ROOT/install-report.json"
    echo "[install] 说明: Windows 下仅保证 Git Bash 行为。"
}

main() {
    require_supported_shell

    local source_root=""
    INSTALL_ROOT="${HOME}/.local/share/git-utils.sh"
    BIN_DIR="${HOME}/.local/bin"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --source)
                source_root="$2"
                shift 2
                ;;
            --install-root)
                INSTALL_ROOT="$2"
                shift 2
                ;;
            --bin-dir)
                BIN_DIR="$2"
                shift 2
                ;;
            *)
                echo "[install] unknown option: $1" >&2
                exit 1
                ;;
        esac
    done

    if [[ -z "$source_root" ]]; then
        source_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
    else
        source_root=$(cd "$source_root" && pwd)
    fi

    if [[ ! -d "$source_root/sh" ]]; then
        echo "[install] invalid source root: $source_root" >&2
        exit 1
    fi

    FILES_WRITTEN=()
    FILES_OVERWRITTEN=()
    DIRS_CREATED=()
    LAUNCHERS_CREATED=()
    LEGACY_DETECTED=()
    NEXT_STEPS=()
    COPIED_REL_PATHS=()

    if [[ ! -d "$INSTALL_ROOT" ]]; then
        DIRS_CREATED+=("$INSTALL_ROOT")
    fi
    if [[ ! -d "$INSTALL_ROOT/sh" ]]; then
        DIRS_CREATED+=("$INSTALL_ROOT/sh")
    fi
    if [[ ! -d "$INSTALL_ROOT/bin" ]]; then
        DIRS_CREATED+=("$INSTALL_ROOT/bin")
    fi
    if [[ ! -d "$BIN_DIR" ]]; then
        DIRS_CREATED+=("$BIN_DIR")
    fi

    mkdir -p "$INSTALL_ROOT/sh" "$INSTALL_ROOT/bin" "$BIN_DIR"

    while IFS= read -r -d '' src_path; do
        local rel_path="${src_path#$source_root/}"
        local dst_path="$INSTALL_ROOT/$rel_path"
        record_file_copy "$src_path" "$dst_path" "$rel_path"
    done < <(find "$source_root/sh" -type f -print0)

    if [[ -f "$source_root/bin/tcping.exe" ]]; then
        record_file_copy "$source_root/bin/tcping.exe" "$INSTALL_ROOT/bin/tcping.exe" "bin/tcping.exe"
    fi

    write_shell_launcher "w" "\"$INSTALL_ROOT/sh/w.sh\""
    write_shell_launcher "wsha" "\"$INSTALL_ROOT/sh/wsha.sh\""
    write_wsh_launcher

    if is_windows_host; then
        write_windows_launcher "w"
        write_windows_launcher "wsha"
        write_windows_launcher "wsh"
    fi

    detect_legacy_layout

    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        NEXT_STEPS+=("add $BIN_DIR to PATH")
    fi
    if is_windows_host; then
        NEXT_STEPS+=("run installed commands from Git Bash")
    fi

    write_report
    print_summary
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
