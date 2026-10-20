{{ config(
    materialized = 'table'
) }}

with metro as (

    select *
    from {{ ref('stg_metro_station_hourly_september') }}

),

network_day_hour as (

    select
        business_date,
        is_weekend,
        observation_hour,
        sum(passenger_count) as network_passenger_activity

    from metro

    group by
        business_date,
        is_weekend,
        observation_hour

),

hourly_summary as (

    select
        is_weekend,
        observation_hour,

        count(*) as observed_days,
        sum(network_passenger_activity) as total_passenger_activity,
        avg(network_passenger_activity) as avg_network_passenger_activity

    from network_day_hour

    group by
        is_weekend,
        observation_hour

),

final as (

    select
        case
            when is_weekend then 'Weekend'
            else 'Weekday'
        end as day_type,

        is_weekend,
        observation_hour,
        observed_days,
        total_passenger_activity,

        round(
            avg_network_passenger_activity,
            2
        ) as avg_network_passenger_activity,

        round(
            100.0 * total_passenger_activity
            / nullif(
                sum(total_passenger_activity) over (
                    partition by is_weekend
                ),
                0
            ),
            2
        ) as passenger_activity_share_pct,

        dense_rank() over (
            partition by is_weekend
            order by avg_network_passenger_activity desc
        ) as hourly_activity_rank

    from hourly_summary

)

select *
from final