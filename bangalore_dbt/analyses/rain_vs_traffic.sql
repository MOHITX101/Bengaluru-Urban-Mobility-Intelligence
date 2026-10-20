with traffic_weather as (

    select *
    from {{ ref('mart_traffic_weather') }}

)

select
    case
        when has_precipitation = true then 'Rainy'
        when has_precipitation = false then 'No rain'
        else 'Unknown'
    end as weather_group,

    count(*)                                  as traffic_observations,
    count(distinct traffic_date)              as observed_days,

    round(avg(precipitation_mm), 2)           as avg_precipitation_mm,
    round(avg(traffic_volume), 2)             as avg_traffic_volume,
    round(avg(average_speed_kmph), 2)         as avg_speed_kmph,
    round(avg(travel_time_index), 3)          as avg_travel_time_index,
    round(avg(congestion_level), 2)           as avg_congestion_level,
    round(avg(incident_reports), 2)           as avg_incident_reports

from traffic_weather

group by 1

order by
    case weather_group
        when 'Rainy' then 1
        when 'No rain' then 2
        else 3
    end