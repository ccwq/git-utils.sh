#!/bin/bash

set -euo pipefail

json_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
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

main() {
    local install_root="${HOME}/.local/share/git-utils.sh"
    local bin_dir="${HOME}/.local/bin"
    local remove_user_config=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --install-root)
                install_root="$2"
                shift 2
                ;;
            --bin-dir)
                bin_dir="$2"
                shift 2
                ;;
            --remove-user-config)
                remove_user_config=1
                shift
                ;;
            --yes)
                shift
                ;;
            *)
                echo "[uninstall] unknown option: $1" >&2
                exit 1
                ;;
        esac
    done

    REMOVED_PATHS=()
    KEPT_PATHS=()

    local launcher
    for launcher in "$bin_dir/w" "$bin_dir/wsha" "$bin_dir/wsh"; do
        if [[ -e "$launcher" ]]; then
            rm -f "$launcher"
            REMOVED_PATHS+=("$launcher")
        fi
    done

    if [[ -d "$install_root" ]]; then
        rm -rf "$install_root"
        REMOVED_PATHS+=("$install_root")
    fi

    if [[ $remove_user_config -eq 1 && -d "$HOME/.config/wsh-alias" ]]; then
        rm -rf "$HOME/.config/wsh-alias"
        REMOVED_PATHS+=("$HOME/.config/wsh-alias")
    elif [[ -d "$HOME/.config/wsh-alias" ]]; then
        KEPT_PATHS+=("$HOME/.config/wsh-alias")
    fi

    local report_path="${HOME}/.local/share/git-utils.sh-uninstall-report.json"
    mkdir -p "$(dirname "$report_path")"
    cat > "$report_path" <<EOF
{
  "uninstall_time": "$(date -Iseconds)",
  "install_root": "$(json_escape "$install_root")",
  "removed_paths": $(json_array REMOVED_PATHS),
  "kept_paths": $(json_array KEPT_PATHS)
}
EOF

    echo "--------------------------------"
    echo "[uninstall] 卸载完成"
    echo "[uninstall] report: $report_path"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
