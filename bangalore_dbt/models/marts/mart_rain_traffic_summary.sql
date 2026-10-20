{{ config(
    materialized = 'table'
) }}


with base as (

    select *
    from {{ ref('mart_traffic_weather') }}
    where has_precipitation is not null

),

summary as (

    select
        avg(case when has_precipitation then traffic_volume end)
            as rainy_traffic_volume,
        avg(case when not has_precipitation then traffic_volume end)
            as dry_traffic_volume,

        avg(case when has_precipitation then average_speed_kmph end)
            as rainy_speed,
        avg(case when not has_precipitation then average_speed_kmph end)
            as dry_speed,

        avg(case when has_precipitation then travel_time_index end)
            as rainy_travel_time_index,
        avg(case when not has_precipitation then travel_time_index end)
            as dry_travel_time_index,

        avg(case when has_precipitation then congestion_level end)
            as rainy_congestion,
        avg(case when not has_precipitation then congestion_level end)
            as dry_congestion,

        avg(case when has_precipitation then incident_reports end)
            as rainy_incidents,
        avg(case when not has_precipitation then incident_reports end)
            as dry_incidents

    from base

)

select
    'Traffic volume' as metric,
    round(rainy_traffic_volume, 2) as rainy_average,
    round(dry_traffic_volume, 2) as no_rain_average,
    round(rainy_traffic_volume - dry_traffic_volume, 2) as difference,
    round(
        100 * (rainy_traffic_volume - dry_traffic_volume)
        / nullif(dry_traffic_volume, 0),
        2
    ) as percentage_difference
from summary

union all

select
    'Average speed (km/h)',
    round(rainy_speed, 2),
    round(dry_speed, 2),
    round(rainy_speed - dry_speed, 2),
    round(100 * (rainy_speed - dry_speed) / nullif(dry_speed, 0), 2)
from summary

union all

select
    'Travel time index',
    round(rainy_travel_time_index, 3),
    round(dry_travel_time_index, 3),
    round(rainy_travel_time_index - dry_travel_time_index, 3),
    round(
        100 * (rainy_travel_time_index - dry_travel_time_index)
        / nullif(dry_travel_time_index, 0),
        2
    )
from summary

union all

select
    'Congestion level',
    round(rainy_congestion, 2),
    round(dry_congestion, 2),
    round(rainy_congestion - dry_congestion, 2),
    round(100 * (rainy_congestion - dry_congestion) / nullif(dry_congestion, 0), 2)
from summary

union all

select
    'Incident reports',
    round(rainy_incidents, 2),
    round(dry_incidents, 2),
    round(rainy_incidents - dry_incidents, 2),
    round(100 * (rainy_incidents - dry_incidents) / nullif(dry_incidents, 0), 2)
from summary

order by metric