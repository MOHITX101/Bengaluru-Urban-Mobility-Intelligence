{{ config(
    materialized = 'view',
    schema = 'STAGING'
) }}

with source_data as (

    select
        serial_number_raw,
        category_raw,
        vehicle_type_raw,
        opening_total_raw,
        net_additions_raw,
        closing_total_raw,
        source_filename,
        source_row_number,
        loaded_at

    from {{ source('raw_bangalore', 'vehicle_registration_snapshots') }}

),

cleaned as (

    select
        nullif(trim(serial_number_raw), '') as serial_number,
        nullif(trim(category_raw), '') as vehicle_category,
        nullif(trim(vehicle_type_raw), '') as vehicle_type,

        try_to_number(
            regexp_replace(
                nullif(trim(opening_total_raw), ''),
                '[^0-9-]',
                ''
            )
        ) as opening_registered_vehicles,

        try_to_number(
            regexp_replace(
                nullif(trim(net_additions_raw), ''),
                '[^0-9-]',
                ''
            )
        ) as net_vehicle_additions,

        try_to_number(
            regexp_replace(
                nullif(trim(closing_total_raw), ''),
                '[^0-9-]',
                ''
            )
        ) as closing_registered_vehicles,

        source_filename,
        source_row_number,
        loaded_at

    from source_data

),

dated as (

    select
        *,

        case
            when lower(source_filename) like '%2025-26%'
                then '2025-26'

            when lower(source_filename) like '%2024%'
                then '2023-24'

            when lower(source_filename) like '%2023%'
                then '2022-23'
        end as fiscal_year,

        case
            when lower(source_filename) like '%2025-26%'
                then 2025

            when lower(source_filename) like '%2024%'
                then 2023

            when lower(source_filename) like '%2023%'
                then 2022
        end as fiscal_year_start,

        case
            when lower(source_filename) like '%2025-26%'
                then 2026

            when lower(source_filename) like '%2024%'
                then 2024

            when lower(source_filename) like '%2023%'
                then 2023
        end as fiscal_year_end,

        case
            when lower(source_filename) like '%2025-26%'
                then to_date('2025-03-31')

            when lower(source_filename) like '%2024%'
                then to_date('2023-03-31')

            /*
            The source header explicitly states 28-02-2022.
            We retain that reported date rather than silently replacing it.
            */
            when lower(source_filename) like '%2023%'
                then to_date('2022-02-28')
        end as opening_snapshot_date,

        case
            when lower(source_filename) like '%2025-26%'
                then to_date('2026-03-31')

            when lower(source_filename) like '%2024%'
                then to_date('2024-03-31')

            when lower(source_filename) like '%2023%'
                then to_date('2023-03-31')
        end as closing_snapshot_date

    from cleaned

),

classified as (

    select
        *,

        case
            when upper(vehicle_category) = 'TOTAL (A)+(B)'
                then 'GRAND_TOTAL'

            when upper(vehicle_category) like 'TOTAL%'
              or vehicle_type is null
                then 'SUBTOTAL'

            else 'DETAIL'
        end as row_type,

        opening_registered_vehicles
        + net_vehicle_additions
            as calculated_closing_registered_vehicles

    from dated

),

final as (

    select
        md5(
            concat_ws(
                '||',
                source_filename,
                source_row_number::varchar
            )
        ) as vehicle_snapshot_row_id,

        fiscal_year,
        fiscal_year_start,
        fiscal_year_end,
        opening_snapshot_date,
        closing_snapshot_date,

        serial_number,
        vehicle_category,
        vehicle_type,
        row_type,

        opening_registered_vehicles,
        net_vehicle_additions,
        closing_registered_vehicles,

        calculated_closing_registered_vehicles,

        closing_registered_vehicles
        - calculated_closing_registered_vehicles
            as closing_total_difference,

        case
            when closing_registered_vehicles
                 = calculated_closing_registered_vehicles
                then 'MATCHED'
            else 'DIFFERENCE'
        end as closing_reconciliation_status,

        case
            when net_vehicle_additions < 0 then true
            else false
        end as has_negative_net_additions,

        /*
        These flags document known source-header inconsistencies.
        They do not modify the source numbers.
        */
        case
            when lower(source_filename) like '%2024%'
                then true
            else false
        end as source_additions_header_year_mismatch,

        case
            when lower(source_filename) like '%2025-26%'
                then true
            else false
        end as source_closing_header_period_mismatch,

        source_filename,
        source_row_number,
        loaded_at

    from classified

)

select *
from final