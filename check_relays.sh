#!/usr/bin/env bash
# ==============================================================================
# SMART LOCALHOST MULTI-PORT PROXY RELAY CHECKER
# Auto-detects total ports or accepts custom range. Always checks 127.0.0.1.
# ==============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Auto-detect total ports if arguments are not provided
if [ -z "$1" ]; then
    # Auto count from proxies.txt
    PX_FILE="/opt/proxychain-v2/proxies.txt"
    [ ! -f "$PX_FILE" ] && PX_FILE="proxies.txt"
    if [ -f "$PX_FILE" ]; then
        TOTAL_PORTS=$(grep -v '^[[:space:]]*#' "$PX_FILE" | grep -v '^[[:space:]]*$' | wc -l)
    else
        TOTAL_PORTS=50
    fi
    START_PORT=10001
    END_PORT=$((START_PORT + TOTAL_PORTS - 1))
elif [ -z "$2" ]; then
    # Single port test: e.g. bash check_relays.sh 10001
    START_PORT="$1"
    END_PORT="$1"
    TOTAL_PORTS=1
else
    # Range specified: e.g. bash check_relays.sh 10001 10249
    START_PORT="$1"
    END_PORT="$2"
    TOTAL_PORTS=$((END_PORT - START_PORT + 1))
fi

USER="${3:-gemini}"
PASS="${4:-gemini}"
CONCURRENCY=30

echo -e "${CYAN}================================================================${NC}"
echo -e "${BOLD}${CYAN}   ⚡ PROXYCHAIN-DOCKERV2 — LOCALHOST RELAY CHECKER (127.0.0.1)${NC}"
echo -e "${CYAN}================================================================${NC}"
echo -e "Target Host : ${YELLOW}127.0.0.1${NC}"
echo -e "Total Port  : ${YELLOW}${TOTAL_PORTS} port${NC} (Port ${START_PORT} s/d ${END_PORT})"
echo -e "Credentials : ${CYAN}${USER}:${PASS}${NC}"
echo -e "Concurrency : ${CONCURRENCY} workers paralel"
echo -e "${CYAN}----------------------------------------------------------------${NC}"

check_port_loopback() {
    local port="$1"
    local u="$2"
    local p="$3"

    # 1. Test HTTP Proxy on 127.0.0.1
    local resp=$(curl -s -m 4 -x "http://${u}:${p}@127.0.0.1:${port}" "https://api.ipify.org" 2>/dev/null)
    if [ -n "$resp" ] && [[ "$resp" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "\033[0;32m[✓] 127.0.0.1:${port} -> ALIVE (HTTP)   | Exit IP: ${resp}\033[0m"
        return 0
    fi

    # 2. Test SOCKS5 Proxy fallback on 127.0.0.1
    resp=$(curl -s -m 4 -x "socks5h://${u}:${p}@127.0.0.1:${port}" "https://api.ipify.org" 2>/dev/null)
    if [ -n "$resp" ] && [[ "$resp" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "\033[0;32m[✓] 127.0.0.1:${port} -> ALIVE (SOCKS5) | Exit IP: ${resp}\033[0m"
        return 0
    else
        echo -e "\033[0;31m[✗] 127.0.0.1:${port} -> DEAD / TIMEOUT\033[0m"
        return 1
    fi
}
export -f check_port_loopback

seq "$START_PORT" "$END_PORT" | xargs -n 1 -P "$CONCURRENCY" -I {} bash -c "check_port_loopback {} '$USER' '$PASS'"

echo -e "${CYAN}================================================================${NC}"
echo -e "${GREEN}${BOLD}Pemeriksaan relay selesai!${NC}"
