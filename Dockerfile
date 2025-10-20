# FROM ubuntu:22.04

# ENV DEBIAN_FRONTEND=noninteractive

# # 1) Install dependencies
# RUN apt-get update && \
#     apt-get install -y iproute2 iptables iputils-ping ca-certificates bash curl tar sudo nano && \
#     rm -rf /var/lib/apt/lists/*

# # 2) Copy k3s binary
# COPY k3s /usr/local/bin/k3s
# RUN chmod +x /usr/local/bin/k3s

# # 3) Install liqoctl
# RUN curl -LS "https://github.com/liqotech/liqo/releases/download/v1.0.0/liqoctl-linux-amd64.tar.gz" \
#     | tar -xz && \
#     install -o root -g root -m 0755 liqoctl /usr/local/bin/liqoctl && \
#     rm -f liqoctl

# CMD ["bash", "-c", "while true; do sleep 1000; done"]

# ──────────────────────────────
# Client image for containerlab
# ──────────────────────────────


# FROM ubuntu:22.04

# ENV DEBIAN_FRONTEND=noninteractive
# WORKDIR /

# # 1 ── Base packages
# RUN apt-get update && \
#     apt-get install -y --no-install-recommends \
#         iproute2 iptables iputils-ping ca-certificates \
#         bash curl tar sudo nano && \
#     rm -rf /var/lib/apt/lists/*

# # 2 ── K3s binary
# COPY k3s /usr/local/bin/k3s
# RUN chmod +x /usr/local/bin/k3s

# # 3 ── liqoctl
# RUN curl -Lsf https://github.com/liqotech/liqo/releases/download/v1.0.0/liqoctl-linux-amd64.tar.gz \
#     | tar -xz -C /usr/local/bin && \
#     chmod +x /usr/local/bin/liqoctl

# # 4 ── Runtime assets
# COPY scripts/client-init.sh /client-init.sh
# COPY ip-mapping.txt  /ip-mapping.txt
# COPY liqo-v1.0.0.tgz /liqo-chart.tgz
# RUN chmod +x /client-init.sh

# # 5 ── Run the init script as PID 1
# CMD ["bash", "-c", "while true; do sleep 1000; done"]

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /

# ---- version pins (override with --build-arg) ----
ARG K3S_VERSION=v1.30.4+k3s1
ARG KWOK_VERSION=v0.5.1
ARG LIQO_VERSION=v1.0.0
ARG TARGETARCH

# 1) Base packages
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl tar bash sudo nano iproute2 iptables iputils-ping \
  && rm -rf /var/lib/apt/lists/*

# 2) k3s binary (arch-aware)
#    k3s release assets: "k3s" for amd64, "k3s-arm64" for arm64
RUN set -eux; \
  ARCH="${TARGETARCH:-amd64}"; \
  K3S_ASSET="k3s"; \
  if [ "$ARCH" = "arm64" ]; then K3S_ASSET="k3s-arm64"; fi; \
  curl -L --fail \
    "https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/${K3S_ASSET}" \
    -o /usr/local/bin/k3s; \
  chmod +x /usr/local/bin/k3s

# 2.1) kubectl shim via k3s
RUN printf '%s\n' '#!/usr/bin/env bash' 'exec /usr/local/bin/k3s kubectl "$@"' \
   > /usr/local/bin/kubectl && chmod +x /usr/local/bin/kubectl

# 3) liqoctl (arch-aware)
RUN set -eux; ARCH="${TARGETARCH:-amd64}"; \
  curl -Lsf "https://github.com/liqotech/liqo/releases/download/${LIQO_VERSION}/liqoctl-linux-${ARCH}.tar.gz" \
  | tar -xz -C /usr/local/bin && chmod +x /usr/local/bin/liqoctl

# 4) KWOK + kwokctl (arch-aware)
RUN set -eux; ARCH="${TARGETARCH:-amd64}"; base="https://github.com/kubernetes-sigs/kwok/releases/download/${KWOK_VERSION}"; \
  curl -Lfso /usr/local/bin/kwokctl "${base}/kwokctl-linux-${ARCH}"; \
  curl -Lfso /usr/local/bin/kwok     "${base}/kwok-linux-${ARCH}"; \
  chmod +x /usr/local/bin/kwok /usr/local/bin/kwokctl

# 5) Idle PID 1 (your topology mounts and runs /client-init.sh)
CMD ["bash", "-c", "while true; do sleep 1000; done"]
