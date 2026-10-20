select
    area_name,
    count(*) as observations,
    count(distinct travel_time_index) as distinct_tti_values,

    round(min(travel_time_index), 3) as minimum_tti,
    round(avg(travel_time_index), 3) as average_tti,
    round(max(travel_time_index), 3) as maximum_tti,

    count_if(travel_time_index = 1.5) as observations_at_1_5,

    round(
        100.0 * count_if(travel_time_index = 1.5)
        / nullif(count(*), 0),
        2
    ) as percentage_at_1_5,

    count_if(travel_time_index > 1.5) as observations_above_1_5

from {{ ref('mart_traffic_weather') }}

group by area_name

order by percentage_at_1_5 desc