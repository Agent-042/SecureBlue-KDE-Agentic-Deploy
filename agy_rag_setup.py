#!/usr/bin/env python3
import os
import vertexai
from vertexai.preview import rag
from vertexai.preview.generative_models import GenerativeModel, Tool

# Initialize GCP Environment
PROJECT_ID = os.getenv("GCP_PROJECT", "gen-lang-client-0385466726")
LOCATION = os.getenv("GCP_LOCATION", "us-west1")
CORPUS_DISPLAY_NAME = "Agy_Linux_and_Cloud_Knowledgebase"

vertexai.init(project=PROJECT_ID, location=LOCATION)

def setup_or_get_rag_corpus():
    """Create or load the Vertex AI RAG Corpus."""
    embedding_config = rag.EmbeddingModelConfig(
        publisher_model="publishers/google/models/text-embedding-005"
    )
    
    # Check if corpus exists, otherwise create it
    try:
        corpora = list(rag.list_corpora())
        for corpus in corpora:
            if corpus.display_name == CORPUS_DISPLAY_NAME:
                print(f"[+] Found existing RAG Corpus: {corpus.name}")
                return corpus
    except Exception as e:
        print(f"[!] Warning listing corpora: {e}")

    print("[+] Creating new RAG Corpus...")
    rag_corpus = rag.create_corpus(
        display_name=CORPUS_DISPLAY_NAME,
        description="Core technical reference for SecureBlue, Cloud Run, and Ansible",
        embedding_model_config=embedding_config,
    )
    print(f"[+] Created Corpus: {rag_corpus.name}")
    return rag_corpus

def ingest_documents(corpus_name, gcs_uris):
    """Import documents into the RAG Corpus from GCS buckets."""
    print(f"[+] Ingesting files into {corpus_name}...")
    rag.import_files(
        corpus_name=corpus_name,
        paths=gcs_uris,
        chunk_size=1024,
        chunk_overlap=100,
        max_embedding_requests_per_min=900,
    )
    print("[+] Document ingestion completed.")

def get_rag_enabled_gemini_model(corpus_name):
    """Instantiate Gemini 2.0 / 1.5 with attached Vertex AI RAG Tool."""
    rag_retrieval_tool = Tool.from_retrieval(
        retrieval=rag.Retrieval(
            source=rag.VertexRagStore(
                rag_resources=[rag.RagResource(rag_corpus=corpus_name)],
                similarity_top_k=5,
                vector_distance_threshold=0.5,
            )
        )
    )
    
    model = GenerativeModel(
        model_name="gemini-2.0-flash-001",
        tools=[rag_retrieval_tool]
    )
    return model

if __name__ == "__main__":
    corpus = setup_or_get_rag_corpus()
    print(f"[+] Active Corpus: {corpus.name}")
