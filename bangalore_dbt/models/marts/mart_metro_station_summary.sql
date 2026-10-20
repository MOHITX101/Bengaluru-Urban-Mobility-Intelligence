{{ config(
    materialized = 'table'
) }}

with metro_hourly as (

    select *
    from {{ ref('stg_metro_station_hourly_september') }}

),

station_daily as (

    select
        business_date,
        station_code,
        station_name,
        is_weekend,
        sum(passenger_count) as daily_passenger_activity

    from metro_hourly

    group by
        business_date,
        station_code,
        station_name,
        is_weekend

),

station_summary as (

    select
        station_code,
        station_name,

        count(*) as observed_days,
        sum(daily_passenger_activity) as total_passenger_activity,
        avg(daily_passenger_activity) as avg_daily_passenger_activity,

        avg(
            case
                when is_weekend = false
                    then daily_passenger_activity
            end
        ) as avg_weekday_passenger_activity,

        avg(
            case
                when is_weekend = true
                    then daily_passenger_activity
            end
        ) as avg_weekend_passenger_activity,

        min(business_date) as first_observation_date,
        max(business_date) as last_observation_date

    from station_daily

    group by
        station_code,
        station_name

),

station_hour_summary as (

    select
        station_code,
        station_name,
        observation_hour,

        sum(passenger_count) as hour_total_passenger_activity,
        avg(passenger_count) as hour_avg_passenger_activity

    from metro_hourly

    group by
        station_code,
        station_name,
        observation_hour

),

peak_hour as (

    select
        station_code,
        station_name,
        observation_hour as peak_activity_hour,
        hour_total_passenger_activity as peak_hour_total_activity,
        hour_avg_passenger_activity as peak_hour_avg_activity

    from station_hour_summary

    qualify row_number() over (
        partition by station_code
        order by
            hour_total_passenger_activity desc,
            observation_hour
    ) = 1

),

combined as (

    select
        s.*,
        p.peak_activity_hour,
        p.peak_hour_total_activity,
        p.peak_hour_avg_activity,

        100.0 * p.peak_hour_total_activity
        / nullif(s.total_passenger_activity, 0) as peak_hour_share_pct,

        100.0 * (
            s.avg_weekend_passenger_activity
            - s.avg_weekday_passenger_activity
        ) / nullif(
            s.avg_weekday_passenger_activity,
            0
        ) as weekend_change_pct

    from station_summary s

    left join peak_hour p
        on s.station_code = p.station_code

),

ranked as (

    select
        *,

        dense_rank() over (
            order by total_passenger_activity desc
        ) as passenger_activity_rank

    from combined

)

select
    station_code,
    station_name,
    observed_days,

    total_passenger_activity,
    round(avg_daily_passenger_activity, 2) as avg_daily_passenger_activity,
    round(avg_weekday_passenger_activity, 2) as avg_weekday_passenger_activity,
    round(avg_weekend_passenger_activity, 2) as avg_weekend_passenger_activity,
    round(weekend_change_pct, 2) as weekend_change_pct,

    peak_activity_hour,
    peak_hour_total_activity,
    round(peak_hour_avg_activity, 2) as peak_hour_avg_activity,
    round(peak_hour_share_pct, 2) as peak_hour_share_pct,

    first_observation_date,
    last_observation_date,
    passenger_activity_rank

from ranked