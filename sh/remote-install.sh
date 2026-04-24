#!/bin/bash

set -euo pipefail

require_git_bash_on_windows() {
    if [[ "${OS:-}" == "Windows_NT" && -z "${MSYSTEM:-}" ]]; then
        echo "[remote-install] Windows 下请在 Git Bash 中执行。" >&2
        exit 1
    fi
}

download_with_retry() {
    local url="$1"
    local output_path="$2"
    local round attempt

    for round in 1 2; do
        for attempt in 1 2; do
            if curl -fsSL "$url" -o "$output_path"; then
                return 0
            fi
            [[ $attempt -lt 2 ]] && sleep 10
        done
        [[ $round -lt 2 ]] && sleep 25
    done

    return 1
}

main() {
    require_git_bash_on_windows

    local archive_url="${INSTALL_ARCHIVE_URL:-https://github.com/ccwq/git-utils.sh/archive/refs/heads/master.tar.gz}"
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' EXIT

    local archive_path="$tmp_dir/git-utils.sh.tar.gz"
    if ! download_with_retry "$archive_url" "$archive_path"; then
        echo "[remote-install] 下载失败: $archive_url" >&2
        exit 1
    fi

    tar -xzf "$archive_path" -C "$tmp_dir"
    local source_root
    source_root=$(find "$tmp_dir" -mindepth 1 -maxdepth 1 -type d | head -n 1)

    if [[ -z "$source_root" || ! -f "$source_root/sh/install.sh" ]]; then
        echo "[remote-install] 解压后未找到 sh/install.sh" >&2
        exit 1
    fi

    bash "$source_root/sh/install.sh" --source "$source_root" "$@"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
