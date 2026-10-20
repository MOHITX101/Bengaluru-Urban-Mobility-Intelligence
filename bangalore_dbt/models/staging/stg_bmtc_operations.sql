{{ config(
    materialized = 'view',
    schema = 'STAGING'
) }}

with source_data as (

    select
        parameter_raw,
        fy_2012_13_raw,
        fy_2013_14_raw,
        fy_2014_15_raw,
        fy_2015_16_raw,
        fy_2016_17_raw,
        fy_2017_18_raw,
        fy_2018_19_raw,
        fy_2019_20_raw,
        fy_2020_21_raw,
        fy_2021_22_raw,
        fy_2022_23_raw,
        fy_2023_24_raw,
        fy_2024_25_raw,
        fy_2025_26_raw,
        source_filename,
        source_row_number,
        loaded_at

    from {{ source('raw_bangalore', 'bmtc_operations') }}

),

/*
Convert the wide financial-year columns into rows.

Expected grain:
one BMTC parameter × one financial year.
*/
unpivoted as (

    select
        regexp_replace(
            trim(s.parameter_raw),
            '\\s+',
            ' '
        ) as parameter_name,

        f.value:fiscal_year::varchar as fiscal_year,

        nullif(
            trim(f.value:raw_value::varchar),
            ''
        ) as raw_value,

        s.source_filename,
        s.source_row_number,
        s.loaded_at

    from source_data s,

    lateral flatten(
        input => array_construct(
            object_construct_keep_null(
                'fiscal_year', '2012-13',
                'raw_value', s.fy_2012_13_raw
            ),
            object_construct_keep_null(
                'fiscal_year', '2013-14',
                'raw_value', s.fy_2013_14_raw
            ),
            object_construct_keep_null(
                'fiscal_year', '2014-15',
                'raw_value', s.fy_2014_15_raw
            ),
            object_construct_keep_null(
                'fiscal_year', '2015-16',
                'raw_value', s.fy_2015_16_raw
            ),
            object_construct_keep_null(
                'fiscal_year', '2016-17',
                'raw_value', s.fy_2016_17_raw
            ),
            object_construct_keep_null(
                'fiscal_year', '2017-18',
                'raw_value', s.fy_2017_18_raw
            ),
            object_construct_keep_null(
                'fiscal_year', '2018-19',
                'raw_value', s.fy_2018_19_raw
            ),
            object_construct_keep_null(
                'fiscal_year', '2019-20',
                'raw_value', s.fy_2019_20_raw
            ),
            object_construct_keep_null(
                'fiscal_year', '2020-21',
                'raw_value', s.fy_2020_21_raw
            ),
            object_construct_keep_null(
                'fiscal_year', '2021-22',
                'raw_value', s.fy_2021_22_raw
            ),
            object_construct_keep_null(
                'fiscal_year', '2022-23',
                'raw_value', s.fy_2022_23_raw
            ),
            object_construct_keep_null(
                'fiscal_year', '2023-24',
                'raw_value', s.fy_2023_24_raw
            ),
            object_construct_keep_null(
                'fiscal_year', '2024-25',
                'raw_value', s.fy_2024_25_raw
            ),
            object_construct_keep_null(
                'fiscal_year', '2025-26',
                'raw_value', s.fy_2025_26_raw
            )
        )
    ) f

),

standardized as (

    select
        parameter_name,

        trim(
            regexp_replace(
                lower(parameter_name),
                '[^a-z0-9]+',
                '_'
            ),
            '_'
        ) as parameter_key,

        fiscal_year,

        try_to_number(
            split_part(fiscal_year, '-', 1)
        ) as fiscal_year_start,

        try_to_number(
            split_part(fiscal_year, '-', 1)
        ) + 1 as fiscal_year_end,

        raw_value,

        /*
        First numeric component.

        Examples:
        565+30EV → 565
        390EV    → 390
        -80394.25 → -80394.25
        */
        try_to_decimal(
            regexp_substr(
                raw_value,
                '-?[0-9]+[.]?[0-9]*',
                1,
                1
            ),
            18,
            4
        ) as value_component_1,

        /*
        Second numeric component, where one exists.

        Examples:
        565+30EV → 30
        469+115  → 115
        */
        try_to_decimal(
            regexp_substr(
                raw_value,
                '-?[0-9]+[.]?[0-9]*',
                1,
                2
            ),
            18,
            4
        ) as value_component_2,

        source_filename,
        source_row_number,
        loaded_at

    from unpivoted

    where parameter_name is not null

),

classified as (

    select
        parameter_name,
        parameter_key,
        fiscal_year,
        fiscal_year_start,
        fiscal_year_end,

        to_date(
            fiscal_year_start || '-04-01'
        ) as fiscal_year_start_date,

        dateadd(
            day,
            -1,
            dateadd(
                year,
                1,
                to_date(fiscal_year_start || '-04-01')
            )
        ) as fiscal_year_end_date,

        case
            when parameter_key in (
                'depots',
                'schedules_operated',
                'schedules_added',
                'schedules_curtailed'
            )
                then 'Operations'

            when parameter_key in (
                'vehicles_held',
                'new_vehicles_added',
                'vehicles_scrapped',
                'fleet_utilization',
                'veh_utilisation_km',
                'kmpl_hsd'
            )
                then 'Fleet'

            when parameter_key in (
                'passengers_carried_per_day_lakh',
                'passenger_load_factor'
            )
                then 'Passengers'

            when parameter_key in (
                'age_cancellation',
                'no_of_breakdowns',
                'rate_of_breakdows_10000_kms'
            )
                then 'Service reliability'

            when parameter_key in (
                'no_of_accidents',
                'rate_of_accidents_lakh_kms'
            )
                then 'Safety'

            when parameter_key = 'staff_position'
                then 'Workforce'

            when lower(parameter_name) like '%revenue%'
              or lower(parameter_name) like '%cost%'
              or lower(parameter_name) like '%margin%'
              or lower(parameter_name) like '%epkm%'
              or lower(parameter_name) like '%cpkm%'
              or lower(parameter_name) like '%reimbursement%'
                then 'Financial'

            else 'Other'
        end as parameter_group,

        case
            when parameter_key in (
                'depots',
                'schedules_operated',
                'schedules_added',
                'schedules_curtailed',
                'vehicles_held',
                'new_vehicles_added',
                'vehicles_scrapped',
                'no_of_breakdowns',
                'no_of_accidents',
                'staff_position'
            )
                then 'Count'

            when parameter_key = 'effective_km_per_day_lakh'
                then 'Lakh kilometres per day'

            when parameter_key = 'total_service_km_lakh_km'
                then 'Lakh kilometres'

            when parameter_key = 'veh_utilisation_km'
                then 'Kilometres per vehicle per day'

            when parameter_key = 'passengers_carried_per_day_lakh'
                then 'Lakh passengers per day'

            when parameter_key in (
                'passenger_load_factor',
                'age_cancellation',
                'fleet_utilization'
            )
                then 'Percent'

            when parameter_key = 'kmpl_hsd'
                then 'Kilometres per litre'

            when parameter_key = 'rate_of_breakdows_10000_kms'
                then 'Breakdowns per 10,000 kilometres'

            when parameter_key = 'rate_of_accidents_lakh_kms'
                then 'Accidents per lakh kilometres'

            when lower(parameter_name) like '%rs. lakhs%'
              or lower(parameter_name) like '%rs. lakh%'
                then 'INR lakh'

            when lower(parameter_name) like '%paise%'
                then 'Paise per kilometre'

            else 'Source-defined'
        end as measurement_unit,

        raw_value,
        value_component_1,
        value_component_2,

        /*
        Sum expressions such as:
        565+30EV = 595 total vehicles
        238+240EV = 478 total vehicles
        469+115 = 584 total vehicles

        The original value remains available in raw_value.
        */
        case
            when raw_value is null then null
            when value_component_1 is null then null
            else value_component_1
                 + coalesce(value_component_2, 0)
        end as metric_value,

        /*
        Capture an explicitly labelled EV component.

        565+30EV  → 30
        238+240EV → 240
        390EV     → 390
        */
        case
            when upper(raw_value) not like '%EV%'
                then null

            when value_component_2 is not null
                then value_component_2

            else value_component_1
        end as explicitly_labelled_ev_value,

        case
            when raw_value is null then true
            else false
        end as is_missing_value,

        case
            when raw_value like '%+%' then true
            else false
        end as is_composite_value,

        source_filename,
        source_row_number,
        loaded_at

    from standardized

),

final as (

    select
        md5(
            concat_ws(
                '||',
                parameter_key,
                fiscal_year
            )
        ) as bmtc_parameter_year_id,

        parameter_name,
        parameter_key,
        parameter_group,
        measurement_unit,

        fiscal_year,
        fiscal_year_start,
        fiscal_year_end,
        fiscal_year_start_date,
        fiscal_year_end_date,

        raw_value,
        metric_value,
        value_component_1,
        value_component_2,
        explicitly_labelled_ev_value,

        is_missing_value,
        is_composite_value,

        source_filename,
        source_row_number,
        loaded_at

    from classified

)

select *
from final