{{ config(
    materialized = 'table'
) }}

with daily_air_quality as (

    select *
    from {{ ref('mart_air_quality_daily') }}

),

station_summary as (

    select
        station_id,
        station_name,
        station_short_name,

        count(*) as total_station_days,

        count_if(
            day_coverage_status = 'COMPLETE'
        ) as complete_station_days,

        count_if(
            day_coverage_status = 'SUFFICIENT'
        ) as sufficient_station_days,

        count_if(
            day_coverage_status = 'INSUFFICIENT'
        ) as insufficient_station_days,

        count(exceeds_pm25_24h_standard) as valid_pm25_days,

        count_if(
            exceeds_pm25_24h_standard = true
        ) as pm25_exceedance_days,

        100.0 * count_if(
            exceeds_pm25_24h_standard = true
        ) / nullif(
            count(exceeds_pm25_24h_standard),
            0
        ) as pm25_exceedance_rate_pct,

        avg(
            case
                when valid_pm25_readings >= 72
                    then daily_avg_pm25_ug_m3
            end
        ) as avg_valid_daily_pm25_ug_m3,

        median(
            case
                when valid_pm25_readings >= 72
                    then daily_avg_pm25_ug_m3
            end
        ) as median_valid_daily_pm25_ug_m3,

        max(
            case
                when valid_pm25_readings >= 72
                    then daily_avg_pm25_ug_m3
            end
        ) as maximum_valid_daily_pm25_ug_m3,

        count(exceeds_pm10_24h_standard) as valid_pm10_days,

        count_if(
            exceeds_pm10_24h_standard = true
        ) as pm10_exceedance_days,

        100.0 * count_if(
            exceeds_pm10_24h_standard = true
        ) / nullif(
            count(exceeds_pm10_24h_standard),
            0
        ) as pm10_exceedance_rate_pct,

        avg(
            case
                when valid_pm10_readings >= 72
                    then daily_avg_pm10_ug_m3
            end
        ) as avg_valid_daily_pm10_ug_m3,

        count(exceeds_no2_24h_standard) as valid_no2_days,

        count_if(
            exceeds_no2_24h_standard = true
        ) as no2_exceedance_days,

        100.0 * count_if(
            exceeds_no2_24h_standard = true
        ) / nullif(
            count(exceeds_no2_24h_standard),
            0
        ) as no2_exceedance_rate_pct,

        avg(
            case
                when valid_no2_readings >= 72
                    then daily_avg_no2_ug_m3
            end
        ) as avg_valid_daily_no2_ug_m3,

        min(observation_date_ist) as first_observation_date,
        max(observation_date_ist) as last_observation_date

    from daily_air_quality

    group by
        station_id,
        station_name,
        station_short_name

),

ranked as (

    select
        *,

        case
            when valid_pm25_days > 0 then
                dense_rank() over (
                    order by
                        case
                            when valid_pm25_days > 0
                                then pm25_exceedance_rate_pct
                        end desc nulls last
                )
            else null
        end as pm25_exceedance_rank,

        case
            when valid_pm25_days > 0 then
                dense_rank() over (
                    order by
                        case
                            when valid_pm25_days > 0
                                then avg_valid_daily_pm25_ug_m3
                        end desc nulls last
                )
            else null
        end as avg_pm25_rank,

        case
            when valid_pm10_days > 0 then
                dense_rank() over (
                    order by
                        case
                            when valid_pm10_days > 0
                                then pm10_exceedance_rate_pct
                        end desc nulls last
                )
            else null
        end as pm10_exceedance_rank,

        case
            when valid_no2_days > 0 then
                dense_rank() over (
                    order by
                        case
                            when valid_no2_days > 0
                                then no2_exceedance_rate_pct
                        end desc nulls last
                )
            else null
        end as no2_exceedance_rank

    from station_summary

)

select
    station_id,
    station_name,
    station_short_name,

    total_station_days,
    complete_station_days,
    sufficient_station_days,
    insufficient_station_days,

    valid_pm25_days,
    pm25_exceedance_days,
    round(pm25_exceedance_rate_pct, 2) as pm25_exceedance_rate_pct,
    round(avg_valid_daily_pm25_ug_m3, 2) as avg_valid_daily_pm25_ug_m3,
    round(median_valid_daily_pm25_ug_m3, 2) as median_valid_daily_pm25_ug_m3,
    round(maximum_valid_daily_pm25_ug_m3, 2) as maximum_valid_daily_pm25_ug_m3,

    valid_pm10_days,
    pm10_exceedance_days,
    round(pm10_exceedance_rate_pct, 2) as pm10_exceedance_rate_pct,
    round(avg_valid_daily_pm10_ug_m3, 2) as avg_valid_daily_pm10_ug_m3,

    valid_no2_days,
    no2_exceedance_days,
    round(no2_exceedance_rate_pct, 2) as no2_exceedance_rate_pct,
    round(avg_valid_daily_no2_ug_m3, 2) as avg_valid_daily_no2_ug_m3,

    first_observation_date,
    last_observation_date,

    pm25_exceedance_rank,
    avg_pm25_rank,
    pm10_exceedance_rank,
    no2_exceedance_rank

from ranked