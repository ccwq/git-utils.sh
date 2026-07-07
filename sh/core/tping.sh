#!/bin/bash
# curl_ping.sh - 用 curl 模拟 HTTP(S) 连通性持续探测

HOST="$1"
PORT="$2"
INTERVAL="${3:-1}"    # 探测间隔，默认1秒
SCHEME="$4"
CONNECT_TIMEOUT=3
MAX_TIME=5

if [ -t 2 ]; then
    RED=$'\033[31m'
    GREEN=$'\033[32m'
    ORANGE=$'\033[33m'
    BLUE=$'\033[34m'
    NC=$'\033[0m'
else
    RED=""
    GREEN=""
    ORANGE=""
    BLUE=""
    NC=""
fi

CAN_READ_KEY=0
if [ -t 0 ]; then
    CAN_READ_KEY=1
fi

log() {
    printf "$@" >&2
}

stop_by_interrupt() {
    log "\n收到 Ctrl+C，停止探测。\n"
    exit 130
}

trap stop_by_interrupt INT

if [ -z "$HOST" ] || [ -z "$PORT" ]; then
    log "用法: %s <host> <port> [interval] [http|https]\n" "$0"
    exit 1
fi

if [ -z "$SCHEME" ]; then
    if [ "$PORT" = "443" ]; then
        SCHEME="https"
    else
        SCHEME="http"
    fi
fi

if [ "$SCHEME" != "http" ] && [ "$SCHEME" != "https" ]; then
    log "错误: scheme 只能是 http 或 https\n"
    exit 1
fi

URL="${SCHEME}://${HOST}:${PORT}/"

SEQ=0
log "开始持续探测 %s，连接超时=%ss，总超时=%ss，间隔=%ss\n" "$URL" "$CONNECT_TIMEOUT" "$MAX_TIME" "$INTERVAL"
if [ "$CAN_READ_KEY" -eq 1 ]; then
    log "按 Ctrl+C 或 c 停止探测。\n"
else
    log "按 Ctrl+C 停止探测。\n"
fi
log "%-6s %10s %10s %10s %10s %10s   %s\n" "seq" "total_ms" "dns_ms" "tcp_ms" "tls_ms" "first_ms" "result"

while true; do
    SEQ=$((SEQ+1))

    # 用 HTTP(S) 请求触发完整连接并主动结束，避免 telnet:// 连接成功后长期等待输入。
    RESULT=$(curl -o /dev/null -s --head \
        -w "%{time_total} %{time_namelookup} %{time_connect} %{time_appconnect} %{time_starttransfer}" \
        --connect-timeout "$CONNECT_TIMEOUT" \
        --max-time "$MAX_TIME" \
        "$URL" 2>&1)
    CURL_EXIT=$?
    read -r TIME_TOTAL TIME_NAMELOOKUP TIME_CONNECT TIME_APPCONNECT TIME_STARTTRANSFER _ <<< "$RESULT"

    if [ "$CURL_EXIT" -eq 0 ]; then
        STATUS="成功"
    else
        STATUS="失败 curl_exit=$CURL_EXIT"
    fi

    awk \
        -v seq="$SEQ" \
        -v total="$TIME_TOTAL" \
        -v dns="$TIME_NAMELOOKUP" \
        -v tcp="$TIME_CONNECT" \
        -v tls="$TIME_APPCONNECT" \
        -v first_byte="$TIME_STARTTRANSFER" \
        -v status="$STATUS" \
        -v curl_exit="$CURL_EXIT" \
        -v red="$RED" \
        -v green="$GREEN" \
        -v orange="$ORANGE" \
        -v blue="$BLUE" \
        -v nc="$NC" \
        'BEGIN {
            total_ms = total * 1000
            color = red
            if (curl_exit == 0) {
                if (total_ms <= 500) {
                    color = green
                } else if (total_ms <= 1000) {
                    color = blue
                } else if (total_ms <= 2000) {
                    color = orange
                }
            }
            printf "%s%-6d %10.2f %10.2f %10.2f %10.2f %10.2f   %s%s\n",
                color, seq, total_ms, dns * 1000, tcp * 1000, tls * 1000, first_byte * 1000, status, nc
        }' >&2

    if [ "$CAN_READ_KEY" -eq 1 ] && read -r -s -n 1 -t "$INTERVAL" KEY; then
        if [ "$KEY" = "c" ] || [ "$KEY" = "C" ]; then
            log "收到 c，停止探测。\n"
            exit 0
        fi
    else
        sleep "$INTERVAL"
    fi
done
