"""
Test the Gemini API key and display the Flash and embedding models
available to the current Google AI Studio account.
"""

import os
import sys
from pathlib import Path

from dotenv import load_dotenv
from google import genai


BASE_DIR = Path(__file__).resolve().parent
ENV_FILE = BASE_DIR / ".env"


def load_api_key() -> str:
    """Load and validate the Gemini API key."""

    load_dotenv(ENV_FILE)

    api_key = os.getenv("GEMINI_API_KEY", "").strip()

    if not api_key:
        raise ValueError(
            "GEMINI_API_KEY is missing from llm_app/.env"
        )

    if api_key == "PASTE_YOUR_REAL_GEMINI_API_KEY":
        raise ValueError(
            "Replace the placeholder in .env with your real Gemini API key."
        )

    return api_key


def main() -> None:
    """Connect to Gemini and list relevant available models."""

    api_key = load_api_key()
    client = genai.Client(api_key=api_key)

    print("=" * 70)
    print("BENGALURU MOBILITY RAG — GEMINI CONNECTION TEST")
    print("=" * 70)

    try:
        all_models = list(client.models.list())

    except Exception as exc:
        print("\nGemini connection failed.")
        print(f"\nError type: {type(exc).__name__}")
        print(f"Error details: {exc}")
        sys.exit(1)

    flash_models = []
    embedding_models = []

    for model in all_models:
        model_name = str(getattr(model, "name", ""))

        if "flash" in model_name.lower():
            flash_models.append(model_name)

        if "embedding" in model_name.lower():
            embedding_models.append(model_name)

    print("\nGemini connection successful.")

    print("\nAvailable Flash models:")
    if flash_models:
        for model_name in sorted(set(flash_models)):
            print(f"  - {model_name}")
    else:
        print("  No Flash models were returned for this API key.")

    print("\nAvailable embedding models:")
    if embedding_models:
        for model_name in sorted(set(embedding_models)):
            print(f"  - {model_name}")
    else:
        print("  No embedding models were returned for this API key.")

    print("\nTotal models visible to this key:", len(all_models))
    print("=" * 70)


if __name__ == "__main__":
    main()