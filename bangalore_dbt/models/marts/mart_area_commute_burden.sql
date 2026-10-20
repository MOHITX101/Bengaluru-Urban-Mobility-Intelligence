{{ config(
    materialized = 'table'
) }}

with area_summary as (

    select
        area_name,

        count(*)                              as traffic_observations,
        count(distinct traffic_date)          as observed_days,
        count(distinct road_name)             as roads_covered,

        avg(traffic_volume)                   as avg_traffic_volume,
        avg(average_speed_kmph)               as avg_speed_kmph,
        avg(travel_time_index)                as avg_travel_time_index,
        median(travel_time_index)             as median_travel_time_index,

        avg(
            greatest(travel_time_index - 1, 0)
        ) * 100                               as estimated_extra_travel_time_pct,

        count_if(
            travel_time_index = 1.5
        )                                     as tti_ceiling_observations,

        100.0 * count_if(
            travel_time_index = 1.5
        ) / nullif(count(*), 0)               as tti_ceiling_hit_rate_pct,

        avg(congestion_level)                 as avg_congestion_level,
        avg(incident_reports)                 as avg_incident_reports,

        min(traffic_date)                     as first_observation_date,
        max(traffic_date)                     as last_observation_date

    from {{ ref('mart_traffic_weather') }}

    group by area_name

),

ranked as (

    select
        *,

        dense_rank() over (
            order by avg_travel_time_index desc
        ) as travel_time_burden_rank,

        dense_rank() over (
            order by tti_ceiling_hit_rate_pct desc
        ) as tti_ceiling_hit_rank,

        dense_rank() over (
            order by avg_congestion_level desc
        ) as congestion_rank

    from area_summary

)

select
    area_name,
    traffic_observations,
    observed_days,
    roads_covered,

    round(avg_traffic_volume, 2)                as avg_traffic_volume,
    round(avg_speed_kmph, 2)                    as avg_speed_kmph,
    round(avg_travel_time_index, 3)             as avg_travel_time_index,
    round(median_travel_time_index, 3)          as median_travel_time_index,
    round(estimated_extra_travel_time_pct, 2)   as estimated_extra_travel_time_pct,

    tti_ceiling_observations,
    round(tti_ceiling_hit_rate_pct, 2)          as tti_ceiling_hit_rate_pct,

    round(avg_congestion_level, 2)              as avg_congestion_level,
    round(avg_incident_reports, 2)              as avg_incident_reports,

    first_observation_date,
    last_observation_date,
    travel_time_burden_rank,
    tti_ceiling_hit_rank,
    congestion_rank

from ranked