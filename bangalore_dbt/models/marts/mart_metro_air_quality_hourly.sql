{{ config(
    materialized = 'table'
) }}

with metro_network_hour as (

    select
        business_date,
        observation_hour,
        is_weekend,

        count(distinct station_code) as metro_stations_reporting,
        sum(passenger_count) as network_passenger_activity

    from {{ ref('stg_metro_station_hourly_september') }}

    group by
        business_date,
        observation_hour,
        is_weekend

),

city_air_quality_hour as (

    select
        observation_date_ist,
        observation_hour_ist,

        count(distinct station_id) as aq_stations_reporting,

        count_if(
            avg_pm25_ug_m3 is not null
        ) as stations_with_pm25,

        count_if(
            avg_pm10_ug_m3 is not null
        ) as stations_with_pm10,

        count_if(
            avg_no2_ug_m3 is not null
        ) as stations_with_no2,

        avg(avg_pm25_ug_m3) as city_avg_pm25_ug_m3,
        avg(avg_pm10_ug_m3) as city_avg_pm10_ug_m3,
        avg(avg_no2_ug_m3) as city_avg_no2_ug_m3

    from {{ ref('mart_air_quality_hourly') }}

    group by
        observation_date_ist,
        observation_hour_ist

),

joined as (

    select
        m.business_date,
        m.observation_hour,
        m.is_weekend,
        m.metro_stations_reporting,
        m.network_passenger_activity,

        a.aq_stations_reporting,
        a.stations_with_pm25,
        a.stations_with_pm10,
        a.stations_with_no2,

        a.city_avg_pm25_ug_m3,
        a.city_avg_pm10_ug_m3,
        a.city_avg_no2_ug_m3

    from metro_network_hour m

    left join city_air_quality_hour a
        on m.business_date = a.observation_date_ist
       and m.observation_hour = a.observation_hour_ist

),

final as (

    select
        md5(
            concat_ws(
                '|',
                to_varchar(business_date),
                to_varchar(observation_hour)
            )
        ) as network_hour_id,

        business_date,
        observation_hour,

        dateadd(
            hour,
            observation_hour,
            business_date::timestamp_ntz
        ) as hour_start_ist,

        case
            when is_weekend then 'Weekend'
            else 'Weekday'
        end as day_type,

        is_weekend,
        metro_stations_reporting,
        network_passenger_activity,

        aq_stations_reporting,
        stations_with_pm25,
        stations_with_pm10,
        stations_with_no2,

        round(city_avg_pm25_ug_m3, 2) as city_avg_pm25_ug_m3,
        round(city_avg_pm10_ug_m3, 2) as city_avg_pm10_ug_m3,
        round(city_avg_no2_ug_m3, 2) as city_avg_no2_ug_m3,

        network_passenger_activity
            * city_avg_pm25_ug_m3 as passenger_pm25_exposure_index,

        network_passenger_activity
            * city_avg_pm10_ug_m3 as passenger_pm10_exposure_index,

        network_passenger_activity
            * city_avg_no2_ug_m3 as passenger_no2_exposure_index,

        case
            when aq_stations_reporting is null then 'UNMATCHED'
            else 'MATCHED'
        end as aq_match_status

    from joined

)

select *
from final