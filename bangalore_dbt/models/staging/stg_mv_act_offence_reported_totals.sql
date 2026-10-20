{{ config(
    materialized = 'view'
) }}

with raw_total_row as (

    select
        y2018_raw,
        y2019_raw,
        y2020_raw,
        y2021_raw,
        y2022_raw,
        y2023_raw,
        y2024_raw,
        y2025_raw,

        source_filename,
        source_row_number,
        loaded_at

    from {{ source('raw_bangalore', 'mv_act_offences') }}

    where upper(trim(offence_type_raw)) = 'TOTAL'

),

unpivoted as (

    select
        try_to_number(
            replace(
                replace(year_column, '_RAW', ''),
                'Y',
                ''
            )
        ) as enforcement_year,

        try_to_number(reported_total_raw)
            as reported_total_offence_cases,

        source_filename,
        source_row_number,
        loaded_at

    from raw_total_row

    unpivot include nulls (
        reported_total_raw for year_column in (
            y2018_raw,
            y2019_raw,
            y2020_raw,
            y2021_raw,
            y2022_raw,
            y2023_raw,
            y2024_raw,
            y2025_raw
        )
    )

)

select
    md5(
        to_varchar(enforcement_year)
    ) as offence_total_year_id,

    enforcement_year,
    reported_total_offence_cases,
    source_filename,
    source_row_number,
    loaded_at

from unpivoted

where enforcement_year between 2018 and 2025