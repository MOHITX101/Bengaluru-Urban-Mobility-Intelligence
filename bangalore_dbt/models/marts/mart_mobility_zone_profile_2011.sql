{{ config(
    materialized = 'table',
    schema = 'MARTS'
) }}

with base as (

    select
        mobility_zone_id,
        reference_year,
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
        mode_share_excess_over_100_pct,

        per_capita_trip_rate,
        average_trip_length_km,
        trips_under_15_minutes_pct,
        trips_under_30_minutes_pct

    from {{ ref('stg_mobility_indicators_2011') }}

),

calculated as (

    select
        *,

        round(
            population_2011 * per_capita_trip_rate,
            0
        ) as estimated_daily_person_trips,

        round(
            population_2011
            * per_capita_trip_rate
            * active_travel_mode_share_pct
            / 100,
            0
        ) as estimated_daily_active_travel_trips,

        round(
            population_2011
            * per_capita_trip_rate
            * private_motorized_mode_share_pct
            / 100,
            0
        ) as estimated_daily_private_motorized_trips,

        round(
            population_2011
            * per_capita_trip_rate
            * public_transport_mode_share_pct
            / 100,
            0
        ) as estimated_daily_public_transport_trips,

        round(
            population_2011
            * per_capita_trip_rate
            * trips_under_30_minutes_pct
            / 100,
            0
        ) as estimated_daily_trips_under_30_minutes

    from base

),

final as (

    select
        *,

        rank() over (
            order by population_growth_2001_2011_pct desc
        ) as population_growth_rank,

        rank() over (
            order by active_travel_mode_share_pct desc
        ) as active_travel_share_rank,

        rank() over (
            order by private_motorized_mode_share_pct desc
        ) as private_motorized_share_rank,

        rank() over (
            order by public_transport_mode_share_pct desc
        ) as public_transport_share_rank,

        rank() over (
            order by average_trip_length_km desc
        ) as average_trip_length_rank,

        rank() over (
            order by trips_under_30_minutes_pct desc
        ) as short_trip_share_rank

    from calculated

)

select *
from final