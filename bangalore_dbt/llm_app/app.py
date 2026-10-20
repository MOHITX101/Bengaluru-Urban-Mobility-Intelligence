"""
Bengaluru Mobility Intelligence
Apple-inspired Streamlit interface for the Bengaluru Mobility RAG system.

The live application reads the locally generated knowledge base and embedding
files. Snowflake is only required when rebuilding the knowledge base.
"""

from __future__ import annotations

import inspect
import json
import os
from datetime import datetime
from pathlib import Path
from typing import Any

import streamlit as st
from dotenv import load_dotenv

from rag_engine import BengaluruMobilityRAG


# ---------------------------------------------------------------------
# Application paths and configuration
# ---------------------------------------------------------------------

APP_DIR = Path(__file__).resolve().parent
DATA_DIR = APP_DIR / "data"
KNOWLEDGE_BASE_PATH = DATA_DIR / "knowledge_base.json"
EMBEDDINGS_PATH = DATA_DIR / "embeddings.npy"
MANIFEST_PATH = DATA_DIR / "embedding_manifest.json"

load_dotenv(APP_DIR / ".env")


def load_streamlit_secret() -> None:
    """Load Gemini API key from Streamlit Cloud secrets when available."""

    try:
        gemini_key = st.secrets.get("GEMINI_API_KEY")
    except Exception:
        gemini_key = None

    if gemini_key and not os.getenv("GEMINI_API_KEY"):
        os.environ["GEMINI_API_KEY"] = str(gemini_key)


load_streamlit_secret()

st.set_page_config(
    page_title="Bengaluru Mobility Intelligence",
    page_icon="🌆",
    layout="wide",
    initial_sidebar_state="expanded",
)


# ---------------------------------------------------------------------
# Styling
# ---------------------------------------------------------------------

st.markdown(
    """
    <style>
    :root {
        --background: #f5f5f7;
        --surface: rgba(255, 255, 255, 0.88);
        --surface-solid: #ffffff;
        --text-primary: #1d1d1f;
        --text-secondary: #6e6e73;
        --border: rgba(0, 0, 0, 0.08);
        --blue: #0071e3;
        --blue-dark: #0058b0;
        --green: #34c759;
        --shadow: 0 14px 40px rgba(0, 0, 0, 0.07);
        --small-shadow: 0 6px 20px rgba(0, 0, 0, 0.05);
        --radius-large: 28px;
        --radius-medium: 18px;
        --radius-small: 12px;
    }

    html, body, [class*="css"] {
        font-family:
            -apple-system,
            BlinkMacSystemFont,
            "SF Pro Display",
            "SF Pro Text",
            "Segoe UI",
            sans-serif;
    }

    .stApp {
        color: var(--text-primary);
        background:
            radial-gradient(
                circle at 85% 5%,
                rgba(0, 113, 227, 0.10),
                transparent 26%
            ),
            radial-gradient(
                circle at 35% 18%,
                rgba(175, 82, 222, 0.07),
                transparent 24%
            ),
            var(--background);
    }

    [data-testid="stHeader"] {
        background: rgba(245, 245, 247, 0.72);
        backdrop-filter: blur(18px);
        -webkit-backdrop-filter: blur(18px);
    }

    [data-testid="stSidebar"] {
        background: rgba(251, 251, 253, 0.94);
        border-right: 1px solid var(--border);
        backdrop-filter: blur(22px);
        -webkit-backdrop-filter: blur(22px);
    }

    [data-testid="stSidebar"] > div:first-child {
        padding-top: 2rem;
    }

    .block-container {
        max-width: 1180px;
        padding-top: 2.2rem;
        padding-bottom: 7rem;
    }

    /* Sidebar */

    .brand-mark {
        display: flex;
        align-items: center;
        justify-content: center;
        width: 52px;
        height: 52px;
        margin-bottom: 1rem;
        color: white;
        background: linear-gradient(145deg, #29292d, #050506);
        border-radius: 16px;
        box-shadow: 0 10px 24px rgba(0, 0, 0, 0.20);
        font-size: 0.92rem;
        font-weight: 750;
        letter-spacing: -0.02em;
    }

    .brand-title {
        margin: 0;
        color: var(--text-primary);
        font-size: 1.20rem;
        font-weight: 730;
        letter-spacing: -0.035em;
    }

    .brand-subtitle {
        margin-top: 0.65rem;
        color: var(--text-secondary);
        font-size: 0.88rem;
        line-height: 1.55;
    }

    .status-card {
        display: flex;
        align-items: center;
        gap: 0.65rem;
        margin-top: 1.5rem;
        padding: 0.85rem 0.95rem;
        background: rgba(255, 255, 255, 0.88);
        border: 1px solid var(--border);
        border-radius: 14px;
        box-shadow: var(--small-shadow);
        color: #247b3d;
        font-size: 0.80rem;
        font-weight: 650;
    }

    .status-dot {
        width: 9px;
        height: 9px;
        flex: 0 0 auto;
        background: var(--green);
        border-radius: 50%;
        box-shadow: 0 0 0 5px rgba(52, 199, 89, 0.13);
    }

    .sidebar-label {
        margin-top: 2rem;
        margin-bottom: 0.8rem;
        color: #3a3a3c;
        font-size: 0.82rem;
        font-weight: 700;
        letter-spacing: 0.01em;
    }

    .topic-pills {
        display: flex;
        flex-wrap: wrap;
        gap: 0.50rem;
    }

    .topic-pill {
        padding: 0.48rem 0.68rem;
        color: #515154;
        background: #ffffff;
        border: 1px solid var(--border);
        border-radius: 999px;
        font-size: 0.72rem;
        box-shadow: 0 3px 10px rgba(0, 0, 0, 0.03);
    }

    .sidebar-note {
        margin-top: 1.5rem;
        padding: 0.95rem;
        color: var(--text-secondary);
        background: rgba(255, 255, 255, 0.72);
        border: 1px solid var(--border);
        border-radius: 14px;
        font-size: 0.75rem;
        line-height: 1.5;
    }

    /* Hero */

    .hero {
        position: relative;
        overflow: hidden;
        margin-bottom: 1.5rem;
        padding: 3rem 3.1rem;
        background:
            radial-gradient(
                circle at 88% 20%,
                rgba(255, 255, 255, 0.85),
                transparent 27%
            ),
            linear-gradient(
                135deg,
                rgba(255, 255, 255, 0.96),
                rgba(231, 241, 255, 0.94)
            );
        border: 1px solid rgba(255, 255, 255, 0.9);
        border-radius: var(--radius-large);
        box-shadow: var(--shadow);
    }

    .hero::after {
        content: "";
        position: absolute;
        top: -65px;
        right: -40px;
        width: 260px;
        height: 260px;
        background:
            linear-gradient(
                145deg,
                rgba(0, 113, 227, 0.22),
                rgba(175, 82, 222, 0.12)
            );
        border-radius: 50%;
        filter: blur(4px);
    }

    .hero-eyebrow {
        position: relative;
        z-index: 1;
        margin-bottom: 0.8rem;
        color: var(--blue);
        font-size: 0.78rem;
        font-weight: 750;
        letter-spacing: 0.09em;
        text-transform: uppercase;
    }

    .hero-title {
        position: relative;
        z-index: 1;
        max-width: 700px;
        margin: 0;
        color: #111113;
        font-size: clamp(2.6rem, 6vw, 4.8rem);
        font-weight: 760;
        letter-spacing: -0.065em;
        line-height: 0.98;
    }

    .hero-description {
        position: relative;
        z-index: 1;
        max-width: 680px;
        margin-top: 1.2rem;
        margin-bottom: 0;
        color: #515154;
        font-size: 1.05rem;
        line-height: 1.58;
    }

    /* Metrics */

    [data-testid="stMetric"] {
        min-height: 105px;
        padding: 1rem 1.1rem;
        background: var(--surface);
        border: 1px solid rgba(255, 255, 255, 0.90);
        border-radius: var(--radius-medium);
        box-shadow: var(--small-shadow);
        backdrop-filter: blur(16px);
        -webkit-backdrop-filter: blur(16px);
    }

    [data-testid="stMetricLabel"] {
        color: var(--text-secondary);
        font-size: 0.76rem;
    }

    [data-testid="stMetricValue"] {
        color: var(--text-primary);
        font-size: 1.65rem;
        font-weight: 720;
        letter-spacing: -0.04em;
    }

    /* Section headings */

    .section-heading {
        margin-top: 2rem;
        margin-bottom: 0.25rem;
        color: var(--text-primary);
        font-size: 1.55rem;
        font-weight: 720;
        letter-spacing: -0.04em;
    }

    .section-description {
        margin-bottom: 1.1rem;
        color: var(--text-secondary);
        font-size: 0.91rem;
    }

    /* Buttons */

    .stButton > button {
        width: 100%;
        min-height: 52px;
        padding: 0.70rem 0.85rem;
        color: #333336;
        background: rgba(255, 255, 255, 0.88);
        border: 1px solid var(--border);
        border-radius: 14px;
        box-shadow: 0 5px 18px rgba(0, 0, 0, 0.04);
        font-size: 0.80rem;
        font-weight: 570;
        text-align: left;
        transition:
            transform 160ms ease,
            box-shadow 160ms ease,
            border-color 160ms ease;
    }

    .stButton > button:hover {
        color: var(--blue);
        background: #ffffff;
        border-color: rgba(0, 113, 227, 0.30);
        box-shadow: 0 9px 25px rgba(0, 113, 227, 0.10);
        transform: translateY(-2px);
    }

    [data-testid="stSidebar"] .stButton > button {
        min-height: 42px;
        text-align: center;
    }

    /* Chat */

    [data-testid="stChatMessage"] {
        margin-bottom: 0.85rem;
        padding: 1.05rem 1.15rem;
        background: rgba(255, 255, 255, 0.86);
        border: 1px solid rgba(255, 255, 255, 0.92);
        border-radius: 20px;
        box-shadow: var(--small-shadow);
        backdrop-filter: blur(16px);
        -webkit-backdrop-filter: blur(16px);
    }

    [data-testid="stChatMessageContent"] {
        color: var(--text-primary);
        font-size: 0.95rem;
        line-height: 1.65;
    }

    [data-testid="stChatInput"] {
        background: rgba(255, 255, 255, 0.94);
        border: 1px solid rgba(0, 0, 0, 0.09);
        border-radius: 18px;
        box-shadow: 0 12px 38px rgba(0, 0, 0, 0.10);
        backdrop-filter: blur(20px);
        -webkit-backdrop-filter: blur(20px);
    }

    [data-testid="stChatInput"] textarea {
        color: var(--text-primary);
        font-size: 0.95rem;
    }

    /* Evidence */

    .evidence-card {
        margin-top: 0.65rem;
        margin-bottom: 0.65rem;
        padding: 0.85rem 0.95rem;
        color: #4a4a4d;
        background: #f7f7f9;
        border: 1px solid var(--border);
        border-radius: 13px;
        font-size: 0.79rem;
        line-height: 1.5;
    }

    .evidence-number {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        width: 23px;
        height: 23px;
        margin-right: 0.45rem;
        color: white;
        background: #1d1d1f;
        border-radius: 7px;
        font-size: 0.69rem;
        font-weight: 700;
    }

    .footer-note {
        margin-top: 2rem;
        padding-top: 1.2rem;
        color: #8e8e93;
        border-top: 1px solid var(--border);
        font-size: 0.73rem;
        line-height: 1.55;
        text-align: center;
    }

    div[data-testid="stAlert"] {
        border-radius: 16px;
    }

    div[data-testid="stExpander"] {
        overflow: hidden;
        background: rgba(255, 255, 255, 0.78);
        border: 1px solid var(--border);
        border-radius: 14px;
    }

    @media (max-width: 768px) {
        .block-container {
            padding-top: 1rem;
        }

        .hero {
            padding: 2rem 1.5rem;
            border-radius: 22px;
        }

        .hero-title {
            font-size: 2.75rem;
        }

        .hero-description {
            font-size: 0.94rem;
        }
    }
    </style>
    """,
    unsafe_allow_html=True,
)


# ---------------------------------------------------------------------
# Knowledge-base information
# ---------------------------------------------------------------------

def extract_documents(payload: Any) -> list[dict[str, Any]]:
    """Extract documents from supported knowledge-base JSON structures."""

    if isinstance(payload, list):
        return [item for item in payload if isinstance(item, dict)]

    if isinstance(payload, dict):
        for key in ("documents", "records", "data", "knowledge_base", "items"):
            value = payload.get(key)
            if isinstance(value, list):
                return [item for item in value if isinstance(item, dict)]

    return []


def get_document_metadata(document: dict[str, Any]) -> dict[str, Any]:
    """Return metadata whether it is nested or stored on the document."""

    metadata = document.get("metadata")

    if isinstance(metadata, dict):
        return metadata

    return document


@st.cache_data(show_spinner=False)
def load_knowledge_base_information() -> dict[str, Any]:
    """Read local snapshot statistics without connecting to Snowflake."""

    information = {
        "documents": 0,
        "sources": 0,
        "last_updated": "Unavailable",
        "ready": False,
    }

    if not KNOWLEDGE_BASE_PATH.exists():
        return information

    try:
        with KNOWLEDGE_BASE_PATH.open(
            "r",
            encoding="utf-8",
        ) as file:
            payload = json.load(file)

        documents = extract_documents(payload)
        source_models: set[str] = set()

        for document in documents:
            metadata = get_document_metadata(document)

            source_model = (
                metadata.get("source_model")
                or metadata.get("source")
                or metadata.get("table_name")
                or metadata.get("model")
                or document.get("source_model")
                or document.get("source")
            )

            if source_model:
                source_models.add(str(source_model))

        modified_time = datetime.fromtimestamp(
            KNOWLEDGE_BASE_PATH.stat().st_mtime
        )

        information.update(
            {
                "documents": len(documents),
                "sources": len(source_models),
                "last_updated": modified_time.strftime("%d %b %Y"),
                "ready": (
                    KNOWLEDGE_BASE_PATH.exists()
                    and EMBEDDINGS_PATH.exists()
                    and MANIFEST_PATH.exists()
                ),
            }
        )

    except (OSError, json.JSONDecodeError):
        pass

    return information


knowledge_information = load_knowledge_base_information()


# ---------------------------------------------------------------------
# RAG loading and response handling
# ---------------------------------------------------------------------

@st.cache_resource(show_spinner=False)
def load_rag_engine() -> BengaluruMobilityRAG:
    """Initialize the RAG engine once per Streamlit session."""

    return BengaluruMobilityRAG()


def call_rag_method(
    rag_engine: BengaluruMobilityRAG,
    question: str,
) -> Any:
    """
    Call the available public question-answering method.

    This allows the interface to work with common method names without
    requiring changes to rag_engine.py.
    """

    possible_methods = (
        "answer_question",
        "ask",
        "query",
        "answer",
        "answer_query",
        "generate_answer",
        "run",
    )

    for method_name in possible_methods:
        method = getattr(rag_engine, method_name, None)

        if not callable(method):
            continue

        try:
            signature = inspect.signature(method)
            parameters = signature.parameters
            keyword_arguments: dict[str, Any] = {}

            if "top_k" in parameters:
                keyword_arguments["top_k"] = 6
            elif "k" in parameters:
                keyword_arguments["k"] = 6

            return method(question, **keyword_arguments)

        except (ValueError, TypeError):
            # Some wrapped methods do not expose a reliable signature.
            try:
                return method(question)
            except TypeError:
                continue

    raise AttributeError(
        "No supported question-answering method was found in "
        "BengaluruMobilityRAG."
    )


def normalize_sources(raw_sources: Any) -> list[Any]:
    """Convert returned source data into a predictable list."""

    if raw_sources is None:
        return []

    if isinstance(raw_sources, list):
        return raw_sources

    if isinstance(raw_sources, tuple):
        return list(raw_sources)

    if isinstance(raw_sources, dict):
        return [raw_sources]

    return [raw_sources]


def normalize_rag_response(result: Any) -> tuple[str, list[Any]]:
    """Normalize strings, tuples, dictionaries and response objects."""

    if isinstance(result, str):
        return result, []

    if isinstance(result, tuple):
        answer = result[0] if len(result) >= 1 else ""
        sources = result[1] if len(result) >= 2 else []

        return str(answer), normalize_sources(sources)

    if isinstance(result, dict):
        answer = (
            result.get("answer")
            or result.get("response")
            or result.get("output")
            or result.get("text")
            or result.get("result")
            or "No answer was generated."
        )

        sources = (
            result.get("sources")
            or result.get("retrieved_sources")
            or result.get("documents")
            or result.get("context")
            or result.get("retrieved_documents")
            or []
        )

        return str(answer), normalize_sources(sources)

    answer = (
        getattr(result, "answer", None)
        or getattr(result, "response", None)
        or getattr(result, "text", None)
        or str(result)
    )

    sources = (
        getattr(result, "sources", None)
        or getattr(result, "documents", None)
        or getattr(result, "retrieved_documents", None)
        or []
    )

    return str(answer), normalize_sources(sources)


def ask_rag(question: str) -> tuple[str, list[Any]]:
    """Get a normalized answer from the Bengaluru RAG engine."""

    rag_engine = load_rag_engine()
    raw_result = call_rag_method(rag_engine, question)

    return normalize_rag_response(raw_result)


# ---------------------------------------------------------------------
# Source formatting
# ---------------------------------------------------------------------

def get_nested_metadata(source: dict[str, Any]) -> dict[str, Any]:
    metadata = source.get("metadata")

    if isinstance(metadata, dict):
        return metadata

    document = source.get("document")

    if isinstance(document, dict):
        nested_metadata = document.get("metadata")

        if isinstance(nested_metadata, dict):
            return nested_metadata

        return document

    return source


def format_source(source: Any, position: int) -> dict[str, str]:
    """Create a readable title, period, score and preview for one source."""

    if not isinstance(source, dict):
        return {
            "number": str(position),
            "title": str(source),
            "period": "",
            "score": "",
            "preview": "",
        }

    metadata = get_nested_metadata(source)

    source_model = (
        metadata.get("source_model")
        or metadata.get("source")
        or metadata.get("table_name")
        or metadata.get("model")
        or source.get("source_model")
        or source.get("source")
        or "Project evidence"
    )

    title = (
        metadata.get("title")
        or metadata.get("finding_title")
        or metadata.get("kpi_name")
        or metadata.get("station_name")
        or metadata.get("fiscal_year")
        or source.get("title")
        or source_model
    )

    period = (
        metadata.get("reporting_period")
        or metadata.get("period")
        or metadata.get("fiscal_year")
        or metadata.get("observation_year")
        or ""
    )

    similarity = (
        source.get("similarity")
        or source.get("score")
        or metadata.get("similarity")
        or metadata.get("score")
    )

    if isinstance(similarity, (int, float)):
        score = f"{float(similarity):.3f}"
    else:
        score = str(similarity) if similarity else ""

    preview = (
        source.get("content")
        or source.get("text")
        or metadata.get("content")
        or metadata.get("text")
        or metadata.get("description")
        or ""
    )

    if len(str(preview)) > 500:
        preview = f"{str(preview)[:500]}…"

    display_title = str(title)

    if str(source_model) not in display_title:
        display_title = f"{source_model} · {display_title}"

    return {
        "number": str(position),
        "title": display_title,
        "period": str(period),
        "score": score,
        "preview": str(preview),
    }


def render_sources(sources: list[Any]) -> None:
    """Display retrieved evidence below an assistant answer."""

    if not sources:
        return

    with st.expander(
        f"View retrieved evidence ({len(sources)} sources)",
        expanded=False,
    ):
        for position, source in enumerate(sources, start=1):
            formatted = format_source(source, position)

            details: list[str] = []

            if formatted["period"]:
                details.append(formatted["period"])

            if formatted["score"]:
                details.append(
                    f"Similarity {formatted['score']}"
                )

            detail_text = " · ".join(details)

            st.markdown(
                f"""
                <div class="evidence-card">
                    <div>
                        <span class="evidence-number">
                            {formatted["number"]}
                        </span>
                        <strong>{formatted["title"]}</strong>
                    </div>
                    <div style="
                        margin-top: 0.35rem;
                        color: #7a7a7f;
                    ">
                        {detail_text}
                    </div>
                    {
                        '<div style="margin-top:0.45rem;">'
                        + formatted["preview"]
                        + "</div>"
                        if formatted["preview"]
                        else ""
                    }
                </div>
                """,
                unsafe_allow_html=True,
            )


# ---------------------------------------------------------------------
# Chat state
# ---------------------------------------------------------------------

if "messages" not in st.session_state:
    st.session_state.messages = []

if "queued_question" not in st.session_state:
    st.session_state.queued_question = None


def get_chat_avatar(role: str) -> str:
    """
    Return a valid Streamlit avatar.

    Important: use a single emoji. Text such as "AI" or "BLR" is treated as
    an image path by Streamlit and produces StreamlitAPIException.
    """

    return "👤" if role == "user" else "🤖"


def queue_question(question: str) -> None:
    st.session_state.queued_question = question


# ---------------------------------------------------------------------
# Sidebar
# ---------------------------------------------------------------------

with st.sidebar:
    st.markdown(
        """
        <div class="brand-mark">BLR</div>
        <p class="brand-title">Mobility Intelligence</p>
        <p class="brand-subtitle">
            Evidence-backed urban analytics for Bengaluru.
        </p>
        """,
        unsafe_allow_html=True,
    )

    if knowledge_information["ready"]:
        st.markdown(
            """
            <div class="status-card">
                <span class="status-dot"></span>
                Local analytical snapshot ready
            </div>
            """,
            unsafe_allow_html=True,
        )
    else:
        st.warning(
            "The local knowledge-base or embedding files are missing."
        )

    st.markdown(
        '<div class="sidebar-label">Explore</div>',
        unsafe_allow_html=True,
    )

    st.markdown(
        """
        <div class="topic-pills">
            <span class="topic-pill">City mobility KPIs</span>
            <span class="topic-pill">Metro demand</span>
            <span class="topic-pill">Vehicle registrations</span>
            <span class="topic-pill">BMTC performance</span>
            <span class="topic-pill">Air quality and weather</span>
            <span class="topic-pill">Road safety</span>
            <span class="topic-pill">Cross-dataset findings</span>
        </div>
        """,
        unsafe_allow_html=True,
    )

    st.markdown(
        '<div class="sidebar-label">Conversation</div>',
        unsafe_allow_html=True,
    )

    if st.button(
        "Start a new conversation",
        use_container_width=True,
    ):
        st.session_state.messages = []
        st.session_state.queued_question = None
        st.rerun()

    st.markdown(
        f"""
        <div class="sidebar-note">
            <strong>Snapshot mode</strong><br>
            This application uses the locally saved analytical snapshot.
            Snowflake is not required for answering questions.
            <br><br>
            Last snapshot update:
            <strong>{knowledge_information["last_updated"]}</strong>
        </div>
        """,
        unsafe_allow_html=True,
    )


# ---------------------------------------------------------------------
# Main page
# ---------------------------------------------------------------------

st.markdown(
    """
    <section class="hero">
        <div class="hero-eyebrow">
            Bengaluru Urban Intelligence
        </div>
        <h1 class="hero-title">Ask Bengaluru.</h1>
        <p class="hero-description">
            Explore mobility, Metro demand, vehicle growth, air quality,
            weather, public transport and road safety through evidence
            generated by the analytical data platform.
        </p>
    </section>
    """,
    unsafe_allow_html=True,
)

metric_one, metric_two, metric_three, metric_four = st.columns(4)

with metric_one:
    st.metric(
        "Evidence records",
        f"{knowledge_information['documents']:,}",
    )

with metric_two:
    st.metric(
        "Analytical sources",
        f"{knowledge_information['sources']:,}",
    )

with metric_three:
    st.metric(
        "Vector dimensions",
        "768",
    )

with metric_four:
    st.metric(
        "Answer mode",
        "Grounded RAG",
    )


# ---------------------------------------------------------------------
# Suggested questions
# ---------------------------------------------------------------------

st.markdown(
    '<div class="section-heading">Start with a question</div>',
    unsafe_allow_html=True,
)

st.markdown(
    """
    <div class="section-description">
        Select a suggested investigation or type your own question below.
    </div>
    """,
    unsafe_allow_html=True,
)

suggested_questions = [
    (
        "How many registered vehicles are there in Bengaluru?",
        "Registered vehicles",
    ),
    (
        "Did registered vehicles grow faster than BMTC schedules?",
        "Vehicle growth vs BMTC",
    ),
    (
        "How does rainfall affect particulate pollution?",
        "Rainfall and pollution",
    ),
    (
        "Which Metro stations have the highest passenger activity?",
        "Busiest Metro stations",
    ),
    (
        "What are the most important road-safety findings?",
        "Road-safety findings",
    ),
    (
        "Summarize Bengaluru's most important mobility challenges.",
        "Executive summary",
    ),
]

suggestion_columns = st.columns(3)

for index, (question, label) in enumerate(suggested_questions):
    with suggestion_columns[index % 3]:
        if st.button(
            label,
            key=f"suggestion_{index}",
            use_container_width=True,
        ):
            queue_question(question)
            st.rerun()


# ---------------------------------------------------------------------
# Conversation
# ---------------------------------------------------------------------

st.markdown(
    '<div class="section-heading">Conversation</div>',
    unsafe_allow_html=True,
)

st.markdown(
    """
    <div class="section-description">
        Answers are generated only from the evidence contained in the
        Bengaluru analytical snapshot.
    </div>
    """,
    unsafe_allow_html=True,
)

if not st.session_state.messages:
    st.info(
        "Ask about transport demand, congestion, air quality, weather, "
        "vehicle registrations, BMTC performance or road safety."
    )

for message in st.session_state.messages:
    role = message.get("role", "assistant")
    content = message.get("content", "")
    sources = message.get("sources", [])

    # Emoji values prevent the invalid-avatar Streamlit exception.
    with st.chat_message(
        role,
        avatar=get_chat_avatar(role),
    ):
        st.markdown(content)

        if role == "assistant":
            render_sources(sources)


queued_question = st.session_state.queued_question
st.session_state.queued_question = None

typed_question = st.chat_input(
    "Ask a question about Bengaluru mobility and urban conditions…"
)

question = queued_question or typed_question

if question:
    question = question.strip()

    if question:
        st.session_state.messages.append(
            {
                "role": "user",
                "content": question,
                "sources": [],
            }
        )

        try:
            with st.spinner(
                "Searching the Bengaluru evidence base…"
            ):
                answer, sources = ask_rag(question)

            st.session_state.messages.append(
                {
                    "role": "assistant",
                    "content": answer,
                    "sources": sources,
                }
            )

        except Exception as error:
            error_message = (
                "I could not generate an answer. Check that the Gemini API "
                "key, knowledge-base file, embedding file and manifest are "
                "available.\n\n"
                f"Technical detail: `{type(error).__name__}: {error}`"
            )

            st.session_state.messages.append(
                {
                    "role": "assistant",
                    "content": error_message,
                    "sources": [],
                }
            )

        st.rerun()


# ---------------------------------------------------------------------
# Footer
# ---------------------------------------------------------------------

st.markdown(
    """
    <div class="footer-note">
        Bengaluru Mobility Intelligence · Built with dbt, Snowflake,
        Power BI, Gemini embeddings and retrieval-augmented generation.
        <br>
        Results reflect the reporting periods and limitations of the
        underlying project datasets.
    </div>
    """,
    unsafe_allow_html=True,
)