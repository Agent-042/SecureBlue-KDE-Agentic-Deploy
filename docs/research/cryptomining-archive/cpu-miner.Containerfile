FROM docker.io/library/ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl libuv1 libhwloc15 libssl3 \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /etc/xmrig

ARG XMRIG_VERSION=6.26.0
RUN curl -fsSL -o "xmrig-${XMRIG_VERSION}-linux-static-x64.tar.gz" \
    "https://github.com/xmrig/xmrig/releases/download/v${XMRIG_VERSION}/xmrig-${XMRIG_VERSION}-linux-static-x64.tar.gz" \
 && tar -xzf "xmrig-${XMRIG_VERSION}-linux-static-x64.tar.gz" \
 && mv "xmrig-${XMRIG_VERSION}/xmrig" /etc/xmrig/xmrig \
 && rm -rf "xmrig-${XMRIG_VERSION}" "xmrig-${XMRIG_VERSION}-linux-static-x64.tar.gz" \
 && chmod +x /etc/xmrig/xmrig

ENTRYPOINT ["/etc/xmrig/xmrig"]
CMD ["-c", "/etc/xmrig/config.json"]
