{{ config(
    materialized = 'view'
) }}

with raw_offences as (

    select *
    from {{ source('raw_bangalore', 'mv_act_offences') }}

),

cleaned_wide as (

    select
        try_to_number(serial_number_raw) as serial_number,
        nullif(trim(offence_type_raw), '') as offence_type,

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

    from raw_offences

    where upper(trim(offence_type_raw)) <> 'TOTAL'
      and nullif(trim(offence_type_raw), '') is not null

),

unpivoted as (

    select
        serial_number,
        offence_type,

        try_to_number(
            replace(
                replace(year_column, '_RAW', ''),
                'Y',
                ''
            )
        ) as enforcement_year,

        try_to_number(offence_cases_raw) as offence_cases,

        source_filename,
        source_row_number,
        loaded_at

    from cleaned_wide

    unpivot include nulls (
        offence_cases_raw for year_column in (
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

),

final as (

    select
        md5(
            concat_ws(
                '|',
                to_varchar(enforcement_year),
                upper(offence_type)
            )
        ) as offence_year_id,

        serial_number,
        offence_type,
        enforcement_year,
        offence_cases,

        case
            when offence_cases is null then true
            else false
        end as is_missing_offence_count,

        source_filename,
        source_row_number,
        loaded_at

    from unpivoted

    where enforcement_year between 2018 and 2025

)

select *
from final