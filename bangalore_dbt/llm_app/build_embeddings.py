"""
Generate Gemini embeddings for the Bengaluru Mobility knowledge base.

Features:
- Free-tier-aware rate limiting
- Batch processing
- Checkpoint saving
- Automatic resume
- Cosine-similarity normalisation
"""

import json
import os
import sys
import time
from pathlib import Path
from typing import Any

import numpy as np
from dotenv import load_dotenv
from google import genai
from google.genai import types


BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
ENV_FILE = BASE_DIR / ".env"

KNOWLEDGE_BASE_FILE = DATA_DIR / "knowledge_base.json"
EMBEDDINGS_FILE = DATA_DIR / "embeddings.npy"
CHECKPOINT_FILE = DATA_DIR / "embeddings_checkpoint.npy"
MANIFEST_FILE = DATA_DIR / "embedding_manifest.json"

BATCH_SIZE = 20
OUTPUT_DIMENSION = 768
MAX_RETRIES = 5

# Free tier currently reports a 100-input-per-minute limit.
# Use only 80 to leave a safety margin.
SAFE_DOCUMENTS_PER_WINDOW = 80
RATE_WINDOW_SECONDS = 65


def require_environment_variable(name: str) -> str:
    """Return a required environment variable."""

    value = os.getenv(name, "").strip()

    if not value:
        raise ValueError(
            f"Required environment variable {name} is missing."
        )

    return value


def load_knowledge_base() -> dict[str, Any]:
    """Load the exported Snowflake knowledge base."""

    if not KNOWLEDGE_BASE_FILE.exists():
        raise FileNotFoundError(
            "knowledge_base.json was not found. "
            "Run build_knowledge_base.py first."
        )

    with KNOWLEDGE_BASE_FILE.open(
        "r",
        encoding="utf-8",
    ) as input_file:
        knowledge_base = json.load(input_file)

    documents = knowledge_base.get("documents", [])

    if not documents:
        raise ValueError(
            "The knowledge base contains no documents."
        )

    return knowledge_base


def load_checkpoint(
    total_documents: int,
) -> np.ndarray:
    """Load previously generated vectors if available."""

    if not CHECKPOINT_FILE.exists():
        return np.empty(
            (0, OUTPUT_DIMENSION),
            dtype=np.float32,
        )

    checkpoint = np.load(CHECKPOINT_FILE)

    if checkpoint.ndim != 2:
        raise ValueError(
            "The embedding checkpoint has an invalid shape."
        )

    if checkpoint.shape[1] != OUTPUT_DIMENSION:
        raise ValueError(
            "Checkpoint dimension does not match "
            f"{OUTPUT_DIMENSION}."
        )

    if checkpoint.shape[0] > total_documents:
        raise ValueError(
            "Checkpoint contains more vectors than documents."
        )

    print(
        f"Checkpoint found: "
        f"{checkpoint.shape[0]} documents already embedded."
    )

    return checkpoint.astype(
        np.float32,
        copy=False,
    )


def save_checkpoint(
    vectors: list[list[float]],
) -> None:
    """Save current raw vectors after every successful batch."""

    checkpoint = np.asarray(
        vectors,
        dtype=np.float32,
    )

    np.save(
        CHECKPOINT_FILE,
        checkpoint,
    )


def create_embedding_batch(
    client: genai.Client,
    model_name: str,
    texts: list[str],
) -> list[list[float]]:
    """Generate a batch of embeddings with quota-aware retries."""

    for attempt in range(1, MAX_RETRIES + 1):
        try:
            response = client.models.embed_content(
                model=model_name,
                contents=texts,
                config=types.EmbedContentConfig(
                    task_type="RETRIEVAL_DOCUMENT",
                    output_dimensionality=OUTPUT_DIMENSION,
                ),
            )

            vectors = [
                embedding.values
                for embedding in response.embeddings
            ]

            if len(vectors) != len(texts):
                raise RuntimeError(
                    "Gemini returned an unexpected number "
                    "of embeddings."
                )

            return vectors

        except Exception as exc:
            error_message = str(exc)

            if attempt == MAX_RETRIES:
                raise

            if (
                "429" in error_message
                or "RESOURCE_EXHAUSTED" in error_message
            ):
                wait_seconds = RATE_WINDOW_SECONDS
                print(
                    "\nGemini free-tier quota reached."
                )
            else:
                wait_seconds = min(
                    2 ** attempt,
                    30,
                )

            print(
                f"Request failed on attempt "
                f"{attempt} of {MAX_RETRIES}."
            )
            print(
                f"Waiting {wait_seconds} seconds "
                f"before retrying..."
            )

            time.sleep(wait_seconds)

    raise RuntimeError(
        "Embedding generation failed unexpectedly."
    )


def normalise_embeddings(
    embedding_matrix: np.ndarray,
) -> np.ndarray:
    """Normalise vectors for cosine similarity retrieval."""

    vector_norms = np.linalg.norm(
        embedding_matrix,
        axis=1,
        keepdims=True,
    )

    vector_norms = np.clip(
        vector_norms,
        a_min=1e-12,
        a_max=None,
    )

    return embedding_matrix / vector_norms


def wait_for_next_rate_window(
    window_start: float,
) -> float:
    """Wait until the next safe embedding quota window."""

    elapsed_seconds = time.monotonic() - window_start

    remaining_seconds = max(
        RATE_WINDOW_SECONDS - elapsed_seconds,
        0,
    )

    if remaining_seconds > 0:
        print(
            "\nFree-tier safety limit reached."
        )
        print(
            f"Waiting {remaining_seconds:.0f} seconds "
            f"before continuing..."
        )

        time.sleep(remaining_seconds)

    return time.monotonic()


def main() -> None:
    """Generate and save all document embeddings."""

    load_dotenv(ENV_FILE)

    api_key = require_environment_variable(
        "GEMINI_API_KEY"
    )

    model_name = require_environment_variable(
        "GEMINI_EMBEDDING_MODEL"
    ).removeprefix("models/")

    knowledge_base = load_knowledge_base()
    documents = knowledge_base["documents"]
    total_documents = len(documents)

    existing_checkpoint = load_checkpoint(
        total_documents=total_documents
    )

    all_vectors = existing_checkpoint.tolist()
    start_index = existing_checkpoint.shape[0]

    if start_index == total_documents:
        print(
            "All documents are already present "
            "in the checkpoint."
        )

    client = genai.Client(api_key=api_key)

    print("=" * 70)
    print("BUILDING BENGALURU MOBILITY EMBEDDING INDEX")
    print("=" * 70)
    print(f"Embedding model: {model_name}")
    print(f"Documents: {total_documents}")
    print(f"Starting document: {start_index + 1}")
    print(f"Output dimension: {OUTPUT_DIMENSION}")
    print(f"Batch size: {BATCH_SIZE}")
    print(
        "Safe free-tier window: "
        f"{SAFE_DOCUMENTS_PER_WINDOW} documents"
    )
    print()

    documents_in_current_window = 0
    window_start = time.monotonic()

    try:
        for batch_start in range(
            start_index,
            total_documents,
            BATCH_SIZE,
        ):
            batch_end = min(
                batch_start + BATCH_SIZE,
                total_documents,
            )

            batch_size = batch_end - batch_start

            if (
                documents_in_current_window + batch_size
                > SAFE_DOCUMENTS_PER_WINDOW
            ):
                window_start = wait_for_next_rate_window(
                    window_start
                )
                documents_in_current_window = 0

            batch_documents = documents[
                batch_start:batch_end
            ]

            batch_texts = [
                document["content"]
                for document in batch_documents
            ]

            batch_vectors = create_embedding_batch(
                client=client,
                model_name=model_name,
                texts=batch_texts,
            )

            all_vectors.extend(batch_vectors)

            save_checkpoint(
                vectors=all_vectors
            )

            documents_in_current_window += batch_size

            print(
                f"Embedded documents "
                f"{batch_start + 1:>3}–{batch_end:>3} "
                f"of {total_documents}"
            )

        embedding_matrix = np.asarray(
            all_vectors,
            dtype=np.float32,
        )

        if embedding_matrix.shape != (
            total_documents,
            OUTPUT_DIMENSION,
        ):
            raise RuntimeError(
                "Unexpected final embedding matrix shape: "
                f"{embedding_matrix.shape}"
            )

        normalised_matrix = normalise_embeddings(
            embedding_matrix
        )

        np.save(
            EMBEDDINGS_FILE,
            normalised_matrix,
        )

        manifest = {
            "project": (
                "Bengaluru Urban Mobility Intelligence"
            ),
            "embedding_model": model_name,
            "document_count": total_documents,
            "embedding_dimension": (
                OUTPUT_DIMENSION
            ),
            "embeddings_file": EMBEDDINGS_FILE.name,
            "knowledge_base_file": (
                KNOWLEDGE_BASE_FILE.name
            ),
            "normalised_for_cosine_similarity": True,
        }

        with MANIFEST_FILE.open(
            "w",
            encoding="utf-8",
        ) as output_file:
            json.dump(
                manifest,
                output_file,
                indent=2,
            )

        CHECKPOINT_FILE.unlink(
            missing_ok=True
        )

        print("\n" + "=" * 70)
        print("EMBEDDING INDEX CREATED SUCCESSFULLY")
        print(
            f"Matrix shape: "
            f"{normalised_matrix.shape}"
        )
        print(
            f"Saved vectors: {EMBEDDINGS_FILE}"
        )
        print(
            f"Saved manifest: {MANIFEST_FILE}"
        )
        print("=" * 70)

    except KeyboardInterrupt:
        print(
            "\nProcess interrupted. "
            "The checkpoint has been preserved."
        )
        sys.exit(1)

    except Exception as exc:
        print(
            "\nEmbedding generation stopped."
        )
        print(
            "Completed vectors remain saved "
            "in the checkpoint."
        )
        print(
            f"Error type: {type(exc).__name__}"
        )
        print(
            f"Error details: {exc}"
        )
        sys.exit(1)


if __name__ == "__main__":
    main()