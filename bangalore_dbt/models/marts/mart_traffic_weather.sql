{{ config(
    materialized = 'table'
) }}

with traffic as (

    select *
    from {{ ref('stg_traffic') }}

),

weather as (

    select *
    from {{ ref('stg_daily_weather') }}

),

joined as (

    select
        t.traffic_record_id,
        t.traffic_date,

        year(t.traffic_date)                    as traffic_year,
        quarter(t.traffic_date)                 as traffic_quarter,
        month(t.traffic_date)                   as traffic_month_number,
        monthname(t.traffic_date)               as traffic_month_name,
        dayname(t.traffic_date)                 as traffic_day_name,

        case
            when dayofweekiso(t.traffic_date) in (6, 7) then true
            else false
        end                                     as is_weekend,

        t.area_name,
        t.road_name,
        t.traffic_volume,
        t.average_speed_kmph,
        t.travel_time_index,
        t.congestion_level,
        t.road_capacity_utilization,
        t.incident_reports,
        t.environmental_impact,
        t.public_transport_usage,
        t.traffic_signal_compliance,
        t.parking_usage,
        t.pedestrian_cyclist_count,
        t.weather_condition                    as traffic_weather_label,
        t.roadwork_activity,

        w.weather_date,
        w.temperature_2m_c,
        w.relative_humidity_2m_pct,
        w.precipitation_mm,
        w.wind_speed_2m,

        case
            when w.weather_date is null then null
            when w.precipitation_mm > 0 then true
            else false
        end                                     as has_precipitation,

        case
            when w.weather_date is null then 'UNMATCHED'
            else 'MATCHED'
        end                                     as weather_match_status,

        t.source_filename                       as traffic_source_filename,
        w.source_filename                       as weather_source_filename,
        t.loaded_at                             as traffic_loaded_at,
        w.loaded_at                             as weather_loaded_at

    from traffic t

    left join weather w
        on t.traffic_date = w.weather_date

)

select *
from joined