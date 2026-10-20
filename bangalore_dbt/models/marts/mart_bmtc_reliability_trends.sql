{{ config(
    materialized = 'view',
    schema = 'MARTS'
) }}

with base as (

    select
        fiscal_year,
        fiscal_year_start,
        fiscal_year_start_date,
        fiscal_year_end_date,

        total_service_km_lakh,
        fleet_utilization_pct,
        cancellation_pct,

        breakdowns,
        breakdowns_per_10000_km,

        bmtc_accidents,
        accidents_per_lakh_km

    from {{ ref('mart_bmtc_yearly_performance') }}

    where fiscal_year_start >= 2017

),

with_previous_year as (

    select
        *,

        lag(breakdowns) over (
            order by fiscal_year_start
        ) as previous_year_breakdowns,

        lag(bmtc_accidents) over (
            order by fiscal_year_start
        ) as previous_year_accidents

    from base

),

calculated as (

    select
        *,

        round(
            breakdowns
            / nullif(total_service_km_lakh * 10, 0),
            4
        ) as calculated_breakdowns_per_10000_km,

        round(
            breakdowns_per_10000_km
            -
            (
                breakdowns
                / nullif(total_service_km_lakh * 10, 0)
            ),
            4
        ) as breakdown_rate_difference,

        abs(
            breakdowns_per_10000_km
            -
            (
                breakdowns
                / nullif(total_service_km_lakh * 10, 0)
            )
        ) <= 0.005 as breakdown_rate_reconciles,

        round(
            (
                breakdowns
                - previous_year_breakdowns
            )
            / nullif(previous_year_breakdowns, 0)
            * 100,
            2
        ) as breakdowns_yoy_pct,

        round(
            breakdowns
            / nullif(previous_year_breakdowns, 0),
            2
        ) as breakdown_change_ratio,

        case
            when previous_year_breakdowns is null then null
            when breakdowns >= previous_year_breakdowns * 3 then true
            else false
        end as breakdown_increase_over_3x_flag,

        round(
            bmtc_accidents
            / nullif(total_service_km_lakh, 0),
            4
        ) as calculated_accidents_per_lakh_km,

        round(
            accidents_per_lakh_km
            -
            (
                bmtc_accidents
                / nullif(total_service_km_lakh, 0)
            ),
            4
        ) as accident_rate_difference,

        abs(
            accidents_per_lakh_km
            -
            (
                bmtc_accidents
                / nullif(total_service_km_lakh, 0)
            )
        ) <= 0.005 as accident_rate_reconciles,

        round(
            (
                bmtc_accidents
                - previous_year_accidents
            )
            / nullif(previous_year_accidents, 0)
            * 100,
            2
        ) as accidents_yoy_pct

    from with_previous_year

)

select *
from calculated