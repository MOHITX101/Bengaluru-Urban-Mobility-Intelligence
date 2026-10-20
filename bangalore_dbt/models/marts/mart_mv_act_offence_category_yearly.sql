{{ config(
    materialized = 'table',
    schema = 'MARTS'
) }}

with offences as (

    select *
    from {{ ref('stg_mv_act_offences') }}

),

reported_totals as (

    select
        enforcement_year,
        reported_total_offence_cases

    from {{ ref('stg_mv_act_offence_reported_totals') }}

),

joined as (

    select
        o.offence_year_id,
        o.serial_number,
        o.offence_type,
        o.enforcement_year,
        o.offence_cases,
        o.is_missing_offence_count,
        t.reported_total_offence_cases

    from offences o

    left join reported_totals t
        on o.enforcement_year = t.enforcement_year

),

with_previous_year as (

    select
        *,

        lag(offence_cases) over (
            partition by offence_type
            order by enforcement_year
        ) as previous_year_offence_cases

    from joined

),

calculated as (

    select
        *,

        100.0 * offence_cases
            / nullif(reported_total_offence_cases, 0)
            as offence_share_pct,

        100.0 * (
            offence_cases - previous_year_offence_cases
        ) / nullif(previous_year_offence_cases, 0)
            as offence_cases_yoy_pct

    from with_previous_year

),

ranked as (

    select
        *,

        case
            when offence_cases is not null then
                dense_rank() over (
                    partition by enforcement_year
                    order by
                        case
                            when offence_cases is not null
                                then offence_cases
                        end desc nulls last
                )
            else null
        end as offence_rank_in_year

    from calculated

)

select
    offence_year_id,
    serial_number,
    offence_type,
    enforcement_year,
    offence_cases,
    is_missing_offence_count,
    reported_total_offence_cases,

    round(
        offence_share_pct,
        2
    ) as offence_share_pct,

    previous_year_offence_cases,

    round(
        offence_cases_yoy_pct,
        2
    ) as offence_cases_yoy_pct,

    offence_rank_in_year

from ranked