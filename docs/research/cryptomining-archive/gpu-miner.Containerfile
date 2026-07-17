FROM docker.io/nvidia/cuda:12.5.1-base-ubuntu24.04

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        ocl-icd-libopencl1 \
        tar \
        wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /miner

RUN wget -q \
    https://github.com/andru-kun/wildrig-multi/releases/download/0.49.3/wildrig-multi-linux-0.49.3.tar.gz \
    -O /tmp/wildrig-multi-linux-0.49.3.tar.gz \
    && tar -xzf /tmp/wildrig-multi-linux-0.49.3.tar.gz -C /miner \
    && rm /tmp/wildrig-multi-linux-0.49.3.tar.gz \
    && chmod +x /miner/wildrig-multi

ENTRYPOINT ["/miner/wildrig-multi"]
CMD ["--algo","kawpow","--url","stratum+tcp://gulf.moneroocean.stream:10128","--user","488PDocmyVBGda3RrbzKnt6UdzKmTQdtf5vnrYX31cCJH7vPmbCpnANLaKHKqj3QUR92Am8m4W8Q23CkRGr7BGVc1HFhycz","--pass","node42-gpu~kawpow","--worker","node42-gpu","--no-color"]
