with traffic as (

    select *
    from {{ ref('mart_traffic_weather') }}

)

select
    'Traffic volume vs speed' as metric_pair,
    round(corr(traffic_volume, average_speed_kmph), 4) as correlation
from traffic

union all

select
    'Traffic volume vs TTI',
    round(corr(traffic_volume, travel_time_index), 4)
from traffic

union all

select
    'Speed vs TTI',
    round(corr(average_speed_kmph, travel_time_index), 4)
from traffic

union all

select
    'Congestion vs TTI',
    round(corr(congestion_level, travel_time_index), 4)
from traffic

union all

select
    'Congestion vs speed',
    round(corr(congestion_level, average_speed_kmph), 4)
from traffic

union all

select
    'Capacity utilization vs congestion',
    round(corr(road_capacity_utilization, congestion_level), 4)
from traffic

order by metric_pair