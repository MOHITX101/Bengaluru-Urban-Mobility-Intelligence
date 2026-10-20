{{ config(
    materialized = 'view'
) }}

with raw_enforcement as (

    select *
    from {{ source('raw_bangalore', 'traffic_cases_and_fines') }}

),

typed as (

    select
        try_to_number(year_raw) as enforcement_year,

        try_to_number(mv_act_cases_raw) as mv_act_cases,
        try_to_number(mv_act_fine_raw) as mv_act_fine_inr,

        try_to_number(kp_act_cases_raw) as kp_act_cases,
        try_to_number(kp_act_fine_raw) as kp_act_fine_inr,

        try_to_number(towing_cases_raw) as towing_cases,
        try_to_number(towing_charges_raw) as towing_charges_inr,

        try_to_number(ktc_act_cases_raw) as ktc_act_cases,
        try_to_number(ktc_act_fine_raw) as ktc_act_fine_inr,

        try_to_number(automation_cases_raw) as automation_cases,
        try_to_number(automation_fine_raw) as automation_fine_inr,

        try_to_number(total_cases_booked_raw) as reported_total_cases,
        try_to_number(total_fine_collected_raw) as reported_total_fine_inr,

        source_filename,
        source_row_number,
        loaded_at

    from raw_enforcement

    where try_to_number(year_raw) is not null

),

calculated as (

    select
        *,

        coalesce(mv_act_cases, 0)
        + coalesce(kp_act_cases, 0)
        + coalesce(towing_cases, 0)
        + coalesce(ktc_act_cases, 0)
        + coalesce(automation_cases, 0)
            as calculated_total_cases,

        coalesce(mv_act_fine_inr, 0)
        + coalesce(kp_act_fine_inr, 0)
        + coalesce(towing_charges_inr, 0)
        + coalesce(ktc_act_fine_inr, 0)
        + coalesce(automation_fine_inr, 0)
            as calculated_total_fine_inr

    from typed

),

final as (

    select
        md5(
            to_varchar(enforcement_year)
        ) as enforcement_year_id,

        enforcement_year,

        mv_act_cases,
        mv_act_fine_inr,
        kp_act_cases,
        kp_act_fine_inr,
        towing_cases,
        towing_charges_inr,
        ktc_act_cases,
        ktc_act_fine_inr,
        automation_cases,
        automation_fine_inr,

        reported_total_cases,
        calculated_total_cases,

        reported_total_cases
            - calculated_total_cases
            as total_cases_difference,

        reported_total_fine_inr,
        calculated_total_fine_inr,

        reported_total_fine_inr
            - calculated_total_fine_inr
            as total_fine_difference_inr,

        case
            when reported_total_cases = calculated_total_cases
                then 'MATCHED'
            else 'MISMATCHED'
        end as case_total_reconciliation_status,

        case
            when reported_total_fine_inr = calculated_total_fine_inr
                then 'MATCHED'
            else 'MISMATCHED'
        end as fine_total_reconciliation_status,

        source_filename,
        source_row_number,
        loaded_at

    from calculated

)

select *
from final