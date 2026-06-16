FROM debian:13

ENV PORT=7681
ENV DEBIAN_FRONTEND=noninteractive

# Combine update, install, and cleanup to minimize layers
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    wget \
    curl \
    git \
    python3 \
    python3-pip \
    tini \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Dynamically detect architecture for ttyd
RUN set -eux; \
    arch="$(uname -m)"; \
    case "$arch" in \
      x86_64) ttyd_asset="ttyd.x86_64" ;; \
      aarch64) ttyd_asset="ttyd.aarch64" ;; \
      *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
    esac; \
    wget -qO /usr/local/bin/ttyd "https://github.com/tsl0922/ttyd/releases/latest/download/${ttyd_asset}" \
    && chmod +x /usr/local/bin/ttyd

# Create a clean entrypoint script to handle environment variables and conditional authentication properly
RUN cat << 'EOF' > /usr/local/bin/entrypoint.sh
#!/bin/bash
cd /root

if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
    exec /usr/local/bin/ttyd --writable -i 0.0.0.0 -p "$PORT" -c "$USERNAME:$PASSWORD" /bin/bash
else
    exec /usr/local/bin/ttyd --writable -i 0.0.0.0 -p "$PORT" /bin/bash
fi
EOF

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 7681

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/local/bin/entrypoint.sh"]
