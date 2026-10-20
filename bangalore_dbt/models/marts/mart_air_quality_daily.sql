{{ config(
    materialized = 'table'
) }}

with daily as (

    select
        station_id,
        station_name,
        station_short_name,
        observation_date_ist,

        count(*) as source_observation_count,

        count(pm25_ug_m3) as valid_pm25_readings,
        count(pm10_ug_m3) as valid_pm10_readings,
        count(no2_ug_m3) as valid_no2_readings,

        avg(pm25_ug_m3) as daily_avg_pm25_ug_m3,
        avg(pm10_ug_m3) as daily_avg_pm10_ug_m3,
        avg(no2_ug_m3) as daily_avg_no2_ug_m3,
        avg(so2_ug_m3) as daily_avg_so2_ug_m3,
        avg(co_mg_m3) as daily_avg_co_mg_m3,
        avg(ozone_ug_m3) as daily_avg_ozone_ug_m3,

        max(pm25_ug_m3) as daily_max_pm25_ug_m3,
        max(pm10_ug_m3) as daily_max_pm10_ug_m3,
        max(no2_ug_m3) as daily_max_no2_ug_m3

    from {{ ref('stg_air_quality') }}

    group by
        station_id,
        station_name,
        station_short_name,
        observation_date_ist

),

final as (

    select
        md5(
            concat_ws(
                '|',
                upper(station_id),
                to_varchar(observation_date_ist)
            )
        ) as station_day_id,

        station_id,
        station_name,
        station_short_name,
        observation_date_ist,

        year(observation_date_ist) as observation_year,
        month(observation_date_ist) as observation_month_number,
        monthname(observation_date_ist) as observation_month_name,
        dayname(observation_date_ist) as observation_day_name,

        case
            when dayofweekiso(observation_date_ist) in (6, 7)
                then true
            else false
        end as is_weekend,

        source_observation_count,

        round(
            100.0 * source_observation_count / 96,
            2
        ) as expected_day_coverage_pct,

        valid_pm25_readings,
        valid_pm10_readings,
        valid_no2_readings,

        round(
            100.0 * valid_pm25_readings / 96,
            2
        ) as pm25_data_completeness_pct,

        round(
            100.0 * valid_pm10_readings / 96,
            2
        ) as pm10_data_completeness_pct,

        round(
            100.0 * valid_no2_readings / 96,
            2
        ) as no2_data_completeness_pct,

        round(daily_avg_pm25_ug_m3, 2) as daily_avg_pm25_ug_m3,
        round(daily_avg_pm10_ug_m3, 2) as daily_avg_pm10_ug_m3,
        round(daily_avg_no2_ug_m3, 2) as daily_avg_no2_ug_m3,
        round(daily_avg_so2_ug_m3, 2) as daily_avg_so2_ug_m3,
        round(daily_avg_co_mg_m3, 3) as daily_avg_co_mg_m3,
        round(daily_avg_ozone_ug_m3, 2) as daily_avg_ozone_ug_m3,

        round(daily_max_pm25_ug_m3, 2) as daily_max_pm25_ug_m3,
        round(daily_max_pm10_ug_m3, 2) as daily_max_pm10_ug_m3,
        round(daily_max_no2_ug_m3, 2) as daily_max_no2_ug_m3,

        case
            when valid_pm25_readings >= 72
                then daily_avg_pm25_ug_m3 > 60
            else null
        end as exceeds_pm25_24h_standard,

        case
            when valid_pm10_readings >= 72
                then daily_avg_pm10_ug_m3 > 100
            else null
        end as exceeds_pm10_24h_standard,

        case
            when valid_no2_readings >= 72
                then daily_avg_no2_ug_m3 > 80
            else null
        end as exceeds_no2_24h_standard,

        case
            when valid_pm25_readings >= 72
                 and daily_avg_pm25_ug_m3 > 60 then true
            when valid_pm10_readings >= 72
                 and daily_avg_pm10_ug_m3 > 100 then true
            when valid_no2_readings >= 72
                 and daily_avg_no2_ug_m3 > 80 then true
            when valid_pm25_readings >= 72
              or valid_pm10_readings >= 72
              or valid_no2_readings >= 72 then false
            else null
        end as exceeds_any_selected_24h_standard,

        case
            when source_observation_count >= 96 then 'COMPLETE'
            when source_observation_count >= 72 then 'SUFFICIENT'
            else 'INSUFFICIENT'
        end as day_coverage_status

    from daily

)

select *
from final