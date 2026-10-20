{{ config(
    materialized = 'table',
    schema = 'MARTS'
) }}

with combined_accidents as (

    select
        station_year_accident_id,
        traffic_zone,
        traffic_police_station,
        accident_year,
        fatal_accidents,
        persons_killed,
        non_fatal_accidents,
        persons_injured,
        total_accident_cases,
        source_filename,
        loaded_at

    from {{ ref('stg_accidents_2018_2020') }}

    union all

    select
        station_year_accident_id,
        traffic_zone,
        traffic_police_station,
        accident_year,
        fatal_accidents,
        persons_killed,
        non_fatal_accidents,
        persons_injured,
        total_accident_cases,
        source_filename,
        loaded_at

    from {{ ref('stg_accidents_2021_2022') }}

),

calculated as (

    select
        *,

        persons_killed
            + persons_injured as total_casualties,

        100.0 * fatal_accidents
            / nullif(total_accident_cases, 0)
            as fatal_accident_share_pct,

        100.0 * persons_killed
            / nullif(total_accident_cases, 0)
            as persons_killed_per_100_cases,

        100.0 * persons_injured
            / nullif(total_accident_cases, 0)
            as persons_injured_per_100_cases,

        100.0 * (
            persons_killed + persons_injured
        ) / nullif(total_accident_cases, 0)
            as casualties_per_100_cases

    from combined_accidents

),

ranked as (

    select
        *,

        dense_rank() over (
            partition by accident_year
            order by total_accident_cases desc
        ) as accident_case_rank_in_year,

        dense_rank() over (
            partition by accident_year
            order by persons_killed desc
        ) as fatalities_rank_in_year,

        dense_rank() over (
            partition by accident_year
            order by fatal_accident_share_pct desc
        ) as severity_rank_in_year

    from calculated

)

select
    station_year_accident_id,
    traffic_zone,
    traffic_police_station,
    accident_year,

    fatal_accidents,
    persons_killed,
    non_fatal_accidents,
    persons_injured,
    total_accident_cases,
    total_casualties,

    round(
        fatal_accident_share_pct,
        2
    ) as fatal_accident_share_pct,

    round(
        persons_killed_per_100_cases,
        2
    ) as persons_killed_per_100_cases,

    round(
        persons_injured_per_100_cases,
        2
    ) as persons_injured_per_100_cases,

    round(
        casualties_per_100_cases,
        2
    ) as casualties_per_100_cases,

    accident_case_rank_in_year,
    fatalities_rank_in_year,
    severity_rank_in_year,

    source_filename,
    loaded_at

from ranked