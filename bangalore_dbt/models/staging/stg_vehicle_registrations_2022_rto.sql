{{ config(
    materialized = 'view',
    schema = 'STAGING'
) }}

with source_data as (

    select
        serial_number_raw,
        category_raw,
        vehicle_type_raw,
        newly_added_raw,
        total_registered_raw,

        central_raw,
        west_raw,
        east_raw,
        north_raw,
        south_raw,
        kr_puram_raw,
        jnanabharathi_raw,
        electronic_city_raw,
        yelahanka_raw,
        devanahalli_raw,
        rto_ar_raw,
        chandapura_raw,

        source_filename,
        source_row_number,
        loaded_at

    from {{ source('raw_bangalore', 'vehicle_registrations_2022_rto') }}

),

cleaned as (

    select
        nullif(trim(serial_number_raw), '') as serial_number,
        nullif(trim(category_raw), '') as vehicle_category,
        nullif(trim(vehicle_type_raw), '') as vehicle_type,

        try_to_number(
            regexp_replace(
                nullif(trim(newly_added_raw), ''),
                '[^0-9-]',
                ''
            )
        ) as newly_added_vehicles,

        try_to_number(
            regexp_replace(
                nullif(trim(total_registered_raw), ''),
                '[^0-9-]',
                ''
            )
        ) as total_registered_vehicles,

        try_to_number(regexp_replace(
            nullif(trim(central_raw), ''), '[^0-9-]', ''
        )) as central_registered_vehicles,

        try_to_number(regexp_replace(
            nullif(trim(west_raw), ''), '[^0-9-]', ''
        )) as west_registered_vehicles,

        try_to_number(regexp_replace(
            nullif(trim(east_raw), ''), '[^0-9-]', ''
        )) as east_registered_vehicles,

        try_to_number(regexp_replace(
            nullif(trim(north_raw), ''), '[^0-9-]', ''
        )) as north_registered_vehicles,

        try_to_number(regexp_replace(
            nullif(trim(south_raw), ''), '[^0-9-]', ''
        )) as south_registered_vehicles,

        try_to_number(regexp_replace(
            nullif(trim(kr_puram_raw), ''), '[^0-9-]', ''
        )) as kr_puram_registered_vehicles,

        try_to_number(regexp_replace(
            nullif(trim(jnanabharathi_raw), ''), '[^0-9-]', ''
        )) as jnanabharathi_registered_vehicles,

        try_to_number(regexp_replace(
            nullif(trim(electronic_city_raw), ''), '[^0-9-]', ''
        )) as electronic_city_registered_vehicles,

        try_to_number(regexp_replace(
            nullif(trim(yelahanka_raw), ''), '[^0-9-]', ''
        )) as yelahanka_registered_vehicles,

        try_to_number(regexp_replace(
            nullif(trim(devanahalli_raw), ''), '[^0-9-]', ''
        )) as devanahalli_registered_vehicles,

        try_to_number(regexp_replace(
            nullif(trim(rto_ar_raw), ''), '[^0-9-]', ''
        )) as rto_ar_registered_vehicles,

        try_to_number(regexp_replace(
            nullif(trim(chandapura_raw), ''), '[^0-9-]', ''
        )) as chandapura_registered_vehicles,

        source_filename,
        source_row_number,
        loaded_at

    from source_data

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

        coalesce(central_registered_vehicles, 0)
        + coalesce(west_registered_vehicles, 0)
        + coalesce(east_registered_vehicles, 0)
        + coalesce(north_registered_vehicles, 0)
        + coalesce(south_registered_vehicles, 0)
        + coalesce(kr_puram_registered_vehicles, 0)
        + coalesce(jnanabharathi_registered_vehicles, 0)
        + coalesce(electronic_city_registered_vehicles, 0)
        + coalesce(yelahanka_registered_vehicles, 0)
        + coalesce(devanahalli_registered_vehicles, 0)
        + coalesce(rto_ar_registered_vehicles, 0)
        + coalesce(chandapura_registered_vehicles, 0)
            as calculated_rto_total,

        total_registered_vehicles
        - newly_added_vehicles
            as estimated_opening_registered_vehicles

    from cleaned

),

final as (

    select
        md5(
            concat_ws(
                '||',
                source_filename,
                source_row_number::varchar
            )
        ) as vehicle_registration_row_id,

        '2021-22' as fiscal_year,
        2021 as fiscal_year_start,
        2022 as fiscal_year_end,
        to_date('2022-03-31') as snapshot_date,

        serial_number,
        vehicle_category,
        vehicle_type,
        row_type,

        estimated_opening_registered_vehicles,
        newly_added_vehicles,
        total_registered_vehicles,

        central_registered_vehicles,
        west_registered_vehicles,
        east_registered_vehicles,
        north_registered_vehicles,
        south_registered_vehicles,
        kr_puram_registered_vehicles,
        jnanabharathi_registered_vehicles,
        electronic_city_registered_vehicles,
        yelahanka_registered_vehicles,
        devanahalli_registered_vehicles,
        rto_ar_registered_vehicles,
        chandapura_registered_vehicles,

        calculated_rto_total,

        total_registered_vehicles
        - calculated_rto_total
            as rto_total_difference,

        case
            when total_registered_vehicles = calculated_rto_total
                then 'MATCHED'
            else 'DIFFERENCE'
        end as rto_reconciliation_status,

        source_filename,
        source_row_number,
        loaded_at

    from classified

)

select *
from final