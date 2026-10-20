{{ config(
    materialized = 'view',
    schema = 'STAGING'
) }}

with source_data as (

    select
        serial_number_raw,
        cause_of_death_raw,
        male_count_raw,
        male_percentage_raw,
        female_count_raw,
        female_percentage_raw,
        total_count_raw,
        total_percentage_raw,
        percent_of_certified_deaths_raw,
        source_filename,
        source_row_number,
        loaded_at

    from {{ source('raw_bangalore', 'respiratory_deaths_2020') }}

),

cleaned as (

    select
        case
            when upper(trim(serial_number_raw)) = 'NA' then null
            else nullif(trim(serial_number_raw), '')
        end as serial_number,

        nullif(trim(cause_of_death_raw), '') as cause_of_death,

        try_to_number(
            regexp_replace(
                nullif(trim(male_count_raw), ''),
                '[^0-9-]',
                ''
            )
        ) as male_deaths,

        try_to_decimal(
            regexp_replace(
                nullif(trim(male_percentage_raw), ''),
                '[^0-9.-]',
                ''
            ),
            10,
            2
        ) as male_share_pct,

        try_to_number(
            regexp_replace(
                nullif(trim(female_count_raw), ''),
                '[^0-9-]',
                ''
            )
        ) as female_deaths,

        try_to_decimal(
            regexp_replace(
                nullif(trim(female_percentage_raw), ''),
                '[^0-9.-]',
                ''
            ),
            10,
            2
        ) as female_share_pct,

        try_to_number(
            regexp_replace(
                nullif(trim(total_count_raw), ''),
                '[^0-9-]',
                ''
            )
        ) as total_deaths,

        try_to_decimal(
            regexp_replace(
                nullif(trim(total_percentage_raw), ''),
                '[^0-9.-]',
                ''
            ),
            10,
            2
        ) as respiratory_death_share_pct,

        try_to_decimal(
            regexp_replace(
                nullif(trim(percent_of_certified_deaths_raw), ''),
                '[^0-9.-]',
                ''
            ),
            10,
            2
        ) as share_of_all_medically_certified_deaths_pct,

        source_filename,
        source_row_number,
        loaded_at

    from source_data

),

classified as (

    select
        *,

        case
            when upper(cause_of_death) like
                 'TOTAL MEDICALLY CERTIFIED DEATHS%'
                then 'TOTAL_RESPIRATORY_DEATHS'

            when upper(cause_of_death) like
                 'DEATHS DUE TO DISEASES OF RESPIRATORY SYSTEM AS PERCENTAGE%'
                then 'SUMMARY_RATE'

            else 'CAUSE_DETAIL'
        end as row_type

    from cleaned

),

final as (

    select
        md5(
            concat_ws(
                '||',
                cause_of_death,
                source_row_number::varchar
            )
        ) as respiratory_death_record_id,

        2020 as reference_year,

        'UNVERIFIED_FROM_SUPPLIED_FILE'
            as geography_scope,

        'CONTEXT_ONLY_NOT_JOINABLE_TO_BENGALURU_COMMUTERS'
            as analytical_use_status,

        row_type,
        serial_number,
        cause_of_death,

        male_deaths,
        male_share_pct,
        female_deaths,
        female_share_pct,
        total_deaths,
        respiratory_death_share_pct,
        share_of_all_medically_certified_deaths_pct,

        case
            when male_deaths is null
              or female_deaths is null
              or total_deaths is null
                then null

            else male_deaths + female_deaths
        end as calculated_total_deaths,

        case
            when male_deaths is null
              or female_deaths is null
              or total_deaths is null
                then null

            else total_deaths - (male_deaths + female_deaths)
        end as death_count_difference,

        source_filename,
        source_row_number,
        loaded_at

    from classified

)

select *
from final