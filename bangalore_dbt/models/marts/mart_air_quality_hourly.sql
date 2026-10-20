{{ config(
    materialized = 'table'
) }}

with air_quality as (

    select *
    from {{ ref('stg_air_quality') }}

),

hourly as (

    select
        station_id,
        station_name,
        station_short_name,

        date_trunc(
            'hour',
            observed_at_ist
        ) as hour_start_ist,

        count(*) as source_observation_count,

        count(pm25_ug_m3) as valid_pm25_observations,
        count(pm10_ug_m3) as valid_pm10_observations,
        count(no2_ug_m3) as valid_no2_observations,

        avg(pm25_ug_m3) as avg_pm25_ug_m3,
        avg(pm10_ug_m3) as avg_pm10_ug_m3,
        avg(no_ug_m3) as avg_no_ug_m3,
        avg(no2_ug_m3) as avg_no2_ug_m3,
        avg(nox_ppb) as avg_nox_ppb,
        avg(nh3_ug_m3) as avg_nh3_ug_m3,
        avg(so2_ug_m3) as avg_so2_ug_m3,
        avg(co_mg_m3) as avg_co_mg_m3,
        avg(ozone_ug_m3) as avg_ozone_ug_m3,
        avg(benzene_ug_m3) as avg_benzene_ug_m3,
        avg(toluene_ug_m3) as avg_toluene_ug_m3,

        min(pm25_ug_m3) as minimum_pm25_ug_m3,
        max(pm25_ug_m3) as maximum_pm25_ug_m3,

        avg(station_temperature_c) as avg_station_temperature_c,
        avg(station_relative_humidity_pct) as avg_station_relative_humidity_pct,
        avg(station_wind_speed_m_s) as avg_station_wind_speed_m_s,
        avg(station_rainfall_mm) as avg_station_rainfall_mm

    from air_quality

    group by
        station_id,
        station_name,
        station_short_name,
        date_trunc('hour', observed_at_ist)

),

final as (

    select
        md5(
            concat_ws(
                '|',
                upper(station_id),
                to_varchar(hour_start_ist)
            )
        ) as station_hour_id,

        station_id,
        station_name,
        station_short_name,
        hour_start_ist,
        hour_start_ist::date as observation_date_ist,
        hour(hour_start_ist) as observation_hour_ist,
        dayname(hour_start_ist) as observation_day_name,

        case
            when dayofweekiso(hour_start_ist) in (6, 7) then true
            else false
        end as is_weekend,

        source_observation_count,

        round(
            100.0 * source_observation_count / 4,
            2
        ) as expected_hour_coverage_pct,

        valid_pm25_observations,
        valid_pm10_observations,
        valid_no2_observations,

        round(
            100.0 * valid_pm25_observations
            / nullif(source_observation_count, 0),
            2
        ) as pm25_data_completeness_pct,

        round(
            100.0 * valid_pm10_observations
            / nullif(source_observation_count, 0),
            2
        ) as pm10_data_completeness_pct,

        round(
            100.0 * valid_no2_observations
            / nullif(source_observation_count, 0),
            2
        ) as no2_data_completeness_pct,

        round(avg_pm25_ug_m3, 2) as avg_pm25_ug_m3,
        round(avg_pm10_ug_m3, 2) as avg_pm10_ug_m3,
        round(avg_no_ug_m3, 2) as avg_no_ug_m3,
        round(avg_no2_ug_m3, 2) as avg_no2_ug_m3,
        round(avg_nox_ppb, 2) as avg_nox_ppb,
        round(avg_nh3_ug_m3, 2) as avg_nh3_ug_m3,
        round(avg_so2_ug_m3, 2) as avg_so2_ug_m3,
        round(avg_co_mg_m3, 3) as avg_co_mg_m3,
        round(avg_ozone_ug_m3, 2) as avg_ozone_ug_m3,
        round(avg_benzene_ug_m3, 2) as avg_benzene_ug_m3,
        round(avg_toluene_ug_m3, 2) as avg_toluene_ug_m3,

        round(minimum_pm25_ug_m3, 2) as minimum_pm25_ug_m3,
        round(maximum_pm25_ug_m3, 2) as maximum_pm25_ug_m3,

        round(avg_station_temperature_c, 2) as avg_station_temperature_c,
        round(avg_station_relative_humidity_pct, 2) as avg_station_relative_humidity_pct,
        round(avg_station_wind_speed_m_s, 2) as avg_station_wind_speed_m_s,
        round(avg_station_rainfall_mm, 2) as avg_station_rainfall_mm

    from hourly

)

select *
from final