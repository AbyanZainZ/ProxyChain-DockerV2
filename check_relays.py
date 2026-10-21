#!/usr/bin/env python3
"""
Smart Multi-Port Proxy Relay Checker for ProxyChain-DockerV2
Automatically detects total active relay ports or checks specified range.
Always tests directly against 127.0.0.1:<PORT>.
"""
import sys
import os
import time
import json
import asyncio
import httpx

# ANSI Colors
GREEN = "\033[0;32m"
RED = "\033[0;31m"
YELLOW = "\033[1;33m"
CYAN = "\033[0;36m"
BOLD = "\033[1m"
NC = "\033[0m"

CONCURRENCY = 40
TARGET_URL = "http://api.ipify.org"

def auto_detect_ports() -> tuple[list[int], str, str]:
    """Auto-detect active relay ports and credentials from API or files."""
    user = "gemini"
    password = "gemini"
    start_port = 10001
    ports: list[int] = []

    # 1. Try querying local API
    try:
        with httpx.Client(timeout=2.0) as client:
            res = client.get("http://127.0.0.1:8080/api/relay/active-list")
            if res.status_code == 200:
                data = res.json()
                active_ports = data.get("ports", [])
                if active_ports:
                    return active_ports, data.get("user", user), data.get("password", password)
    except Exception:
        pass

    # 2. Try reading config.json
    cfg_path = "/opt/proxychain-v2/config.json"
    if not os.path.exists(cfg_path):
        cfg_path = "config.json"
    if os.path.exists(cfg_path):
        try:
            with open(cfg_path, "r", encoding="utf-8") as f:
                cfg = json.load(f)
                user = cfg.get("relay_client_user", user)
                password = cfg.get("relay_client_pass", password)
                start_port = cfg.get("relay_start_port", 10001)
        except Exception:
            pass

    # 3. Try counting proxies.txt
    px_path = "/opt/proxychain-v2/proxies.txt"
    if not os.path.exists(px_path):
        px_path = "proxies.txt"
    total_nodes = 0
    if os.path.exists(px_path):
        try:
            with open(px_path, "r", encoding="utf-8") as f:
                lines = [l.strip() for l in f if l.strip() and not l.startswith("#")]
                total_nodes = len(lines)
        except Exception:
            pass

    if total_nodes == 0:
        total_nodes = 50  # Default fallback count

    ports = list(range(start_port, start_port + total_nodes))
    return ports, user, password

async def test_single_port(port: int, user: str, password: str, sem: asyncio.Semaphore) -> dict:
    async with sem:
        # 1. Try HTTP Proxy on 127.0.0.1
        http_url = f"http://{user}:{password}@127.0.0.1:{port}"
        t0 = time.time()
        try:
            async with httpx.AsyncClient(proxy=http_url, timeout=4.0) as client:
                res = await client.get(TARGET_URL)
                lat = int((time.time() - t0) * 1000)
                if res.status_code == 200:
                    exit_ip = res.text.strip()
                    print(f"{GREEN}[✓] 127.0.0.1:{port} -> ALIVE (HTTP)   | Exit IP: {exit_ip} ({lat} ms){NC}")
                    return {"port": port, "alive": True, "ip": exit_ip, "proto": "HTTP", "latency": lat}
        except Exception:
            pass

        # 2. Try SOCKS5 Proxy fallback on 127.0.0.1
        socks_url = f"socks5://{user}:{password}@127.0.0.1:{port}"
        t0 = time.time()
        try:
            async with httpx.AsyncClient(proxy=socks_url, timeout=4.0) as client:
                res = await client.get(TARGET_URL)
                lat = int((time.time() - t0) * 1000)
                if res.status_code == 200:
                    exit_ip = res.text.strip()
                    print(f"{GREEN}[✓] 127.0.0.1:{port} -> ALIVE (SOCKS5) | Exit IP: {exit_ip} ({lat} ms){NC}")
                    return {"port": port, "alive": True, "ip": exit_ip, "proto": "SOCKS5", "latency": lat}
        except Exception:
            pass

        print(f"{RED}[✗] 127.0.0.1:{port} -> DEAD / TIMEOUT{NC}")
        return {"port": port, "alive": False, "ip": None, "proto": "NONE", "latency": 0}

async def main():
    user = "gemini"
    password = "gemini"
    ports: list[int] = []

    # Check CLI arguments
    if len(sys.argv) == 2:
        # Single port specified: e.g. python check_relays.py 10001
        p = int(sys.argv[1])
        ports = [p]
    elif len(sys.argv) >= 3:
        # Range specified: e.g. python check_relays.py 10001 10249 [user] [pass]
        p_start = int(sys.argv[1])
        p_end = int(sys.argv[2])
        ports = list(range(p_start, p_end + 1))
        if len(sys.argv) > 3: user = sys.argv[3]
        if len(sys.argv) > 4: password = sys.argv[4]
    else:
        # Auto-detect mode
        ports, user, password = auto_detect_ports()

    total_ports = len(ports)
    print(f"{CYAN}================================================================{NC}")
    print(f"{BOLD}{CYAN}   ⚡ PROXYCHAIN-DOCKERV2 — LOCALHOST RELAY CHECKER (127.0.0.1) ${NC}")
    print(f"{CYAN}================================================================{NC}")
    print(f"Target Host : {YELLOW}127.0.0.1{NC} (Internal Localhost Loopback)")
    print(f"Total Port  : {YELLOW}{total_ports} ports{NC} (Port {ports[0]} s/d {ports[-1]})")
    print(f"Credentials : {CYAN}{user}:{password}{NC}")
    print(f"Test Target : {TARGET_URL}")
    print(f"Concurrency : {CONCURRENCY} workers paralel")
    print(f"{CYAN}----------------------------------------------------------------{NC}")

    sem = asyncio.Semaphore(CONCURRENCY)
    tasks = [test_single_port(p, user, password, sem) for p in ports]
    results = await asyncio.gather(*tasks)

    alive = [r for r in results if r["alive"]]
    dead = [r for r in results if not r["alive"]]
    pct = (len(alive) / total_ports * 100) if total_ports > 0 else 0

    print(f"\n{CYAN}================================================================{NC}")
    print(f"{BOLD}📊 RINGKASAN HASIL TEST PROXY RELAY:{NC}")
    print(f"Total Port Diperiksa : {total_ports}")
    print(f"Port ALIVE (Aktif)   : {GREEN}{len(alive)} ({pct:.1f}%){NC}")
    print(f"Port DEAD (Mati)     : {RED}{len(dead)}{NC}")
    if alive:
        avg_lat = sum(r["latency"] for r in alive) / len(alive)
        print(f"Rata-rata Ping       : {YELLOW}{avg_lat:.0f} ms{NC}")
    print(f"{CYAN}================================================================{NC}")

if __name__ == "__main__":
    asyncio.run(main())
