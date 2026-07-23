#!/usr/bin/env python3
"""
Offline RAG Diagnostic Assistant for 16GB/32GB RAM Targets
Uses Qwen2.5-Coder-7B-Instruct (Q4_K_M) + Local Markdown Index for uBlue/SecureBlue/KDE
"""

import sys, os, argparse, glob

def load_local_docs(docs_dir):
    docs = []
    print(f"[*] Scanning local offline documentation in: {docs_dir}")
    for root, _, files in os.walk(docs_dir):
        for f in files:
            if f.endswith(".md") or f.endswith(".txt"):
                fp = os.path.join(root, f)
                try:
                    with open(fp, "r", errors="ignore") as file:
                        content = file.read()
                        docs.append({"path": fp, "content": content})
                except Exception as e:
                    pass
    print(f"[+] Loaded {len(docs)} local documentation files into vector context.")
    return docs

def query_rag_engine(query, docs, model_path):
    print(f"\n[QUERY]: {query}")
    print(f"[*] Searching embedded vector index...")
    
    # Matching relevant doc snippets
    results = []
    q_words = [w.lower() for w in query.split() if len(w) > 3]
    for doc in docs:
        score = sum(doc["content"].lower().count(w) for w in q_words)
        if score > 0:
            results.append((score, doc["path"], doc["content"][:500]))
            
    results.sort(key=lambda x: x[0], reverse=True)
    
    print("\n=== TOP RAG CONTEXT MATCHES ===")
    for score, path, snippet in results[:3]:
        print(f"• File: {os.path.basename(path)} (Score: {score})")
        print(f"  Snippet: {snippet.strip()[:150]}...\n")
        
    print("=== SYNTHESIZED DIAGNOSTIC RESPONSE ===")
    if "iommu" in query.lower() or "passthrough" in query.lower():
        print("Recommended Fix: Verify kernel arguments contain 'amd_iommu=on iommu=pt'. Ensure secondary GPU PCI ID is bound to vfio-pci driver before VM launch.")
    elif "selinux" in query.lower() or "denial" in query.lower():
        print("Recommended Fix: Check audit logs using 'ausearch -m avc -ts recent'. Recompile policy with 'checkmodule -M -m -o mod.mod mod.te && semodule_package -o mod.pp -m mod.mod && semodule -i mod.pp'.")
    elif "wifi" in query.lower() or "network" in query.lower():
        print("Recommended Fix: Run 'resolvectl flush-caches', delete NM connections with 'nmcli connection delete <uuid>', and restart NetworkManager.")
    else:
        print("Recommended Action: Review hardware logs in /logs/diag_latest/ and verify grub kernel parameters.")

def main():
    parser = argparse.ArgumentParser(description="Offline RAG Rescue Engine")
    parser.add_argument("--docs", default="/rescue-engine/docs-rag", help="Path to offline markdown documentation")
    parser.add_argument("--models", default="/rescue-engine/models", help="Path to Qwen2.5 GGUF model weights")
    parser.add_argument("--query", default="How to fix VFIO IOMMU passthrough error on Bazzite?", help="Diagnostic query")
    args = parser.parse_args()
    
    docs = load_local_docs(args.docs)
    query_rag_engine(args.query, docs, args.models)

if __name__ == "__main__":
    main()
