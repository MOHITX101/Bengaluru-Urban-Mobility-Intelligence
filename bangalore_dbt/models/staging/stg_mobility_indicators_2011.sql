{{ config(
    materialized = 'view',
    schema = 'STAGING'
) }}

with source_data as (

    select
        zone_raw,
        population_2001_raw,
        population_2011_raw,
        area_sq_km_raw,
        population_density_2011_raw,
        employment_density_2011_raw,
        average_household_size_raw,
        average_per_capita_income_raw,

        walk_mode_share_raw,
        bicycle_mode_share_raw,
        taxi_mode_share_raw,
        auto_mode_share_raw,
        two_wheeler_mode_share_raw,
        car_van_mode_share_raw,
        public_transport_share_raw,
        slow_moving_vehicle_share_raw,

        per_capita_trip_rate_raw,
        average_trip_length_km_raw,
        trip_under_15_min_share_raw,
        trip_under_30_min_share_raw,

        source_filename,
        source_row_number,
        loaded_at

    from {{ source('raw_bangalore', 'mobility_indicators_2011') }}

),

cleaned as (

    select
        nullif(trim(zone_raw), '') as zone_name,

        try_to_number(
            regexp_replace(
                nullif(trim(population_2001_raw), ''),
                '[^0-9-]',
                ''
            )
        ) as population_2001,

        try_to_number(
            regexp_replace(
                nullif(trim(population_2011_raw), ''),
                '[^0-9-]',
                ''
            )
        ) as population_2011,

        try_to_decimal(
            regexp_replace(
                nullif(trim(area_sq_km_raw), ''),
                '[^0-9.-]',
                ''
            ),
            18,
            2
        ) as area_sq_km,

        try_to_decimal(
            regexp_replace(
                nullif(trim(population_density_2011_raw), ''),
                '[^0-9.-]',
                ''
            ),
            18,
            2
        ) as reported_population_density_2011,

        try_to_decimal(
            regexp_replace(
                nullif(trim(employment_density_2011_raw), ''),
                '[^0-9.-]',
                ''
            ),
            18,
            2
        ) as reported_employment_density_2011,

        try_to_decimal(
            regexp_replace(
                nullif(trim(average_household_size_raw), ''),
                '[^0-9.-]',
                ''
            ),
            18,
            2
        ) as average_household_size,

        try_to_decimal(
            regexp_replace(
                nullif(trim(average_per_capita_income_raw), ''),
                '[^0-9.-]',
                ''
            ),
            18,
            2
        ) as average_per_capita_income,

        try_to_decimal(
            regexp_replace(
                nullif(trim(walk_mode_share_raw), ''),
                '[^0-9.-]',
                ''
            ),
            10,
            2
        ) as walk_mode_share_pct,

        try_to_decimal(
            regexp_replace(
                nullif(trim(bicycle_mode_share_raw), ''),
                '[^0-9.-]',
                ''
            ),
            10,
            2
        ) as bicycle_mode_share_pct,

        try_to_decimal(
            regexp_replace(
                nullif(trim(taxi_mode_share_raw), ''),
                '[^0-9.-]',
                ''
            ),
            10,
            2
        ) as taxi_mode_share_pct,

        try_to_decimal(
            regexp_replace(
                nullif(trim(auto_mode_share_raw), ''),
                '[^0-9.-]',
                ''
            ),
            10,
            2
        ) as auto_mode_share_pct,

        try_to_decimal(
            regexp_replace(
                nullif(trim(two_wheeler_mode_share_raw), ''),
                '[^0-9.-]',
                ''
            ),
            10,
            2
        ) as two_wheeler_mode_share_pct,

        try_to_decimal(
            regexp_replace(
                nullif(trim(car_van_mode_share_raw), ''),
                '[^0-9.-]',
                ''
            ),
            10,
            2
        ) as car_van_mode_share_pct,

        try_to_decimal(
            regexp_replace(
                nullif(trim(public_transport_share_raw), ''),
                '[^0-9.-]',
                ''
            ),
            10,
            2
        ) as public_transport_mode_share_pct,

        try_to_decimal(
            regexp_replace(
                nullif(trim(slow_moving_vehicle_share_raw), ''),
                '[^0-9.-]',
                ''
            ),
            10,
            2
        ) as slow_moving_vehicle_share_pct,

        try_to_decimal(
            regexp_replace(
                nullif(trim(per_capita_trip_rate_raw), ''),
                '[^0-9.-]',
                ''
            ),
            10,
            3
        ) as per_capita_trip_rate,

        try_to_decimal(
            regexp_replace(
                nullif(trim(average_trip_length_km_raw), ''),
                '[^0-9.-]',
                ''
            ),
            10,
            2
        ) as average_trip_length_km,

        try_to_decimal(
            regexp_replace(
                nullif(trim(trip_under_15_min_share_raw), ''),
                '[^0-9.-]',
                ''
            ),
            10,
            2
        ) as trips_under_15_minutes_pct,

        try_to_decimal(
            regexp_replace(
                nullif(trim(trip_under_30_min_share_raw), ''),
                '[^0-9.-]',
                ''
            ),
            10,
            2
        ) as trips_under_30_minutes_pct,

        source_filename,
        source_row_number,
        loaded_at

    from source_data

),

calculated as (

    select
        *,

        case
            when upper(zone_name) like '%BIAAPA%'
                then 'BIAAPA_TALUK'
            else 'BENGALURU_ZONE'
        end as zone_classification,

        round(
            (
                population_2011 - population_2001
            )
            / nullif(population_2001, 0)
            * 100,
            2
        ) as population_growth_2001_2011_pct,

        round(
            population_2011
            / nullif(area_sq_km, 0),
            2
        ) as calculated_population_density_2011,

        round(
            reported_population_density_2011
            -
            (
                population_2011
                / nullif(area_sq_km, 0)
            ),
            2
        ) as population_density_difference,

        walk_mode_share_pct
        + bicycle_mode_share_pct
            as active_travel_mode_share_pct,

        two_wheeler_mode_share_pct
        + car_van_mode_share_pct
            as private_motorized_mode_share_pct,

        taxi_mode_share_pct
        + auto_mode_share_pct
        + public_transport_mode_share_pct
            as shared_motorized_mode_share_pct,

        walk_mode_share_pct
        + bicycle_mode_share_pct
        + taxi_mode_share_pct
        + auto_mode_share_pct
        + two_wheeler_mode_share_pct
        + car_van_mode_share_pct
        + public_transport_mode_share_pct
        + slow_moving_vehicle_share_pct
            as reported_mode_share_sum_pct

    from cleaned

),

final as (

    select
        md5(zone_name) as mobility_zone_id,

        2011 as reference_year,

        zone_name,
        zone_classification,

        population_2001,
        population_2011,
        population_growth_2001_2011_pct,

        area_sq_km,
        reported_population_density_2011,
        calculated_population_density_2011,
        population_density_difference,
        reported_employment_density_2011,

        average_household_size,
        average_per_capita_income,

        walk_mode_share_pct,
        bicycle_mode_share_pct,
        active_travel_mode_share_pct,

        taxi_mode_share_pct,
        auto_mode_share_pct,
        two_wheeler_mode_share_pct,
        car_van_mode_share_pct,
        private_motorized_mode_share_pct,

        public_transport_mode_share_pct,
        shared_motorized_mode_share_pct,
        slow_moving_vehicle_share_pct,

        reported_mode_share_sum_pct,

        reported_mode_share_sum_pct - 100
            as mode_share_excess_over_100_pct,

        per_capita_trip_rate,
        average_trip_length_km,
        trips_under_15_minutes_pct,
        trips_under_30_minutes_pct,

        source_filename,
        source_row_number,
        loaded_at

    from calculated

)

select *
from final