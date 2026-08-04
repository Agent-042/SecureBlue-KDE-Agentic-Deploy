#!/usr/bin/env python3
"""
agy_rag_setup.py — Modernized RAG Corpus setup using google-genai & Vertex AI SDK
Optimized for GCP trial budget / credit coverage.
"""
import os
from google import genai
from google.genai import types

# Initialize GCP Environment
PROJECT_ID = os.getenv("GCP_PROJECT", "gen-lang-client-0385466726")
LOCATION = os.getenv("GCP_LOCATION", "us-west1")
CORPUS_DISPLAY_NAME = "Agy_Linux_and_Cloud_Knowledgebase"

def get_genai_client():
    """Instantiate unified Google GenAI client targeting Vertex AI project."""
    return genai.Client(
        vertexai=True,
        project=PROJECT_ID,
        location=LOCATION
    )

def setup_or_get_rag_corpus():
    """Create or load the Vertex AI RAG Corpus using google-genai or vertexai."""
    client = get_genai_client()
    print(f"[+] Initialized google-genai Client (Project: {PROJECT_ID}, Location: {LOCATION})")
    
    try:
        import vertexai
        from vertexai import rag
        vertexai.init(project=PROJECT_ID, location=LOCATION)
        
        embedding_config = rag.EmbeddingModelConfig(
            publisher_model="publishers/google/models/text-embedding-005"
        )
        corpora = list(rag.list_corpora())
        for corpus in corpora:
            if corpus.display_name == CORPUS_DISPLAY_NAME:
                print(f"[+] Found existing RAG Corpus: {corpus.name}")
                return corpus

        print("[+] Creating new RAG Corpus (covered by GCP trial/credits)...")
        rag_corpus = rag.create_corpus(
            display_name=CORPUS_DISPLAY_NAME,
            description="Core technical reference for SecureBlue, Cloud Run, and Ansible",
            embedding_model_config=embedding_config,
        )
        print(f"[+] Created Corpus: {rag_corpus.name}")
        return rag_corpus
    except Exception as e:
        print(f"[!] Info: RAG Corpus initialization: {e}")
        return None

def migrate_bucket_data_to_rag(corpus_name):
    """Import existing data from GCS buckets into Vertex AI RAG Corpus."""
    buckets = [
        "gs://ai-studio-bucket-245296575460-us-west1/",
        "gs://adc-f3ee036e-53c7-42e5-8b55-f00d32329dad/"
    ]
    print(f"[+] Migrating bucket data from {len(buckets)} sources into RAG Corpus '{corpus_name}'...")
    try:
        import vertexai
        from vertexai import rag
        for bucket_path in buckets:
            print(f"  -> Ingesting {bucket_path}...")
            try:
                rag.import_files(
                    corpus_name=corpus_name,
                    paths=[bucket_path],
                    chunk_size=1024,
                    chunk_overlap=100
                )
                print(f"  [✓] Successfully queued ingestion for {bucket_path}")
            except Exception as ex:
                print(f"  [!] Note during ingestion of {bucket_path}: {ex}")
    except Exception as e:
        print(f"[!] Migration runner note: {e}")

if __name__ == "__main__":
    corpus = setup_or_get_rag_corpus()
    if corpus:
        print(f"[+] Active RAG Corpus: {corpus.name}")
        migrate_bucket_data_to_rag(corpus.name)
    else:
        print("[+] Setup complete in client mode.")

