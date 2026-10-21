#!/usr/bin/env bash
# ==============================================================================
# PROXYCHAIN-DOCKERV2 — DOCKER CLOUD SANDBOX & LINUX CONTAINER INSTALLER
# Dual-Engine: TraffMonetizer Passive Income + Surfshark WireGuard + Proxy Relay
# ==============================================================================
set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}==============================================================================${NC}"
echo -e "${BOLD}${CYAN}   ⚡ PROXYCHAIN-DOCKERV2 — HYBRID HARVESTER & PROXY GATEWAY INSTALLER       ${NC}"
echo -e "${CYAN}==============================================================================${NC}"

# 1. Root Check
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${YELLOW}[!] Script ini membutuhkan hak akses root. Mengalihkan ke sudo...${NC}"
    exec sudo bash "$0" "$@"
fi

export DEBIAN_FRONTEND=noninteractive
INSTALL_DIR="/opt/proxychain-v2"
SCREEN_NAME="proxychain-v2"

# 2. Package Dependencies
echo -e "${GREEN}[1/6] Memperbarui sistem & menginstall dependensi...${NC}"
apt-get update -y >/dev/null 2>&1 || true
apt-get install -y python3 python3-pip python3-venv git curl proxychains4 wireguard-tools screen lsof procps psmisc net-tools >/dev/null 2>&1

# 3. Download Official TraffMonetizer CLI & WireProxy Binaries
echo -e "${GREEN}[2/6] Menyiapkan binary resmi TraffMonetizer CLI & WireProxy...${NC}"
TM_PATH="/usr/local/bin/cli"
TM_SYMLINK="/usr/local/bin/traffmonetizer"
if [ ! -f "$TM_PATH" ] && [ ! -f "$TM_SYMLINK" ]; then
    echo -e "${YELLOW}Mengunduh binary TraffMonetizer resmi dari Docker Hub via Crane...${NC}"
    curl -sL https://github.com/google/go-containerregistry/releases/latest/download/go-containerregistry_Linux_x86_64.tar.gz | tar -xz -C /usr/local/bin crane 2>/dev/null || true
    chmod +x /usr/local/bin/crane 2>/dev/null || true
    if [ -x "/usr/local/bin/crane" ]; then
        crane export traffmonetizer/cli_v2:latest - | tar -x -C / usr/local/bin/cli 2>/dev/null || true
        rm -f /usr/local/bin/crane
    fi
    chmod +x "$TM_PATH" 2>/dev/null || true
    ln -sf "$TM_PATH" "$TM_SYMLINK" 2>/dev/null || true
fi

WP_PATH="/usr/local/bin/wireproxy"
if [ ! -f "$WP_PATH" ]; then
    echo -e "${YELLOW}Mengunduh binary WireProxy (Userspace WireGuard)...${NC}"
    curl -sL "https://github.com/windtf/wireproxy/releases/download/v1.1.3/wireproxy_linux_amd64.tar.gz" | tar -xz -C /usr/local/bin wireproxy 2>/dev/null || true
    chmod +x "$WP_PATH" 2>/dev/null || true
fi

# 4. Project Directory Setup
echo -e "${GREEN}[3/6] Menyiapkan direktori proyek di ${INSTALL_DIR}...${NC}"
mkdir -p "$INSTALL_DIR"

if [ -f "app.py" ] && [ -d "static" ]; then
    echo -e "${CYAN}Menyalin file dari direktori saat ini...${NC}"
    cp -a . "$INSTALL_DIR/"
else
    REPO_URL="${1:-https://github.com/AbyanZainZ/ProxyChain-DockerV2.git}"
    echo -e "${YELLOW}Mengunduh source code dari ${REPO_URL}...${NC}"
    if [ -d "$INSTALL_DIR/.git" ]; then
        git -C "$INSTALL_DIR" pull || true
    else
        rm -rf "$INSTALL_DIR"
        git clone "$REPO_URL" "$INSTALL_DIR"
    fi
fi

cd "$INSTALL_DIR"

# 5. Setup Python Virtual Environment
echo -e "${GREEN}[4/6] Menyiapkan Python Virtual Environment (venv) & Libraries...${NC}"
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
venv/bin/pip install --upgrade pip >/dev/null 2>&1
venv/bin/pip install -r requirements.txt >/dev/null 2>&1

# 6. Kernel & Limits Tuning
echo -e "${GREEN}[5/6] Tuning Kernel & File Descriptors untuk Skala 1000 Node...${NC}"
ulimit -n 65535 2>/dev/null || true
ulimit -u 65535 2>/dev/null || true
sysctl -w fs.file-max=2097152 2>/dev/null || true

# 7. Runner Loop & CLI Tool
echo -e "${GREEN}[6/6] Menyiapkan Daemon Runner & CLI Tool 'proxychain'...${NC}"
cat << 'EOF' > "$INSTALL_DIR/runner.sh"
#!/usr/bin/env bash
cd /opt/proxychain-v2
export PYTHONUNBUFFERED=1
while true; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting ProxyChain-DockerV2..." >> /opt/proxychain-v2/proxychain-v2.log
    /opt/proxychain-v2/venv/bin/python3 app.py >> /opt/proxychain-v2/proxychain-v2.log 2>&1
    EXIT_CODE=$?
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Process exited with code ${EXIT_CODE}. Restarting in 3 seconds..." >> /opt/proxychain-v2/proxychain-v2.log
    sleep 3
done
EOF
chmod +x "$INSTALL_DIR/runner.sh"

cat << 'EOF' > /usr/local/bin/proxychain
#!/usr/bin/env bash
INSTALL_DIR="/opt/proxychain-v2"
SCREEN_NAME="proxychain-v2"
LOG_FILE="$INSTALL_DIR/proxychain-v2.log"

case "$1" in
    start)
        if screen -list | grep -q "\.${SCREEN_NAME}[[:space:]]"; then
            echo "[!] ProxyChain-V2 sudah berjalan di screen '${SCREEN_NAME}'."
        else
            echo "[+] Menjalankan ProxyChain-V2 di background screen '${SCREEN_NAME}'..."
            screen -dmS "$SCREEN_NAME" bash "$INSTALL_DIR/runner.sh"
            sleep 1
            echo "[✓] ProxyChain-V2 berhasil dijalankan!"
        fi
        ;;
    stop)
        echo "[-] Menghentikan ProxyChain-V2..."
        screen -S "$SCREEN_NAME" -X quit 2>/dev/null || true
        pkill -f "/opt/proxychain-v2/app.py" 2>/dev/null || true
        pkill -f "cli start accept" 2>/dev/null || true
        pkill -f "wireproxy" 2>/dev/null || true
        sleep 1
        echo "[✓] ProxyChain-V2 telah dihentikan."
        ;;
    restart)
        $0 stop
        sleep 1
        $0 start
        ;;
    status)
        echo "======================================================"
        echo " ⚡ PROXYCHAIN-DOCKERV2 — RUNTIME STATUS"
        echo "======================================================"
        if screen -list | grep -q "\.${SCREEN_NAME}[[:space:]]"; then
            echo -e "Screen Daemon  : \033[0;32m● RUNNING\033[0m (Session: ${SCREEN_NAME})"
        else
            echo -e "Screen Daemon  : \033[0;31m○ STOPPED\033[0m"
        fi

        PIDS=$(pgrep -f "/opt/proxychain-v2/app.py" || true)
        if [ -n "$PIDS" ]; then
            echo -e "Python Backend : \033[0;32m● ACTIVE\033[0m (PID: ${PIDS})"
        else
            echo -e "Python Backend : \033[0;31m○ NOT RUNNING\033[0m"
        fi

        TM_COUNT=$(pgrep -f "cli start accept" | wc -l || echo 0)
        WP_COUNT=$(pgrep -f "wireproxy" | wc -l || echo 0)
        echo -e "TraffMonetizer : \033[0;36m${TM_COUNT} workers aktif\033[0m"
        echo -e "WireProxy (WG) : \033[0;36${WP_COUNT} tunnels aktif\033[0m"

        echo ""
        echo "--- 15 Log Terbaru (${LOG_FILE}) ---"
        if [ -f "$LOG_FILE" ]; then
            tail -n 15 "$LOG_FILE"
        else
            echo "Belum ada log tercatat."
        fi
        echo "======================================================"
        ;;
    logs)
        if [ -f "$LOG_FILE" ]; then
            tail -f "$LOG_FILE"
        else
            echo "Log file belum tersedia."
        fi
        ;;
    attach)
        screen -r "$SCREEN_NAME"
        ;;
    token)
        if [ -n "$2" ]; then
            python3 -c "
import json
with open('/opt/proxychain-v2/config.json', 'r') as f:
    cfg = json.load(f)
cfg['traff_token'] = '$2'
with open('/opt/proxychain-v2/config.json', 'w') as f:
    json.dump(cfg, f, indent=2)
print('TraffMonetizer Token updated to: $2')
"
            $0 restart
        else
            echo "Penggunaan: proxychain token <TRAFF_TOKEN>"
        fi
        ;;
    test|check)
        /opt/proxychain-v2/venv/bin/python3 /opt/proxychain-v2/check_relays.py "${2:-10001}" "${3:-10249}"
        ;;
    *)
        echo "Penggunaan: proxychain {start|stop|restart|status|logs|attach|token <TOKEN>|test [START_PORT] [END_PORT]}"
        exit 1
        ;;
esac
EOF
chmod +x /usr/local/bin/proxychain
ln -sf /usr/local/bin/proxychain /usr/local/bin/traffnode 2>/dev/null || true

# Start Service
proxychain start

# Detect URL & Host
HOST_NAME=$(hostname)
if [[ "$HOST_NAME" =~ ^sbx[-_](.+) ]]; then
    SBX_ID="${BASH_REMATCH[1]}"
    DASHBOARD_URL="https://8080-${SBX_ID}.sbx.sandboxes-cloud.docker.com/"
    IS_SANDBOX=true
else
    SERVER_IP=$(curl -s -4 --max-time 3 https://api.ipify.org 2>/dev/null || curl -s -4 --max-time 3 https://ifconfig.me 2>/dev/null || echo "127.0.0.1")
    DASHBOARD_URL="http://${SERVER_IP}:8080"
    IS_SANDBOX=false
fi

echo ""
echo -e "${CYAN}==============================================================================${NC}"
echo -e "${GREEN}${BOLD}🎉 PROXYCHAIN-DOCKERV2 BERHASIL DIINSTALL & DIAKTIFKAN!${NC}"
echo -e "${CYAN}==============================================================================${NC}"
if [ "$IS_SANDBOX" = true ]; then
    echo -e "Web Dashboard : ${YELLOW}${BOLD}${DASHBOARD_URL}${NC}"
    echo -e "                (Pastikan port 8080 sudah ditambahkan di menu 'Connect' -> 'Connect via a Port')"
else
    echo -e "Web Dashboard : ${YELLOW}${DASHBOARD_URL}${NC} (Atau http://127.0.0.1:8080)"
fi
echo -e "Default Auth  : ${CYAN}gemini / gemini${NC}"
echo -e "Port Awal     : ${CYAN}10001 (Port bertambah dinamis sesuai jumlah proxy)${NC}"
echo ""
echo -e "${BOLD}🛠️ Perintah Praktis di Terminal:${NC}"
echo -e "  - Cek Status & Port : ${GREEN}proxychain status${NC}"
echo -e "  - Pantau Log Realtime: ${GREEN}proxychain logs${NC}"
echo -e "  - Pasang Token TM    : ${GREEN}proxychain token <TOKEN_TRAFFMONETIZER>${NC}"
echo -e "  - Stop / Restart     : ${GREEN}proxychain stop${NC} / ${GREEN}proxychain restart${NC}"
echo ""
echo -e "${BOLD}🔑 Akses dari Laptop via SSH Tunnel:${NC}"
echo -e "  ${YELLOW}ssh -N -L 8080:127.0.0.1:8080 -L 10001:127.0.0.1:10001 user@ssh.sandboxes-cloud.docker.com${NC}"
echo -e "${CYAN}==============================================================================${NC}"
