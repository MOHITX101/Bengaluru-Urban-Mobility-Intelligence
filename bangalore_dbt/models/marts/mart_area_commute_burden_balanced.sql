{{ config(
    materialized = 'table'
) }}

with traffic as (

    select *
    from {{ ref('mart_traffic_weather') }}

),

complete_dates as (

    select
        traffic_date

    from traffic

    group by traffic_date

    having count(distinct area_name) = 8

),

area_day as (

    select
        t.traffic_date,
        t.area_name,

        count(distinct t.road_name) as roads_observed,

        avg(t.traffic_volume) as daily_avg_traffic_volume,
        avg(t.average_speed_kmph) as daily_avg_speed_kmph,
        avg(t.travel_time_index) as daily_avg_travel_time_index,
        avg(t.congestion_level) as daily_avg_congestion_level,

        100.0 * count_if(
            t.travel_time_index = 1.5
        ) / nullif(count(*), 0) as daily_tti_ceiling_hit_rate_pct

    from traffic t

    inner join complete_dates d
        on t.traffic_date = d.traffic_date

    group by
        t.traffic_date,
        t.area_name

),

balanced_summary as (

    select
        area_name,

        count(*) as balanced_comparison_days,
        avg(roads_observed) as avg_roads_observed_per_day,

        avg(daily_avg_traffic_volume) as balanced_avg_traffic_volume,
        avg(daily_avg_speed_kmph) as balanced_avg_speed_kmph,
        avg(daily_avg_travel_time_index) as balanced_avg_travel_time_index,
        avg(daily_avg_congestion_level) as balanced_avg_congestion_level,
        avg(daily_tti_ceiling_hit_rate_pct) as balanced_tti_ceiling_hit_rate_pct

    from area_day

    group by area_name

),

balanced_ranked as (

    select
        *,

        dense_rank() over (
            order by balanced_avg_travel_time_index desc
        ) as balanced_travel_time_rank,

        dense_rank() over (
            order by balanced_tti_ceiling_hit_rate_pct desc
        ) as balanced_ceiling_hit_rank

    from balanced_summary

)

select
    b.area_name,
    b.balanced_comparison_days,
    round(b.avg_roads_observed_per_day, 2) as avg_roads_observed_per_day,

    f.avg_travel_time_index as full_sample_avg_tti,
    round(b.balanced_avg_travel_time_index, 3) as balanced_avg_tti,
    round(
        b.balanced_avg_travel_time_index
        - f.avg_travel_time_index,
        3
    ) as avg_tti_difference,

    f.tti_ceiling_hit_rate_pct as full_sample_ceiling_hit_pct,
    round(
        b.balanced_tti_ceiling_hit_rate_pct,
        2
    ) as balanced_ceiling_hit_pct,

    round(b.balanced_avg_traffic_volume, 2) as balanced_avg_traffic_volume,
    round(b.balanced_avg_speed_kmph, 2) as balanced_avg_speed_kmph,
    round(b.balanced_avg_congestion_level, 2) as balanced_avg_congestion_level,

    f.travel_time_burden_rank as full_sample_rank,
    b.balanced_travel_time_rank as balanced_sample_rank,

    b.balanced_travel_time_rank
        - f.travel_time_burden_rank as rank_position_change,

    b.balanced_ceiling_hit_rank

from balanced_ranked b

inner join {{ ref('mart_area_commute_burden') }} f
    on b.area_name = f.area_name