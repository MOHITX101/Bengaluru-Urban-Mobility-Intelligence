{{ config(
    materialized = 'table',
    schema = 'MARTS'
) }}

with annual_enforcement as (

    select *
    from {{ ref('stg_traffic_enforcement_annual') }}

),

offence_totals as (

    select
        enforcement_year,
        reported_total_offence_cases

    from {{ ref('stg_mv_act_offence_reported_totals') }}

),

joined as (

    select
        a.*,
        o.reported_total_offence_cases,

        a.reported_total_cases
            - o.reported_total_offence_cases
            as annual_vs_offence_scope_difference

    from annual_enforcement a

    left join offence_totals o
        on a.enforcement_year = o.enforcement_year

),

calculated as (

    select
        *,

        reported_total_fine_inr
            / nullif(reported_total_cases, 0)
            as avg_fine_per_case_inr,

        100.0 * automation_cases
            / nullif(reported_total_cases, 0)
            as automation_case_share_pct,

        100.0 * reported_total_offence_cases
            / nullif(reported_total_cases, 0)
            as offence_detail_coverage_pct,

        lag(reported_total_cases) over (
            order by enforcement_year
        ) as previous_year_cases,

        lag(reported_total_fine_inr) over (
            order by enforcement_year
        ) as previous_year_fine

    from joined

),

final as (

    select
        enforcement_year_id,
        enforcement_year,

        mv_act_cases,
        kp_act_cases,
        towing_cases,
        ktc_act_cases,
        automation_cases,

        reported_total_cases,
        calculated_total_cases,
        total_cases_difference,
        case_total_reconciliation_status,

        reported_total_offence_cases,
        annual_vs_offence_scope_difference,

        round(
            offence_detail_coverage_pct,
            2
        ) as offence_detail_coverage_pct,

        reported_total_fine_inr,

        round(
            reported_total_fine_inr / 10000000.0,
            2
        ) as reported_total_fine_crore_inr,

        calculated_total_fine_inr,
        total_fine_difference_inr,
        fine_total_reconciliation_status,

        round(
            avg_fine_per_case_inr,
            2
        ) as avg_fine_per_case_inr,

        round(
            automation_case_share_pct,
            2
        ) as automation_case_share_pct,

        round(
            100.0 * (
                reported_total_cases - previous_year_cases
            ) / nullif(previous_year_cases, 0),
            2
        ) as total_cases_yoy_pct,

        round(
            100.0 * (
                reported_total_fine_inr - previous_year_fine
            ) / nullif(previous_year_fine, 0),
            2
        ) as total_fine_yoy_pct

    from calculated

)

select *
from final