# ⚡ ProxyChain-DockerV2

> **All-in-One Hybrid Passive Income Harvester & Inbound Authenticated Proxy Gateway**  
> Menggabungkan **TraffMonetizer Passive Income** + **Surfshark WireGuard (925 Node Fisik)** + **ProxyChain Multi-Port Relay Gateway** dalam paket siap Docker & Cloud Sandbox.

---

## 🌟 Fitur Utama V2:

1. **💰 TraffMonetizer Bandwidth Monetization**:
   - Menjalankan instance TraffMonetizer pada setiap node proxy (Custom Proxy maupun Surfshark WireGuard) untuk menghasilkan pasif income dollar dari bandwidth sharing.
2. **⚡ Inbound Authenticated Relay Gateway**:
   - Membuka port relay (`IP:10001..N:gemini:gemini`) dengan autentikasi seragam dan auto-sensing HTTP/SOCKS5 untuk bot, browser, atau scraper Anda.
3. **🦈 925 Server Fisik Surfshark WireGuard**:
   - Didukung file database `surfshark_servers.json` berisi 925 server global yang dapat digenerate dan dimonetisasi tanpa penalti duplicate IP.
4. **🐳 Full Docker & Cloud Sandbox Support**:
   - `Dockerfile` dengan pre-installed official TraffMonetizer CLI v2 dan WireProxy.
   - `docker-compose.yml` dengan `network_mode: host` untuk Linux VPS.
   - Script instalasi 1-baris `install_sandbox.sh` non-systemd untuk [Docker Agentic Platform](https://agentic-platform.docker.com/sandboxes/new).
5. **🛠️ Management CLI 'proxychain'**:
   - `proxychain status`, `proxychain logs`, `proxychain token <TOKEN>`, `proxychain restart`.

---

## 🚀 Cara Menjalankan

### 1. Di Docker Cloud Sandbox:
```bash
curl -fsSL https://raw.githubusercontent.com/AbyanZainZ/ProxyChain-DockerV2/main/install_sandbox.sh | bash
```

### 2. Di VPS Linux via Docker Compose:
```bash
docker compose up -d
docker compose logs -f
```

### 3. Di Localhost Windows:
Klik ganda file `run_localhost.bat`.
Akses dashboard di: `http://127.0.0.1:8080`
