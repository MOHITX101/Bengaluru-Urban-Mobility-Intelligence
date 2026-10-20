{{ config(
    materialized = 'table'
) }}

with high_coverage_hours as (

    select
        *,

        case
            when is_weekend then 'Weekend'

            when observation_hour between 7 and 10
                then 'Weekday morning peak'

            when observation_hour between 17 and 20
                then 'Weekday evening peak'

            else 'Weekday off-peak'
        end as commute_period

    from {{ ref('mart_metro_air_quality_hourly') }}

    where stations_with_pm25 >= 5
      and city_avg_pm25_ug_m3 is not null

),

period_summary as (

    select
        commute_period,

        count(*) as high_coverage_network_hours,
        count(distinct business_date) as observed_days,

        min(stations_with_pm25) as minimum_pm25_stations,
        max(stations_with_pm25) as maximum_pm25_stations,

        sum(network_passenger_activity) as total_passenger_activity,
        avg(network_passenger_activity) as avg_hourly_passenger_activity,

        avg(city_avg_pm25_ug_m3) as unweighted_avg_pm25_ug_m3,

        sum(passenger_pm25_exposure_index)
            / nullif(
                sum(network_passenger_activity),
                0
            ) as passenger_weighted_avg_pm25_ug_m3,

        avg(passenger_pm25_exposure_index)
            as avg_hourly_pm25_exposure_index

    from high_coverage_hours

    group by commute_period

),

ranked as (

    select
        *,

        dense_rank() over (
            order by passenger_weighted_avg_pm25_ug_m3 desc
        ) as pm25_concentration_rank,

        dense_rank() over (
            order by avg_hourly_pm25_exposure_index desc
        ) as combined_exposure_index_rank

    from period_summary

)

select
    commute_period,
    high_coverage_network_hours,
    observed_days,
    minimum_pm25_stations,
    maximum_pm25_stations,

    total_passenger_activity,

    round(
        avg_hourly_passenger_activity,
        2
    ) as avg_hourly_passenger_activity,

    round(
        unweighted_avg_pm25_ug_m3,
        2
    ) as unweighted_avg_pm25_ug_m3,

    round(
        passenger_weighted_avg_pm25_ug_m3,
        2
    ) as passenger_weighted_avg_pm25_ug_m3,

    round(
        avg_hourly_pm25_exposure_index,
        2
    ) as avg_hourly_pm25_exposure_index,

    pm25_concentration_rank,
    combined_exposure_index_rank

from ranked