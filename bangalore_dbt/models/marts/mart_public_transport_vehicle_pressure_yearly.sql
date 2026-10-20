{{ config(materialized = 'table') }}

with vehicle_registration as (

    select
        fiscal_year,
        fiscal_year_start,
        fiscal_year_end,
        snapshot_date,
        closing_registered_vehicles

    from {{ ref('mart_vehicle_registration_city_yearly') }}

),

bmtc as (

    select
        fiscal_year,
        fiscal_year_start,
        fiscal_year_end_date,
        vehicles_held,
        schedules_operated,
        total_service_km_lakh,
        fleet_utilization_pct,
        passengers_per_day_lakh

    from {{ ref('mart_bmtc_yearly_performance') }}

),

joined as (

    select
        vehicle.fiscal_year,
        vehicle.fiscal_year_start,
        vehicle.fiscal_year_end,
        vehicle.snapshot_date,

        vehicle.closing_registered_vehicles
            as total_registered_vehicles,

        bmtc.vehicles_held as bmtc_vehicles_held,
        bmtc.schedules_operated as bmtc_schedules_operated,
        bmtc.total_service_km_lakh,
        bmtc.fleet_utilization_pct,
        bmtc.passengers_per_day_lakh

    from vehicle_registration as vehicle

    inner join bmtc
        on vehicle.fiscal_year_start = bmtc.fiscal_year_start

),

with_previous_year as (

    select
        *,

        lag(total_registered_vehicles) over (
            order by fiscal_year_start
        ) as previous_registered_vehicles,

        lag(bmtc_vehicles_held) over (
            order by fiscal_year_start
        ) as previous_bmtc_vehicles_held,

        lag(bmtc_schedules_operated) over (
            order by fiscal_year_start
        ) as previous_bmtc_schedules_operated,

        lag(total_service_km_lakh) over (
            order by fiscal_year_start
        ) as previous_total_service_km_lakh,

        first_value(total_registered_vehicles) over (
            order by fiscal_year_start
        ) as baseline_registered_vehicles,

        first_value(bmtc_vehicles_held) over (
            order by fiscal_year_start
        ) as baseline_bmtc_vehicles_held,

        first_value(bmtc_schedules_operated) over (
            order by fiscal_year_start
        ) as baseline_bmtc_schedules_operated,

        first_value(total_service_km_lakh) over (
            order by fiscal_year_start
        ) as baseline_total_service_km_lakh

    from joined

),

calculated as (

    select
        *,

        round(
            100.0 * (
                total_registered_vehicles
                - previous_registered_vehicles
            )
            / nullif(previous_registered_vehicles, 0),
            2
        ) as registered_vehicles_yoy_pct,

        round(
            100.0 * (
                bmtc_vehicles_held
                - previous_bmtc_vehicles_held
            )
            / nullif(previous_bmtc_vehicles_held, 0),
            2
        ) as bmtc_fleet_yoy_pct,

        round(
            100.0 * (
                bmtc_schedules_operated
                - previous_bmtc_schedules_operated
            )
            / nullif(previous_bmtc_schedules_operated, 0),
            2
        ) as bmtc_schedules_yoy_pct,

        round(
            100.0 * (
                total_service_km_lakh
                - previous_total_service_km_lakh
            )
            / nullif(previous_total_service_km_lakh, 0),
            2
        ) as bmtc_service_km_yoy_pct,

        round(
            total_registered_vehicles
            / nullif(bmtc_vehicles_held, 0),
            2
        ) as registered_vehicles_per_bmtc_vehicle,

        round(
            total_registered_vehicles
            / nullif(bmtc_schedules_operated, 0),
            2
        ) as registered_vehicles_per_bmtc_schedule,

        round(
            100.0 * total_registered_vehicles
            / nullif(baseline_registered_vehicles, 0),
            2
        ) as registered_vehicle_index,

        round(
            100.0 * bmtc_vehicles_held
            / nullif(baseline_bmtc_vehicles_held, 0),
            2
        ) as bmtc_fleet_index,

        round(
            100.0 * bmtc_schedules_operated
            / nullif(baseline_bmtc_schedules_operated, 0),
            2
        ) as bmtc_schedule_index,

        round(
            100.0 * total_service_km_lakh
            / nullif(baseline_total_service_km_lakh, 0),
            2
        ) as bmtc_service_km_index

    from with_previous_year

),

final as (

    select
        fiscal_year,
        fiscal_year_start,
        fiscal_year_end,
        snapshot_date,

        total_registered_vehicles,
        bmtc_vehicles_held,
        bmtc_schedules_operated,
        total_service_km_lakh,
        fleet_utilization_pct,
        passengers_per_day_lakh,

        registered_vehicles_yoy_pct,
        bmtc_fleet_yoy_pct,
        bmtc_schedules_yoy_pct,
        bmtc_service_km_yoy_pct,

        round(
            registered_vehicles_yoy_pct
            - bmtc_schedules_yoy_pct,
            2
        ) as vehicle_vs_schedule_growth_gap_pct_points,

        registered_vehicles_per_bmtc_vehicle,
        registered_vehicles_per_bmtc_schedule,

        registered_vehicle_index,
        bmtc_fleet_index,
        bmtc_schedule_index,
        bmtc_service_km_index,

        round(
            100.0 * registered_vehicle_index
            / nullif(bmtc_schedule_index, 0),
            2
        ) as motorisation_supply_pressure_index,

        case
            when registered_vehicle_index > bmtc_schedule_index
                then 'Vehicle stock growing faster than BMTC schedules'
            when registered_vehicle_index < bmtc_schedule_index
                then 'BMTC schedules growing faster than vehicle stock'
            else 'Similar growth'
        end as comparative_growth_status

    from calculated

)

select *
from final
order by fiscal_year_start