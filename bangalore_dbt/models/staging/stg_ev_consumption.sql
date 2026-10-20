{{ config(
    materialized = 'view',
    schema = 'STAGING'
) }}

with source_data as (

    select
        metric_raw,
        fy_2022_23_raw,
        fy_2021_22_raw,
        fy_2020_21_raw,
        source_filename,
        source_row_number,
        loaded_at

    from {{ source('raw_bangalore', 'ev_consumption') }}

),

unpivoted as (

    select
        metric_raw,
        '2020-21' as fiscal_year,
        2020 as fiscal_year_start,
        fy_2020_21_raw as value_raw,
        source_filename,
        source_row_number,
        loaded_at

    from source_data

    union all

    select
        metric_raw,
        '2021-22' as fiscal_year,
        2021 as fiscal_year_start,
        fy_2021_22_raw as value_raw,
        source_filename,
        source_row_number,
        loaded_at

    from source_data

    union all

    select
        metric_raw,
        '2022-23' as fiscal_year,
        2022 as fiscal_year_start,
        fy_2022_23_raw as value_raw,
        source_filename,
        source_row_number,
        loaded_at

    from source_data

),

cleaned as (

    select
        trim(metric_raw) as metric_name,

        trim(
            regexp_replace(
                lower(trim(metric_raw)),
                '[^a-z0-9]+',
                '_'
            ),
            '_'
        ) as metric_key,

        case
            when upper(trim(metric_raw)) like 'LT%'
                then 'LT'

            when upper(trim(metric_raw)) like 'HT%'
                then 'HT'

            else 'UNKNOWN'
        end as connection_type,

        fiscal_year,
        fiscal_year_start,
        fiscal_year_start + 1 as fiscal_year_end,

        nullif(trim(value_raw), '') as raw_value,

        try_to_decimal(
            regexp_replace(
                nullif(trim(value_raw), ''),
                '[^0-9.-]',
                ''
            ),
            20,
            4
        ) as metric_value,

        case
            when position('%' in coalesce(value_raw, '')) > 0
                then true
            else false
        end as is_percentage_value,

        source_filename,
        source_row_number,
        loaded_at

    from unpivoted

),

classified as (

    select
        *,

        case
            when is_percentage_value
                then 'PERCENTAGE'

            when metric_key like '%charging_stations%'
                then 'CHARGING_STATIONS'

            when metric_key like '%units%'
                then 'ELECTRICITY_CONSUMPTION'

            when metric_key like '%revenue%'
                then 'REVENUE'

            else 'OTHER'
        end as metric_group,

        case
            when is_percentage_value
                then 'Percent'

            when metric_key like '%charging_stations%'
                then 'Count'

            when metric_key like '%units%'
                then 'kWh'

            when metric_key like '%revenue%'
                then 'INR'

            else 'Source-defined'
        end as measurement_unit

    from cleaned

),

final as (

    select
        md5(
            concat_ws(
                '||',
                metric_key,
                fiscal_year
            )
        ) as ev_metric_year_id,

        fiscal_year,
        fiscal_year_start,
        fiscal_year_end,

        connection_type,
        metric_name,
        metric_key,
        metric_group,
        measurement_unit,

        raw_value,
        metric_value,
        is_percentage_value,

        case
            when raw_value is null then true
            else false
        end as is_missing_value,

        source_filename,
        source_row_number,
        loaded_at

    from classified

)

select *
from final