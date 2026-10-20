{{ config(
    materialized = 'table',
    schema = 'MARTS'
) }}

with pivoted as (

    select
        fiscal_year,
        fiscal_year_start,
        fiscal_year_end,

        max(case
            when metric_key = 'lt_ev_charging_stations'
            then metric_value
        end) as lt_charging_stations,

        max(case
            when metric_key = 'lt_units_in_kwh'
            then metric_value
        end) as lt_energy_kwh,

        max(case
            when metric_key = 'lt_gross_revenue_deman'
            then metric_value
        end) as lt_revenue_demand_inr,

        max(case
            when metric_key = 'lt_revenue_collected'
            then metric_value
        end) as lt_revenue_collected_inr,

        max(case
            when metric_key = 'ht_ev_charging_stations'
            then metric_value
        end) as ht_charging_stations,

        max(case
            when metric_key = 'ht_units_sold_in_kwh'
            then metric_value
        end) as ht_energy_kwh,

        max(case
            when metric_key = 'ht_of_total_units_sold'
            then metric_value
        end) as ht_pct_of_total_units_sold,

        max(case
            when metric_key = 'ht_gross_revenue_demand'
            then metric_value
        end) as ht_revenue_demand_inr,

        max(case
            when metric_key = 'ht_revenue_collection'
            then metric_value
        end) as ht_revenue_collected_inr

    from {{ ref('stg_ev_consumption') }}

    group by
        fiscal_year,
        fiscal_year_start,
        fiscal_year_end

),

combined as (

    select
        *,

        coalesce(lt_charging_stations, 0)
        + coalesce(ht_charging_stations, 0)
            as reported_charging_stations,

        coalesce(lt_energy_kwh, 0)
        + coalesce(ht_energy_kwh, 0)
            as reported_energy_kwh,

        coalesce(lt_revenue_demand_inr, 0)
        + coalesce(ht_revenue_demand_inr, 0)
            as reported_revenue_demand_inr,

        coalesce(lt_revenue_collected_inr, 0)
        + coalesce(ht_revenue_collected_inr, 0)
            as reported_revenue_collected_inr,

        round(
            lt_revenue_collected_inr
            / nullif(lt_revenue_demand_inr, 0)
            * 100,
            2
        ) as lt_revenue_collection_rate_pct,

        round(
            ht_revenue_collected_inr
            / nullif(ht_revenue_demand_inr, 0)
            * 100,
            2
        ) as ht_revenue_collection_rate_pct,

        case
            when ht_charging_stations is not null
              or ht_energy_kwh is not null
                then 'LT_AND_HT'

            else 'LT_ONLY'
        end as source_coverage_status

    from pivoted

),

with_previous_year as (

    select
        *,

        lag(reported_charging_stations) over (
            order by fiscal_year_start
        ) as previous_year_charging_stations,

        lag(reported_energy_kwh) over (
            order by fiscal_year_start
        ) as previous_year_energy_kwh

    from combined

),

final as (

    select
        md5(fiscal_year) as ev_charging_year_id,

        fiscal_year,
        fiscal_year_start,
        fiscal_year_end,

        lt_charging_stations,
        ht_charging_stations,
        reported_charging_stations,

        lt_energy_kwh,
        ht_energy_kwh,
        reported_energy_kwh,

        ht_pct_of_total_units_sold,

        lt_revenue_demand_inr,
        ht_revenue_demand_inr,
        reported_revenue_demand_inr,

        lt_revenue_collected_inr,
        ht_revenue_collected_inr,
        reported_revenue_collected_inr,

        lt_revenue_collection_rate_pct,
        ht_revenue_collection_rate_pct,

        round(
            reported_revenue_collected_inr
            / nullif(reported_revenue_demand_inr, 0)
            * 100,
            2
        ) as total_revenue_collection_rate_pct,

        previous_year_charging_stations,
        previous_year_energy_kwh,

        round(
            (
                reported_charging_stations
                - previous_year_charging_stations
            )
            / nullif(previous_year_charging_stations, 0)
            * 100,
            2
        ) as charging_stations_yoy_pct,

        round(
            (
                reported_energy_kwh
                - previous_year_energy_kwh
            )
            / nullif(previous_year_energy_kwh, 0)
            * 100,
            2
        ) as energy_consumption_yoy_pct,

        source_coverage_status

    from with_previous_year

)

select *
from final