{{ config(
    materialized = 'table',
    schema = 'MARTS'
) }}

with detail_2021_22 as (

    select
        fiscal_year,
        fiscal_year_start,
        fiscal_year_end,
        snapshot_date,

        lower(
            concat_ws(
                '||',
                vehicle_category,
                vehicle_type
            )
        ) as vehicle_type_key,

        vehicle_category,
        vehicle_type,

        estimated_opening_registered_vehicles
            as opening_registered_vehicles,

        newly_added_vehicles as reported_vehicle_additions,
        total_registered_vehicles as closing_registered_vehicles,

        'NEWLY_ADDED' as additions_measure_type,
        'REPORTED' as data_status

    from {{ ref('stg_vehicle_registrations_2022_rto') }}

    where row_type = 'DETAIL'

),

reported_detail_snapshots as (

    select
        fiscal_year,
        fiscal_year_start,
        fiscal_year_end,
        closing_snapshot_date as snapshot_date,

        lower(
            concat_ws(
                '||',
                vehicle_category,
                vehicle_type
            )
        ) as vehicle_type_key,

        vehicle_category,
        vehicle_type,

        opening_registered_vehicles,
        net_vehicle_additions as reported_vehicle_additions,
        closing_registered_vehicles,

        'NET_ADDITIONS' as additions_measure_type,
        'REPORTED' as data_status

    from {{ ref('stg_vehicle_registration_snapshots') }}

    where row_type = 'DETAIL'

),

fy_2023_24 as (

    select *
    from reported_detail_snapshots
    where fiscal_year = '2023-24'

),

fy_2025_26 as (

    select *
    from reported_detail_snapshots
    where fiscal_year = '2025-26'

),

derived_2024_25 as (

    select
        '2024-25' as fiscal_year,
        2024 as fiscal_year_start,
        2025 as fiscal_year_end,
        to_date('2025-03-31') as snapshot_date,

        previous.vehicle_type_key,
        previous.vehicle_category,
        previous.vehicle_type,

        previous.closing_registered_vehicles
            as opening_registered_vehicles,

        current_year.opening_registered_vehicles
        - previous.closing_registered_vehicles
            as reported_vehicle_additions,

        current_year.opening_registered_vehicles
            as closing_registered_vehicles,

        'IMPLIED_NET_ADDITIONS' as additions_measure_type,
        'DERIVED_FROM_ADJACENT_SNAPSHOTS' as data_status

    from fy_2023_24 previous

    inner join fy_2025_26 current_year
        on previous.vehicle_type_key = current_year.vehicle_type_key

),

combined as (

    select * from detail_2021_22

    union all

    select * from reported_detail_snapshots

    union all

    select * from derived_2024_25

),

with_previous_year as (

    select
        *,

        lag(closing_registered_vehicles) over (
            partition by vehicle_type_key
            order by fiscal_year_start
        ) as previous_year_closing_vehicles,

        sum(closing_registered_vehicles) over (
            partition by fiscal_year
        ) as calculated_citywide_total

    from combined

),

final as (

    select
        md5(
            concat_ws(
                '||',
                fiscal_year,
                vehicle_type_key
            )
        ) as vehicle_type_year_id,

        fiscal_year,
        fiscal_year_start,
        fiscal_year_end,
        snapshot_date,

        vehicle_type_key,
        vehicle_category,
        vehicle_type,

        opening_registered_vehicles,
        reported_vehicle_additions,
        closing_registered_vehicles,
        previous_year_closing_vehicles,

        additions_measure_type,
        data_status,

        closing_registered_vehicles
        - previous_year_closing_vehicles
            as calculated_yearly_vehicle_change,

        round(
            (
                closing_registered_vehicles
                - previous_year_closing_vehicles
            )
            / nullif(previous_year_closing_vehicles, 0)
            * 100,
            2
        ) as vehicle_type_growth_pct,

        calculated_citywide_total,

        round(
            closing_registered_vehicles
            / nullif(calculated_citywide_total, 0)
            * 100,
            2
        ) as vehicle_type_fleet_share_pct,

        rank() over (
            partition by fiscal_year
            order by closing_registered_vehicles desc
        ) as vehicle_type_fleet_rank,

        rank() over (
            partition by fiscal_year
            order by reported_vehicle_additions desc
        ) as vehicle_additions_rank

    from with_previous_year

)

select *
from final