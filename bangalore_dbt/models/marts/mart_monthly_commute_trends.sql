{{ config(
    materialized = 'table'
) }}

with traffic as (

    select *
    from {{ ref('mart_traffic_weather') }}

),

traffic_dates as (

    select distinct traffic_date
    from traffic

),

traffic_monthly as (

    select
        date_trunc('month', traffic_date)::date as month_start,

        count(*) as traffic_observations,
        count(distinct traffic_date) as observed_days,
        count(distinct area_name) as areas_covered,
        count(distinct concat_ws('|', area_name, road_name)) as roads_covered,

        avg(traffic_volume) as avg_traffic_volume,
        avg(average_speed_kmph) as avg_speed_kmph,
        avg(travel_time_index) as avg_travel_time_index,

        avg(
            greatest(travel_time_index - 1, 0)
        ) * 100 as estimated_extra_travel_time_pct,

        100.0 * count_if(
            travel_time_index = 1.5
        ) / nullif(count(*), 0) as tti_ceiling_hit_rate_pct,

        avg(congestion_level) as avg_congestion_level,
        avg(incident_reports) as avg_incident_reports

    from traffic

    group by 1

),

weather_monthly as (

    select
        date_trunc('month', w.weather_date)::date as month_start,

        count(*) as weather_days,
        count_if(w.precipitation_mm > 0) as rainy_days,

        100.0 * count_if(
            w.precipitation_mm > 0
        ) / nullif(count(*), 0) as rainy_day_pct,

        avg(w.precipitation_mm) as avg_daily_precipitation_mm,
        sum(w.precipitation_mm) as total_precipitation_mm,
        avg(w.temperature_2m_c) as avg_temperature_c,
        avg(w.relative_humidity_2m_pct) as avg_relative_humidity_pct,
        avg(w.wind_speed_2m) as avg_wind_speed

    from {{ ref('stg_daily_weather') }} w

    inner join traffic_dates d
        on w.weather_date = d.traffic_date

    group by 1

)

select
    t.month_start,
    year(t.month_start) as traffic_year,
    month(t.month_start) as month_number,
    monthname(t.month_start) as month_name,

    t.traffic_observations,
    t.observed_days,
    t.areas_covered,
    t.roads_covered,
      day(last_day(t.month_start)) as calendar_days_in_month,

    round(
        100.0 * t.observed_days
        / day(last_day(t.month_start)),
        2
    ) as month_coverage_pct,

    case
        when t.observed_days = day(last_day(t.month_start))
            then false
        else true
    end as is_partial_month,

    round(t.avg_traffic_volume, 2) as avg_traffic_volume,
    round(t.avg_speed_kmph, 2) as avg_speed_kmph,
    round(t.avg_travel_time_index, 3) as avg_travel_time_index,
    round(t.estimated_extra_travel_time_pct, 2) as estimated_extra_travel_time_pct,
    round(t.tti_ceiling_hit_rate_pct, 2) as tti_ceiling_hit_rate_pct,
    round(t.avg_congestion_level, 2) as avg_congestion_level,
    round(t.avg_incident_reports, 2) as avg_incident_reports,

    w.weather_days,
    w.rainy_days,
    round(w.rainy_day_pct, 2) as rainy_day_pct,
    round(w.avg_daily_precipitation_mm, 2) as avg_daily_precipitation_mm,
    round(w.total_precipitation_mm, 2) as total_precipitation_mm,
    round(w.avg_temperature_c, 2) as avg_temperature_c,
    round(w.avg_relative_humidity_pct, 2) as avg_relative_humidity_pct,
    round(w.avg_wind_speed, 2) as avg_wind_speed

from traffic_monthly t

left join weather_monthly w
    on t.month_start = w.month_start