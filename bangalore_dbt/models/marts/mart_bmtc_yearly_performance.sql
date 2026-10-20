{{ config(
    materialized = 'table',
    schema = 'MARTS'
) }}

with staged as (

    select *
    from {{ ref('stg_bmtc_operations') }}

),

yearly_pivot as (

    select
        fiscal_year,
        fiscal_year_start,
        fiscal_year_end,
        fiscal_year_start_date,
        fiscal_year_end_date,

        max(case when parameter_key = 'depots'
            then metric_value end) as depots,

        max(case when parameter_key = 'schedules_operated'
            then metric_value end) as schedules_operated,

        max(case when parameter_key = 'vehicles_held'
            then metric_value end) as vehicles_held,

        max(case when parameter_key = 'effective_km_per_day_lakh'
            then metric_value end) as effective_km_per_day_lakh,

        max(case when parameter_key = 'total_service_km_lakh_km'
            then metric_value end) as total_service_km_lakh,

        max(case when parameter_key = 'veh_utilisation_km'
            then metric_value end) as vehicle_utilisation_km,

        max(case when parameter_key = 'passengers_carried_per_day_lakh'
            then metric_value end) as passengers_per_day_lakh,

        max(case when parameter_key = 'passenger_load_factor'
            then metric_value end) as passenger_load_factor_pct,

        max(case when parameter_key = 'schedules_added'
            then metric_value end) as schedules_added,

        max(case when parameter_key = 'schedules_curtailed'
            then metric_value end) as schedules_curtailed,

        max(case when parameter_key = 'new_vehicles_added'
            then metric_value end) as new_vehicles_added,

        max(case when parameter_key = 'new_vehicles_added'
            then explicitly_labelled_ev_value end
        ) as explicitly_labelled_evs_added,

        max(case when parameter_key = 'vehicles_scrapped'
            then metric_value end) as vehicles_scrapped,

        max(case when parameter_key = 'age_cancellation'
            then metric_value end) as cancellation_pct,

        max(case when parameter_key = 'fleet_utilization'
            then metric_value end) as fleet_utilization_pct,

        max(case when parameter_key = 'kmpl_hsd'
            then metric_value end) as kmpl_hsd,

        max(case when parameter_key = 'no_of_breakdowns'
            then metric_value end) as breakdowns,

        max(case when parameter_key = 'rate_of_breakdows_10000_kms'
            then metric_value end) as breakdowns_per_10000_km,

        max(case when parameter_key = 'no_of_accidents'
            then metric_value end) as bmtc_accidents,

        max(case when parameter_key = 'rate_of_accidents_lakh_kms'
            then metric_value end) as accidents_per_lakh_km,

        max(case when parameter_key = 'staff_position'
            then metric_value end) as staff_count,

        max(case when parameter_key = 'traffic_revenue_in_rs_lakhs'
            then metric_value end) as traffic_revenue_inr_lakh,

        max(case when parameter_key =
            'a_govt_reimbursement_fin_assistance'
            then metric_value end) as government_support_inr_lakh,

        max(case when parameter_key = 'b_commercial_revenue'
            then metric_value end) as commercial_revenue_inr_lakh,

        max(case when parameter_key = 'total_non_traffic_revenue'
            then metric_value end) as non_traffic_revenue_inr_lakh,

        max(case when parameter_key = 'gross_revenue_in_rs_lakhs'
            then metric_value end) as gross_revenue_inr_lakh,

        max(case when parameter_key = 'cost_of_operation_in_rs_lakhs'
            then metric_value end) as operating_cost_inr_lakh,

        max(case when parameter_key =
            'margin_on_traffic_revenue_in_rs_lakhs'
            then metric_value end) as traffic_revenue_margin_inr_lakh,

        max(case when parameter_key =
            'margin_on_gross_revenue_rs_lakhs'
            then metric_value end) as gross_revenue_margin_inr_lakh,

        max(case when parameter_key = 'epkm_on_traffic_revnue_paise'
            then metric_value end) as traffic_epkm_paise,

        max(case when parameter_key = 'epkm_on_gross_revenue_paise'
            then metric_value end) as gross_epkm_paise,

        max(case when parameter_key = 'cpkm_paise'
            then metric_value end) as cpkm_paise,

        max(case when parameter_key =
            'margin_on_traffic_revenue_per_km_in_paise'
            then metric_value end) as traffic_margin_per_km_paise,

        max(case when parameter_key =
            'margin_on_gross_revenue_per_km_in_paise'
            then metric_value end) as gross_margin_per_km_paise

    from staged

    group by
        fiscal_year,
        fiscal_year_start,
        fiscal_year_end,
        fiscal_year_start_date,
        fiscal_year_end_date

),

with_previous_year as (

    select
        y.*,

        lag(schedules_operated) over (
            order by fiscal_year_start
        ) as previous_schedules_operated,

        lag(total_service_km_lakh) over (
            order by fiscal_year_start
        ) as previous_total_service_km_lakh,

        lag(bmtc_accidents) over (
            order by fiscal_year_start
        ) as previous_bmtc_accidents,

        lag(gross_revenue_inr_lakh) over (
            order by fiscal_year_start
        ) as previous_gross_revenue_inr_lakh,

        lag(operating_cost_inr_lakh) over (
            order by fiscal_year_start
        ) as previous_operating_cost_inr_lakh

    from yearly_pivot y

),

baseline_2019_20 as (

    select
        schedules_operated as baseline_schedules_operated,
        total_service_km_lakh as baseline_total_service_km_lakh
    from yearly_pivot
    where fiscal_year = '2019-20'

),

calculated as (

    select
        y.*,

        round(
            y.schedules_operated
            / nullif(y.vehicles_held, 0),
            3
        ) as schedules_per_vehicle,

        round(
            y.staff_count
            / nullif(y.schedules_operated, 0),
            2
        ) as staff_per_operated_schedule,

        case
            when y.new_vehicles_added is null then null
            else y.new_vehicles_added
                 - coalesce(y.explicitly_labelled_evs_added, 0)
        end as other_vehicles_added,

        round(
            (
                y.explicitly_labelled_evs_added
                / nullif(y.new_vehicles_added, 0)
            ) * 100,
            2
        ) as explicitly_labelled_ev_share_pct,

        round(
            (
                y.traffic_revenue_inr_lakh
                / nullif(y.operating_cost_inr_lakh, 0)
            ) * 100,
            2
        ) as traffic_revenue_cost_coverage_pct,

        round(
            (
                y.gross_revenue_inr_lakh
                / nullif(y.operating_cost_inr_lakh, 0)
            ) * 100,
            2
        ) as gross_revenue_cost_coverage_pct,

        round(
            (
                y.gross_revenue_margin_inr_lakh
                / nullif(y.gross_revenue_inr_lakh, 0)
            ) * 100,
            2
        ) as gross_operating_margin_pct,

        round(
            (
                y.government_support_inr_lakh
                / nullif(y.gross_revenue_inr_lakh, 0)
            ) * 100,
            2
        ) as government_support_share_pct,

        round(
            (
                (
                    y.schedules_operated
                    - y.previous_schedules_operated
                )
                / nullif(y.previous_schedules_operated, 0)
            ) * 100,
            2
        ) as schedules_operated_yoy_pct,

        round(
            (
                (
                    y.total_service_km_lakh
                    - y.previous_total_service_km_lakh
                )
                / nullif(y.previous_total_service_km_lakh, 0)
            ) * 100,
            2
        ) as total_service_km_yoy_pct,

        round(
            (
                (
                    y.bmtc_accidents
                    - y.previous_bmtc_accidents
                )
                / nullif(y.previous_bmtc_accidents, 0)
            ) * 100,
            2
        ) as bmtc_accidents_yoy_pct,

        round(
            (
                (
                    y.gross_revenue_inr_lakh
                    - y.previous_gross_revenue_inr_lakh
                )
                / nullif(y.previous_gross_revenue_inr_lakh, 0)
            ) * 100,
            2
        ) as gross_revenue_yoy_pct,

        round(
            (
                (
                    y.operating_cost_inr_lakh
                    - y.previous_operating_cost_inr_lakh
                )
                / nullif(y.previous_operating_cost_inr_lakh, 0)
            ) * 100,
            2
        ) as operating_cost_yoy_pct,

        round(
            (
                y.schedules_operated
                / nullif(b.baseline_schedules_operated, 0)
            ) * 100,
            2
        ) as schedule_index_vs_2019_20,

        round(
            (
                y.total_service_km_lakh
                / nullif(b.baseline_total_service_km_lakh, 0)
            ) * 100,
            2
        ) as service_km_index_vs_2019_20

    from with_previous_year y

    cross join baseline_2019_20 b

),

final as (

    select
        md5(fiscal_year) as bmtc_financial_year_id,
        *
    from calculated

)

select *
from final