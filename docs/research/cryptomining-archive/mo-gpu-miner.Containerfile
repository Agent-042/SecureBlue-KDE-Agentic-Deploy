# Multi-miner / Rigel rootless NVIDIA GPU miner for MoneroOcean profit switching
FROM docker.io/nvidia/cuda:12.5.1-base-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive

# Core dependencies plus the OpenCL loader that Rigel may use for device enumeration
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    tar \
    ocl-icd-libopencl1 \
    && rm -rf /var/lib/apt/lists/*

# NVIDIA OpenCL ICD (runtime image normally provides libnvidia-opencl.so.1, but
# the ICD loader file is not always present). If the file already exists it is
# left untouched.
RUN mkdir -p /etc/OpenCL/vendors && \
    if [ ! -f /etc/OpenCL/vendors/nvidia.icd ]; then \
        echo "libnvidia-opencl.so.1" > /etc/OpenCL/vendors/nvidia.icd; \
    fi

# Multi-miner v5.0
RUN mkdir -p /miner && \
    curl -L -o /tmp/mm-v5.0-lin.tar.gz \
        https://github.com/MoneroOcean/multi-miner/releases/download/v5.0/mm-v5.0-lin.tar.gz && \
    tar xzf /tmp/mm-v5.0-lin.tar.gz -C /tmp && \
    cp /tmp/mm /miner/mm && \
    chmod +x /miner/mm && \
    rm -f /tmp/mm-v5.0-lin.tar.gz /tmp/mm

# Rigel 1.23.2
RUN curl -L -o /tmp/rigel-1.23.2-linux.tar.gz \
        https://github.com/rigelminer/rigel/releases/download/1.23.2/rigel-1.23.2-linux.tar.gz && \
    tar xzf /tmp/rigel-1.23.2-linux.tar.gz -C /miner && \
    rm -f /tmp/rigel-1.23.2-linux.tar.gz && \
    ln -sf /miner/rigel-1.23.2-linux/rigel /miner/rigel && \
    chmod +x /miner/rigel-1.23.2-linux/rigel

WORKDIR /miner

ENTRYPOINT ["/miner/mm"]
CMD ["/miner/mm.json"]
