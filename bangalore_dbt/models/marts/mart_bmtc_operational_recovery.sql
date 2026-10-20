{{ config(
    materialized = 'view',
    schema = 'MARTS'
) }}

select
    fiscal_year,
    fiscal_year_start,
    fiscal_year_start_date,
    fiscal_year_end_date,

    depots,
    schedules_operated,
    vehicles_held,
    effective_km_per_day_lakh,
    total_service_km_lakh,
    vehicle_utilisation_km,
    fleet_utilization_pct,

    passengers_per_day_lakh,
    passenger_load_factor_pct,

    schedules_operated_yoy_pct,
    total_service_km_yoy_pct,

    schedule_index_vs_2019_20,
    service_km_index_vs_2019_20,

    round(
        schedule_index_vs_2019_20 - 100,
        2
    ) as schedule_gap_vs_2019_20_pct,

    round(
        service_km_index_vs_2019_20 - 100,
        2
    ) as service_km_gap_vs_2019_20_pct,

    round(
        (
            total_service_km_lakh * 100000
        )
        / nullif(schedules_operated, 0),
        2
    ) as annual_service_km_per_schedule,

    case
        when schedule_index_vs_2019_20 >= 100
         and service_km_index_vs_2019_20 >= 100
            then 'ABOVE_BASELINE'

        when schedule_index_vs_2019_20 >= 90
          or service_km_index_vs_2019_20 >= 90
            then 'RECOVERING_NEAR_BASELINE'

        else 'BELOW_BASELINE'
    end as operational_recovery_status

from {{ ref('mart_bmtc_yearly_performance') }}

where fiscal_year_start >= 2017
