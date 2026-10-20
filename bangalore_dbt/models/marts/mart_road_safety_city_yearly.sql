{{ config(
    materialized = 'table',
    schema = 'MARTS'
) }}

with yearly_totals as (

    select
        accident_year,

        sum(fatal_accidents) as fatal_accidents,
        sum(persons_killed) as persons_killed,
        sum(non_fatal_accidents) as non_fatal_accidents,
        sum(persons_injured) as persons_injured,
        sum(total_accident_cases) as total_accident_cases,
        sum(total_casualties) as total_casualties

    from {{ ref('mart_road_safety_station_yearly') }}

    group by accident_year

),

calculated as (

    select
        *,

        100.0 * fatal_accidents
            / nullif(total_accident_cases, 0)
            as fatal_accident_share_pct,

        100.0 * persons_killed
            / nullif(total_accident_cases, 0)
            as persons_killed_per_100_cases,

        100.0 * persons_injured
            / nullif(total_accident_cases, 0)
            as persons_injured_per_100_cases,

        100.0 * total_casualties
            / nullif(total_accident_cases, 0)
            as casualties_per_100_cases,

        lag(total_accident_cases) over (
            order by accident_year
        ) as previous_year_cases,

        lag(persons_killed) over (
            order by accident_year
        ) as previous_year_persons_killed,

        lag(persons_injured) over (
            order by accident_year
        ) as previous_year_persons_injured

    from yearly_totals

),

final as (

    select
        accident_year,
        fatal_accidents,
        persons_killed,
        non_fatal_accidents,
        persons_injured,
        total_accident_cases,
        total_casualties,

        round(fatal_accident_share_pct, 2)
            as fatal_accident_share_pct,

        round(persons_killed_per_100_cases, 2)
            as persons_killed_per_100_cases,

        round(persons_injured_per_100_cases, 2)
            as persons_injured_per_100_cases,

        round(casualties_per_100_cases, 2)
            as casualties_per_100_cases,

        round(
            100.0 * (
                total_accident_cases - previous_year_cases
            ) / nullif(previous_year_cases, 0),
            2
        ) as accident_cases_yoy_pct,

        round(
            100.0 * (
                persons_killed - previous_year_persons_killed
            ) / nullif(previous_year_persons_killed, 0),
            2
        ) as persons_killed_yoy_pct,

        round(
            100.0 * (
                persons_injured - previous_year_persons_injured
            ) / nullif(previous_year_persons_injured, 0),
            2
        ) as persons_injured_yoy_pct,

        round(
            100.0 * total_accident_cases
            / nullif(
                max(
                    case
                        when accident_year = 2019
                            then total_accident_cases
                    end
                ) over (),
                0
            ),
            2
        ) as cases_index_2019_equals_100

    from calculated

)

select *
from final