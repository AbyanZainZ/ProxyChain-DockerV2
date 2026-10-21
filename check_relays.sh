#!/usr/bin/env bash
# ==============================================================================
# FAST MULTI-PORT PROXY RELAY CHECKER
# Checks ports 10001..10249 simultaneously in parallel (Bash + Curl)
# ==============================================================================

START_PORT="${1:-10001}"
END_PORT="${2:-10249}"
USER="${3:-gemini}"
PASS="${4:-gemini}"
CONCURRENCY="${5:-30}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}================================================================${NC}"
echo -e "${BOLD}${CYAN}   ⚡ PROXYCHAIN-DOCKERV2 — PARALLEL RELAY CHECKER (CURL)     ${NC}"
echo -e "${CYAN}================================================================${NC}"
echo -e "Port Range  : ${YELLOW}${START_PORT}${NC} s/d ${YELLOW}${END_PORT}${NC}"
echo -e "Auth        : ${CYAN}${USER}:${PASS}${NC}"
echo -e "Target URL  : https://api.ipify.org"
echo -e "Concurrency : ${CONCURRENCY} worker paralel"
echo -e "${CYAN}----------------------------------------------------------------${NC}"

check_single_port() {
    local port="$1"
    local u="$2"
    local p="$3"

    # Test HTTP Proxy
    local resp=$(curl -s -m 4 -x "http://${u}:${p}@127.0.0.1:${port}" "https://api.ipify.org" 2>/dev/null)
    if [ -n "$resp" ] && [[ "$resp" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "\033[0;32m[✓] Port ${port}: ALIVE | Exit IP: ${resp}\033[0m"
        return 0
    fi

    # Fallback to SOCKS5
    resp=$(curl -s -m 4 -x "socks5h://${u}:${p}@127.0.0.1:${port}" "https://api.ipify.org" 2>/dev/null)
    if [ -n "$resp" ] && [[ "$resp" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "\033[0;32m[✓] Port ${port}: ALIVE (SOCKS5) | Exit IP: ${resp}\033[0m"
        return 0
    else
        echo -e "\033[0;31m[✗] Port ${port}: DEAD / TIMEOUT\033[0m"
        return 1
    fi
}
export -f check_single_port

seq "$START_PORT" "$END_PORT" | xargs -n 1 -P "$CONCURRENCY" -I {} bash -c "check_single_port {} '$USER' '$PASS'"

echo -e "${CYAN}================================================================${NC}"
echo -e "${GREEN}${BOLD}Pemeriksaan selesai!${NC}"
