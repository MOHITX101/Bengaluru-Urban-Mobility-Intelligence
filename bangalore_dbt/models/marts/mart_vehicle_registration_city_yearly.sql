{{ config(
    materialized = 'table',
    schema = 'MARTS'
) }}

with registration_2021_22 as (

    select
        fiscal_year,
        fiscal_year_start,
        fiscal_year_end,
        snapshot_date,

        estimated_opening_registered_vehicles
            as opening_registered_vehicles,

        newly_added_vehicles as reported_vehicle_additions,
        total_registered_vehicles as closing_registered_vehicles,

        'NEWLY_ADDED' as additions_measure_type,
        'REPORTED' as data_status

    from {{ ref('stg_vehicle_registrations_2022_rto') }}

    where row_type = 'GRAND_TOTAL'

),

reported_snapshots as (

    select
        fiscal_year,
        fiscal_year_start,
        fiscal_year_end,
        closing_snapshot_date as snapshot_date,

        opening_registered_vehicles,
        net_vehicle_additions as reported_vehicle_additions,
        closing_registered_vehicles,

        'NET_ADDITIONS' as additions_measure_type,
        'REPORTED' as data_status

    from {{ ref('stg_vehicle_registration_snapshots') }}

    where row_type = 'GRAND_TOTAL'

),

gap_values as (

    select
        max(
            case
                when fiscal_year = '2023-24'
                then closing_registered_vehicles
            end
        ) as fy_2023_24_closing_total,

        max(
            case
                when fiscal_year = '2025-26'
                then opening_registered_vehicles
            end
        ) as fy_2025_26_opening_total

    from reported_snapshots

),

derived_2024_25 as (

    select
        '2024-25' as fiscal_year,
        2024 as fiscal_year_start,
        2025 as fiscal_year_end,
        to_date('2025-03-31') as snapshot_date,

        fy_2023_24_closing_total
            as opening_registered_vehicles,

        fy_2025_26_opening_total
        - fy_2023_24_closing_total
            as reported_vehicle_additions,

        fy_2025_26_opening_total
            as closing_registered_vehicles,

        'IMPLIED_NET_ADDITIONS' as additions_measure_type,
        'DERIVED_FROM_ADJACENT_SNAPSHOTS' as data_status

    from gap_values

),

combined as (

    select * from registration_2021_22

    union all

    select * from reported_snapshots

    union all

    select * from derived_2024_25

),

with_previous_year as (

    select
        *,

        lag(closing_registered_vehicles) over (
            order by fiscal_year_start
        ) as previous_year_closing_vehicles

    from combined

),

final as (

    select
        md5(fiscal_year) as vehicle_registration_year_id,

        fiscal_year,
        fiscal_year_start,
        fiscal_year_end,
        snapshot_date,

        opening_registered_vehicles,
        reported_vehicle_additions,
        closing_registered_vehicles,

        additions_measure_type,
        data_status,

        previous_year_closing_vehicles,

        closing_registered_vehicles
        - previous_year_closing_vehicles
            as calculated_yearly_fleet_change,

        round(
            (
                closing_registered_vehicles
                - previous_year_closing_vehicles
            )
            / nullif(previous_year_closing_vehicles, 0)
            * 100,
            2
        ) as registered_vehicle_growth_pct,

        round(
            closing_registered_vehicles
            /
            nullif(
                max(
                    case
                        when fiscal_year = '2021-22'
                        then closing_registered_vehicles
                    end
                ) over (),
                0
            )
            * 100,
            2
        ) as vehicle_index_vs_2021_22,

        closing_registered_vehicles
        -
        max(
            case
                when fiscal_year = '2021-22'
                then closing_registered_vehicles
            end
        ) over ()
            as cumulative_vehicle_increase_vs_2021_22

    from with_previous_year

)

select *
from final