{{ config(
    materialized = 'table',
    schema = 'MARTS'
) }}

with metro_hours as (

    select
        business_date,
        observation_hour,
        is_weekend,
        network_passenger_activity

    from {{ ref('mart_metro_air_quality_hourly') }}

),

fixed_panel_air_quality as (

    select
        observation_date_ist,
        observation_hour_ist,

        count_if(
            avg_pm25_ug_m3 is not null
        ) as panel_stations_reporting,

        avg(
            case
                when avg_pm25_ug_m3 is not null
                    then avg_pm25_ug_m3
            end
        ) as fixed_panel_avg_pm25_ug_m3

    from {{ ref('mart_air_quality_hourly') }}

    where observation_date_ist
          between '2025-09-01'::date and '2025-09-30'::date

      and station_short_name in (
          'BTM Layout',
          'Peenya',
          'Jayanagar 5th Block',
          'Silk Board'
      )

    group by
        observation_date_ist,
        observation_hour_ist

),

complete_panel_hours as (

    select
        observation_date_ist,
        observation_hour_ist,
        fixed_panel_avg_pm25_ug_m3

    from fixed_panel_air_quality

    where panel_stations_reporting = 4

),

joined as (

    select
        m.business_date,
        m.observation_hour,
        m.is_weekend,
        m.network_passenger_activity,

        a.fixed_panel_avg_pm25_ug_m3,

        m.network_passenger_activity
            * a.fixed_panel_avg_pm25_ug_m3
            as fixed_panel_pm25_exposure_index

    from metro_hours m

    inner join complete_panel_hours a
        on m.business_date = a.observation_date_ist
       and m.observation_hour = a.observation_hour_ist

),

categorized as (

    select
        business_date,
        observation_hour,
        is_weekend,
        network_passenger_activity,
        fixed_panel_avg_pm25_ug_m3,
        fixed_panel_pm25_exposure_index,

        case
            when is_weekend = true then 'Weekend'

            when observation_hour between 7 and 10
                then 'Weekday morning peak'

            when observation_hour between 17 and 20
                then 'Weekday evening peak'

            else 'Weekday off-peak'
        end as commute_period

    from joined

),

period_summary as (

    select
        commute_period,

        count(*) as complete_panel_hours,
        count(distinct business_date) as observed_days,

        sum(
            network_passenger_activity
        ) as total_passenger_activity,

        avg(
            network_passenger_activity
        ) as avg_hourly_passenger_activity,

        avg(
            fixed_panel_avg_pm25_ug_m3
        ) as unweighted_fixed_panel_pm25_ug_m3,

        sum(
            fixed_panel_pm25_exposure_index
        ) / nullif(
            sum(network_passenger_activity),
            0
        ) as passenger_weighted_fixed_panel_pm25_ug_m3,

        avg(
            fixed_panel_pm25_exposure_index
        ) as avg_hourly_fixed_panel_exposure_index

    from categorized

    group by commute_period

),

ranked as (

    select
        *,

        dense_rank() over (
            order by
                avg_hourly_fixed_panel_exposure_index desc
        ) as fixed_panel_exposure_rank

    from period_summary

)

select
    commute_period,
    complete_panel_hours,
    observed_days,
    total_passenger_activity,

    round(
        avg_hourly_passenger_activity,
        2
    ) as avg_hourly_passenger_activity,

    round(
        unweighted_fixed_panel_pm25_ug_m3,
        2
    ) as unweighted_fixed_panel_pm25_ug_m3,

    round(
        passenger_weighted_fixed_panel_pm25_ug_m3,
        2
    ) as passenger_weighted_fixed_panel_pm25_ug_m3,

    round(
        avg_hourly_fixed_panel_exposure_index,
        2
    ) as avg_hourly_fixed_panel_exposure_index,

    fixed_panel_exposure_rank

from ranked