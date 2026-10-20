{{ config(materialized = 'table') }}

with air_quality as (

    select
        station_day_id,
        station_id,
        station_name,
        station_short_name,
        observation_date_ist,
        observation_year,
        observation_month_number,
        observation_month_name,
        observation_day_name,
        is_weekend,

        source_observation_count,
        expected_day_coverage_pct,
        day_coverage_status,

        valid_pm25_readings,
        valid_pm10_readings,
        valid_no2_readings,

        pm25_data_completeness_pct,
        pm10_data_completeness_pct,
        no2_data_completeness_pct,

        daily_avg_pm25_ug_m3,
        daily_avg_pm10_ug_m3,
        daily_avg_no2_ug_m3,
        daily_avg_so2_ug_m3,
        daily_avg_co_mg_m3,
        daily_avg_ozone_ug_m3,

        daily_max_pm25_ug_m3,
        daily_max_pm10_ug_m3,
        daily_max_no2_ug_m3,

        exceeds_pm25_24h_standard,
        exceeds_pm10_24h_standard,
        exceeds_no2_24h_standard,
        exceeds_any_selected_24h_standard

    from {{ ref('mart_air_quality_daily') }}

),

weather as (

    select
        weather_record_id,
        weather_date,
        temperature_2m_c,
        relative_humidity_2m_pct,
        precipitation_mm,
        wind_speed_2m

    from {{ ref('stg_daily_weather') }}

),

joined as (

    select
        aq.station_day_id,
        aq.station_id,
        aq.station_name,
        aq.station_short_name,

        aq.observation_date_ist,
        aq.observation_year,
        aq.observation_month_number,
        aq.observation_month_name,
        aq.observation_day_name,
        aq.is_weekend,

        aq.source_observation_count,
        aq.expected_day_coverage_pct,
        aq.day_coverage_status,

        aq.valid_pm25_readings,
        aq.valid_pm10_readings,
        aq.valid_no2_readings,

        aq.pm25_data_completeness_pct,
        aq.pm10_data_completeness_pct,
        aq.no2_data_completeness_pct,

        aq.daily_avg_pm25_ug_m3,
        aq.daily_avg_pm10_ug_m3,
        aq.daily_avg_no2_ug_m3,
        aq.daily_avg_so2_ug_m3,
        aq.daily_avg_co_mg_m3,
        aq.daily_avg_ozone_ug_m3,

        aq.daily_max_pm25_ug_m3,
        aq.daily_max_pm10_ug_m3,
        aq.daily_max_no2_ug_m3,

        aq.exceeds_pm25_24h_standard,
        aq.exceeds_pm10_24h_standard,
        aq.exceeds_no2_24h_standard,
        aq.exceeds_any_selected_24h_standard,

        weather.weather_record_id,
        weather.weather_date,
        weather.temperature_2m_c,
        weather.relative_humidity_2m_pct,
        weather.precipitation_mm,
        weather.wind_speed_2m,

        case
            when weather.weather_date is not null then 'MATCHED'
            else 'UNMATCHED'
        end as weather_match_status,

        case
            when weather.weather_date is null then 'Weather unavailable'
            when weather.precipitation_mm > 0 then 'Rainy'
            else 'No rain'
        end as rain_status,

        case
            when weather.weather_date is null then 'Weather unavailable'
            when weather.precipitation_mm = 0 then 'No rain'
            when weather.precipitation_mm <= 2.5 then 'More than 0 to 2.5 mm'
            when weather.precipitation_mm <= 7.5 then 'More than 2.5 to 7.5 mm'
            else 'More than 7.5 mm'
        end as precipitation_band,

        case
            when weather.weather_date is not null
             and aq.day_coverage_status in ('COMPLETE', 'SUFFICIENT')
             and aq.daily_avg_pm25_ug_m3 is not null
                then true
            else false
        end as is_pm25_analysis_eligible,

        case
            when weather.weather_date is not null
             and aq.day_coverage_status in ('COMPLETE', 'SUFFICIENT')
             and aq.daily_avg_pm10_ug_m3 is not null
                then true
            else false
        end as is_pm10_analysis_eligible,

        case
            when weather.weather_date is not null
             and aq.day_coverage_status in ('COMPLETE', 'SUFFICIENT')
             and aq.daily_avg_no2_ug_m3 is not null
                then true
            else false
        end as is_no2_analysis_eligible

    from air_quality as aq

    left join weather
        on aq.observation_date_ist = weather.weather_date

)

select *
from joined