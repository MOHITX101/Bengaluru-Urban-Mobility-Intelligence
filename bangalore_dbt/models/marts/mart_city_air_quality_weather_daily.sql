{{ config(materialized = 'table') }}

with station_days as (

    select *
    from {{ ref('mart_air_quality_weather_daily') }}
    where weather_match_status = 'MATCHED'

),

daily_aggregated as (

    select
        observation_date_ist,
        observation_year,
        observation_month_number,
        observation_month_name,
        observation_day_name,
        is_weekend,

        weather_date,
        temperature_2m_c,
        relative_humidity_2m_pct,
        precipitation_mm,
        wind_speed_2m,
        rain_status,
        precipitation_band,

        count(distinct station_id) as reporting_stations,

        count_if(is_pm25_analysis_eligible)
            as stations_with_valid_pm25,

        count_if(is_pm10_analysis_eligible)
            as stations_with_valid_pm10,

        count_if(is_no2_analysis_eligible)
            as stations_with_valid_no2,

        round(
            avg(
                case
                    when is_pm25_analysis_eligible
                        then daily_avg_pm25_ug_m3
                end
            ),
            2
        ) as city_avg_pm25_ug_m3,

        round(
            avg(
                case
                    when is_pm10_analysis_eligible
                        then daily_avg_pm10_ug_m3
                end
            ),
            2
        ) as city_avg_pm10_ug_m3,

        round(
            avg(
                case
                    when is_no2_analysis_eligible
                        then daily_avg_no2_ug_m3
                end
            ),
            2
        ) as city_avg_no2_ug_m3,

        round(
            max(
                case
                    when is_pm25_analysis_eligible
                        then daily_avg_pm25_ug_m3
                end
            ),
            2
        ) as highest_station_daily_pm25_ug_m3,

        count_if(
            is_pm25_analysis_eligible
            and exceeds_pm25_24h_standard
        ) as pm25_exceeding_stations,

        count_if(
            is_pm10_analysis_eligible
            and exceeds_pm10_24h_standard
        ) as pm10_exceeding_stations,

        count_if(
            is_no2_analysis_eligible
            and exceeds_no2_24h_standard
        ) as no2_exceeding_stations

    from station_days

    group by
        observation_date_ist,
        observation_year,
        observation_month_number,
        observation_month_name,
        observation_day_name,
        is_weekend,
        weather_date,
        temperature_2m_c,
        relative_humidity_2m_pct,
        precipitation_mm,
        wind_speed_2m,
        rain_status,
        precipitation_band

),

final as (

    select
        md5(to_varchar(observation_date_ist)) as city_weather_date_id,

        observation_date_ist,
        observation_year,
        observation_month_number,
        observation_month_name,
        observation_day_name,
        is_weekend,

        temperature_2m_c,
        relative_humidity_2m_pct,
        precipitation_mm,
        wind_speed_2m,
        rain_status,
        precipitation_band,

        reporting_stations,
        stations_with_valid_pm25,
        stations_with_valid_pm10,
        stations_with_valid_no2,

        city_avg_pm25_ug_m3,
        city_avg_pm10_ug_m3,
        city_avg_no2_ug_m3,
        highest_station_daily_pm25_ug_m3,

        pm25_exceeding_stations,
        pm10_exceeding_stations,
        no2_exceeding_stations,

        round(
            100.0 * pm25_exceeding_stations
            / nullif(stations_with_valid_pm25, 0),
            2
        ) as pm25_station_exceedance_pct,

        round(
            100.0 * pm10_exceeding_stations
            / nullif(stations_with_valid_pm10, 0),
            2
        ) as pm10_station_exceedance_pct,

        round(
            100.0 * no2_exceeding_stations
            / nullif(stations_with_valid_no2, 0),
            2
        ) as no2_station_exceedance_pct,

        case
            when stations_with_valid_pm25 >= 4 then true
            else false
        end as is_high_coverage_pm25_date,

        case
            when stations_with_valid_pm10 >= 4 then true
            else false
        end as is_high_coverage_pm10_date,

        case
            when stations_with_valid_no2 >= 4 then true
            else false
        end as is_high_coverage_no2_date

    from daily_aggregated

)

select *
from final