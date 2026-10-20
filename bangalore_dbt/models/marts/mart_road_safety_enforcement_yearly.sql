{{ config(
    materialized = 'table',
    schema = 'MARTS'
) }}

with road_safety as (

    select *
    from {{ ref('mart_road_safety_city_yearly') }}

),

enforcement as (

    select *
    from {{ ref('mart_traffic_enforcement_yearly') }}

),

joined as (

    select
        s.accident_year,

        s.total_accident_cases,
        s.fatal_accidents,
        s.persons_killed,
        s.persons_injured,
        s.total_casualties,
        s.fatal_accident_share_pct,
        s.persons_killed_per_100_cases,
        s.accident_cases_yoy_pct,
        s.persons_killed_yoy_pct,

        e.reported_total_cases as enforcement_cases,
        e.reported_total_fine_inr,
        e.reported_total_fine_crore_inr,
        e.avg_fine_per_case_inr,
        e.automation_case_share_pct,
        e.total_cases_yoy_pct as enforcement_cases_yoy_pct,
        e.total_fine_yoy_pct

    from road_safety s

    inner join enforcement e
        on s.accident_year = e.enforcement_year

),

indexed as (

    select
        *,

        100.0 * total_accident_cases
            / nullif(
                max(
                    case
                        when accident_year = 2018
                            then total_accident_cases
                    end
                ) over (),
                0
            ) as accident_cases_index_2018,

        100.0 * persons_killed
            / nullif(
                max(
                    case
                        when accident_year = 2018
                            then persons_killed
                    end
                ) over (),
                0
            ) as persons_killed_index_2018,

        100.0 * enforcement_cases
            / nullif(
                max(
                    case
                        when accident_year = 2018
                            then enforcement_cases
                    end
                ) over (),
                0
            ) as enforcement_cases_index_2018

    from joined

)

select
    accident_year,

    total_accident_cases,
    fatal_accidents,
    persons_killed,
    persons_injured,
    total_casualties,
    fatal_accident_share_pct,
    persons_killed_per_100_cases,
    accident_cases_yoy_pct,
    persons_killed_yoy_pct,

    enforcement_cases,
    reported_total_fine_crore_inr,
    avg_fine_per_case_inr,
    automation_case_share_pct,
    enforcement_cases_yoy_pct,
    total_fine_yoy_pct,

    round(
        accident_cases_index_2018,
        2
    ) as accident_cases_index_2018,

    round(
        persons_killed_index_2018,
        2
    ) as persons_killed_index_2018,

    round(
        enforcement_cases_index_2018,
        2
    ) as enforcement_cases_index_2018

from indexed