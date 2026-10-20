{{ config(
    materialized = 'table',
    schema = 'MARTS'
) }}

with station_summary as (

    select
        traffic_zone,
        traffic_police_station,

        count(distinct accident_year) as years_observed,

        sum(total_accident_cases) as five_year_accident_cases,
        sum(fatal_accidents) as five_year_fatal_accidents,
        sum(persons_killed) as five_year_persons_killed,
        sum(persons_injured) as five_year_persons_injured,
        sum(total_casualties) as five_year_total_casualties,

        avg(total_accident_cases) as avg_annual_accident_cases,
        avg(persons_killed) as avg_annual_persons_killed,

        max(
            case
                when accident_year = 2018
                    then total_accident_cases
            end
        ) as accident_cases_2018,

        max(
            case
                when accident_year = 2022
                    then total_accident_cases
            end
        ) as accident_cases_2022,

        max(
            case
                when accident_year = 2018
                    then persons_killed
            end
        ) as persons_killed_2018,

        max(
            case
                when accident_year = 2022
                    then persons_killed
            end
        ) as persons_killed_2022

    from {{ ref('mart_road_safety_station_yearly') }}

    group by
        traffic_zone,
        traffic_police_station

),

calculated as (

    select
        *,

        100.0 * five_year_fatal_accidents
            / nullif(five_year_accident_cases, 0)
            as five_year_fatal_accident_share_pct,

        100.0 * five_year_persons_killed
            / nullif(five_year_accident_cases, 0)
            as persons_killed_per_100_cases,

        100.0 * (
            accident_cases_2022 - accident_cases_2018
        ) / nullif(accident_cases_2018, 0)
            as case_change_2018_to_2022_pct,

        100.0 * (
            persons_killed_2022 - persons_killed_2018
        ) / nullif(persons_killed_2018, 0)
            as killed_change_2018_to_2022_pct

    from station_summary

),

ranked as (

    select
        *,

        dense_rank() over (
            order by five_year_accident_cases desc
        ) as accident_case_rank,

        dense_rank() over (
            order by five_year_persons_killed desc
        ) as persons_killed_rank,

        dense_rank() over (
            order by persons_killed_per_100_cases desc
        ) as case_severity_rank

    from calculated

)

select
    traffic_zone,
    traffic_police_station,
    years_observed,

    five_year_accident_cases,
    five_year_fatal_accidents,
    five_year_persons_killed,
    five_year_persons_injured,
    five_year_total_casualties,

    round(avg_annual_accident_cases, 2) as avg_annual_accident_cases,
    round(avg_annual_persons_killed, 2) as avg_annual_persons_killed,

    round(
        five_year_fatal_accident_share_pct,
        2
    ) as five_year_fatal_accident_share_pct,

    round(
        persons_killed_per_100_cases,
        2
    ) as persons_killed_per_100_cases,

    accident_cases_2018,
    accident_cases_2022,
    round(
        case_change_2018_to_2022_pct,
        2
    ) as case_change_2018_to_2022_pct,

    persons_killed_2018,
    persons_killed_2022,
    round(
        killed_change_2018_to_2022_pct,
        2
    ) as killed_change_2018_to_2022_pct,

    accident_case_rank,
    persons_killed_rank,
    case_severity_rank

from ranked