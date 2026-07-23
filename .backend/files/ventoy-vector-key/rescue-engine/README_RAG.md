# Offline AI & RAG Engine Stack (16GB / 32GB RAM Target)

> **PURPOSE**: Zero-internet, offline diagnostic assistant executing `Qwen2.5-Coder-7B-Instruct` (Q4_K_M) or `Qwen2.5-14B-Instruct` with embedded markdown vector store for uBlue, SecureBlue, KDE, and VFIO troubleshooting.

---

## 1. Local LLM Architecture & Quantization

```
Model               : Qwen2.5-Coder-7B-Instruct
Quantization        : Q4_K_M (4-bit Medium Quantization)
Memory Footprint    : ~4.5 GB RAM / VRAM
Context Window      : 32,768 tokens
Embedding Model     : bge-small-en-v1.5 (~130 MB)
Vector Store        : Static LanceDB / ChromaDB directory on USB
```

---

## 2. Directory Structure on USB Partition 1

```
/rescue-engine/
├── models/
│   ├── qwen2.5-coder-7b-instruct-q4_k_m.gguf
│   └── bge-small-en-v1.5.gguf
├── docs-rag/
│   ├── ublue-docs/         # Clone of ublue-os/docs
│   ├── secureblue-docs/    # SecureBlue hardening guides
│   ├── kde-plasma6-docs/   # KDE Plasma 6 Wayland troubleshooting
│   └── vfio-bazzite-docs/  # VFIO GPU passthrough & libvirt guides
└── bin/
    ├── harvester.sh        # Hardware diagnostic & log extractor
    └── rag_assistant.py    # Offline CLI RAG search & reasoning interface
```

---

## 3. Running the Offline RAG Assistant

To launch the assistant from a live rescue terminal:

```bash
# Launch offline RAG diagnostic query
python3 /rescue-engine/bin/rag_assistant.py \
    --docs /rescue-engine/docs-rag \
    --models /rescue-engine/models \
    --query "IOMMU group error when launching Bazzite VM"
```
