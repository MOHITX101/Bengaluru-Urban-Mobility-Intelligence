# Bengaluru Urban Mobility Intelligence — Architecture

The platform combines cloud data warehousing, analytics engineering, business
intelligence and retrieval-augmented generation to analyze Bengaluru's
transportation, safety and environmental conditions.

```mermaid
flowchart TD
    A["Public Urban Datasets<br/>Mobility · Metro · BMTC · Vehicles<br/>Air Quality · Weather · Road Safety"]
    B["AWS S3 and Snowflake Stages<br/>Raw file ingestion"]
    C["Snowflake RAW Layer<br/>14 source datasets"]
    D["dbt Staging Layer<br/>Cleaning · Casting · Standardization"]
    E["dbt Analytical Marts<br/>49 models · KPI and reporting tables"]
    F["Data Quality and Documentation<br/>97 tests · 146 successful build tasks"]
    G["Power BI Dashboard<br/>4 analytical pages"]
    H["RAG Knowledge Export<br/>218 evidence documents"]
    I["Gemini Embeddings<br/>768-dimensional vectors"]
    J["Local NumPy Vector Index<br/>Semantic retrieval"]
    K["Streamlit Intelligence App<br/>Evidence-grounded question answering"]

    A --> B
    B --> C
    C --> D
    D --> E

    D -. validation .-> F
    E -. lineage .-> F

    E --> G
    E --> H
    H --> I
    I --> J
    J --> K
```

## Analytical flow

| Layer | Technology | Responsibility |
|---|---|---|
| Data sources | Public datasets | Mobility, transit, vehicles, weather, pollution and safety data |
| Storage and ingestion | AWS S3 and Snowflake | Durable raw-data storage and warehouse ingestion |
| Transformation | dbt | Standardization, business logic, testing and documentation |
| Analytical layer | Snowflake marts | Reusable KPI, trend and reporting datasets |
| Business intelligence | Power BI | Interactive executive and exploratory dashboards |
| Retrieval layer | Gemini embeddings and NumPy | Semantic retrieval over curated analytical evidence |
| AI application | Streamlit and Gemini | Natural-language answers supported by retrieved evidence |

## Offline portfolio design

The Power BI report uses imported data, while the Streamlit application uses
the saved knowledge base and embedding index. Therefore, the portfolio remains
demonstrable even when the original Snowflake trial warehouse is unavailable.