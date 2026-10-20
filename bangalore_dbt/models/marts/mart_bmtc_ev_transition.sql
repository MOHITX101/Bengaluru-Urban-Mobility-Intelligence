{{ config(
    materialized = 'view',
    schema = 'MARTS'
) }}

select
    fiscal_year,
    fiscal_year_start,
    fiscal_year_start_date,
    fiscal_year_end_date,

    vehicles_held,
    new_vehicles_added,
    explicitly_labelled_evs_added,
    other_vehicles_added,
    explicitly_labelled_ev_share_pct,
    vehicles_scrapped,
    fleet_utilization_pct,

    sum(
        coalesce(explicitly_labelled_evs_added, 0)
    ) over (
        order by fiscal_year_start
        rows between unbounded preceding and current row
    ) as cumulative_explicit_ev_additions,

    sum(
        coalesce(new_vehicles_added, 0)
    ) over (
        order by fiscal_year_start
        rows between unbounded preceding and current row
    ) as cumulative_new_vehicle_additions,

    round(
        (
            sum(
                coalesce(explicitly_labelled_evs_added, 0)
            ) over (
                order by fiscal_year_start
                rows between unbounded preceding and current row
            )
            /
            nullif(
                sum(
                    coalesce(new_vehicles_added, 0)
                ) over (
                    order by fiscal_year_start
                    rows between unbounded preceding and current row
                ),
                0
            )
        ) * 100,
        2
    ) as cumulative_explicit_ev_share_of_additions_pct

from {{ ref('mart_bmtc_yearly_performance') }}

where fiscal_year_start >= 2021