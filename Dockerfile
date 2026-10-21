# ==============================================================================
# PROXYCHAIN-DOCKERV2 — HYBRID PASSIVE INCOME HARVESTER & PROXY RELAY
# TraffMonetizer + Surfshark WireGuard (925 Nodes) + Multi-Port Proxy Relay
# ==============================================================================
FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    DEBIAN_FRONTEND=noninteractive

WORKDIR /app

# Install runtime utilities & proxy tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    procps \
    ca-certificates \
    proxychains4 \
    wireguard-tools \
    tar \
    screen \
    lsof \
    && rm -rf /var/lib/apt/lists/*

# Install TraffMonetizer CLI v2 via crane
RUN curl -sL https://github.com/google/go-containerregistry/releases/latest/download/go-containerregistry_Linux_x86_64.tar.gz | tar -xz -C /usr/local/bin crane && \
    chmod +x /usr/local/bin/crane && \
    crane export traffmonetizer/cli_v2:latest - | tar -x -C / usr/local/bin/cli && \
    chmod +x /usr/local/bin/cli && \
    ln -sf /usr/local/bin/cli /usr/local/bin/traffmonetizer && \
    rm -f /usr/local/bin/crane

# Install WireProxy (Userspace WireGuard to SOCKS5)
RUN curl -sL "https://github.com/windtf/wireproxy/releases/download/v1.1.3/wireproxy_linux_amd64.tar.gz" | tar -xz -C /usr/local/bin wireproxy && \
    chmod +x /usr/local/bin/wireproxy

# Install Python requirements
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install -r requirements.txt

# Copy project files
COPY . .

# Expose Web Dashboard Port (8080) and Default Relay Port Range (10001-10050)
EXPOSE 8080
EXPOSE 10001-10050

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://127.0.0.1:8080/api/status || exit 1

CMD ["python3", "app.py"]
