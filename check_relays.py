#!/usr/bin/env python3
"""
Ultra-fast Async Multi-Port Proxy Relay Checker for ProxyChain-DockerV2
Checks ports 10001..10249 in parallel using asyncio + httpx.
"""
import sys
import time
import asyncio
import httpx

START_PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 10001
END_PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 10249
USER = sys.argv[3] if len(sys.argv) > 3 else "gemini"
PASS = sys.argv[4] if len(sys.argv) > 4 else "gemini"
CONCURRENCY = 40
TARGET_URL = "http://api.ipify.org"

# ANSI Colors
GREEN = "\033[0;32m"
RED = "\033[0;31m"
YELLOW = "\033[1;33m"
CYAN = "\033[0;36m"
BOLD = "\033[1m"
NC = "\033[0m"

async def test_port(port: int, sem: asyncio.Semaphore) -> dict:
    async with sem:
        proxy_url = f"http://{USER}:{PASS}@127.0.0.1:{port}"
        t0 = time.time()
        try:
            async with httpx.AsyncClient(proxy=proxy_url, timeout=4.0) as client:
                res = await client.get(TARGET_URL)
                lat = int((time.time() - t0) * 1000)
                if res.status_code == 200:
                    exit_ip = res.text.strip()
                    print(f"{GREEN}[✓] Port {port}: ALIVE | Exit IP: {exit_ip} ({lat} ms){NC}")
                    return {"port": port, "alive": True, "ip": exit_ip, "latency": lat}
        except Exception:
            pass

        # SOCKS5 fallback
        try:
            socks_url = f"socks5://{USER}:{PASS}@127.0.0.1:{port}"
            t0 = time.time()
            async with httpx.AsyncClient(proxy=socks_url, timeout=4.0) as client:
                res = await client.get(TARGET_URL)
                lat = int((time.time() - t0) * 1000)
                if res.status_code == 200:
                    exit_ip = res.text.strip()
                    print(f"{GREEN}[✓] Port {port}: ALIVE (SOCKS5) | Exit IP: {exit_ip} ({lat} ms){NC}")
                    return {"port": port, "alive": True, "ip": exit_ip, "latency": lat}
        except Exception:
            pass

        print(f"{RED}[✗] Port {port}: DEAD / TIMEOUT{NC}")
        return {"port": port, "alive": False, "ip": None, "latency": 0}

async def main():
    print(f"{CYAN}================================================================{NC}")
    print(f"{BOLD}{CYAN}   ⚡ PROXYCHAIN-DOCKERV2 — ULTRA-FAST RELAY CHECKER           {NC}")
    print(f"{CYAN}================================================================{NC}")
    print(f"Port Range  : {YELLOW}{START_PORT}{NC} s/d {YELLOW}{END_PORT}{NC} (Total: {END_PORT - START_PORT + 1} ports)")
    print(f"Credentials : {CYAN}{USER}:{PASS}{NC}")
    print(f"Target URL  : {TARGET_URL}")
    print(f"Concurrency : {CONCURRENCY} workers")
    print(f"{CYAN}----------------------------------------------------------------{NC}")

    sem = asyncio.Semaphore(CONCURRENCY)
    tasks = [test_port(p, sem) for p in range(START_PORT, END_PORT + 1)]
    results = await asyncio.gather(*tasks)

    alive = [r for r in results if r["alive"]]
    dead = [r for r in results if not r["alive"]]
    total = len(results)
    pct = (len(alive) / total * 100) if total > 0 else 0

    print(f"\n{CYAN}================================================================{NC}")
    print(f"{BOLD}📊 RINGKASAN HASIL TEST:{NC}")
    print(f"Total Port Diperiksa : {total}")
    print(f"Port ALIVE (Aktif)   : {GREEN}{len(alive)} ({pct:.1f}%){NC}")
    print(f"Port DEAD (Mati)     : {RED}{len(dead)}{NC}")
    if alive:
        avg_lat = sum(r["latency"] for r in alive) / len(alive)
        print(f"Rata-rata Latensi    : {YELLOW}{avg_lat:.0f} ms{NC}")
    print(f"{CYAN}================================================================{NC}")

if __name__ == "__main__":
    asyncio.run(main())
