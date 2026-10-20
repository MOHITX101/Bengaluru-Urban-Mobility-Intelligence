{{ config(
    materialized = 'view'
) }}

with raw_accidents as (

    select *
    from {{ source('raw_bangalore', 'accidents_2021_2022') }}

),

cleaned as (

    select
        nullif(initcap(trim(zone_raw)), '') as traffic_zone,
        nullif(trim(station_raw), '') as traffic_police_station,

        try_to_number(y2021_fatal_raw) as y2021_fatal_accidents,
        try_to_number(y2021_killed_raw) as y2021_persons_killed,
        try_to_number(y2021_non_fatal_raw) as y2021_non_fatal_accidents,
        try_to_number(y2021_injured_raw) as y2021_persons_injured,
        try_to_number(y2021_total_cases_raw) as y2021_total_accident_cases,

        try_to_number(y2022_fatal_raw) as y2022_fatal_accidents,
        try_to_number(y2022_killed_raw) as y2022_persons_killed,
        try_to_number(y2022_non_fatal_raw) as y2022_non_fatal_accidents,
        try_to_number(y2022_injured_raw) as y2022_persons_injured,
        try_to_number(y2022_total_cases_raw) as y2022_total_accident_cases,

        source_filename,
        source_row_number,
        loaded_at

    from raw_accidents

    where upper(trim(station_raw)) <> 'GRAND TOTAL'
      and nullif(trim(station_raw), '') is not null

),

long_format as (

    select
        traffic_zone,
        traffic_police_station,
        2021 as accident_year,
        y2021_fatal_accidents as fatal_accidents,
        y2021_persons_killed as persons_killed,
        y2021_non_fatal_accidents as non_fatal_accidents,
        y2021_persons_injured as persons_injured,
        y2021_total_accident_cases as total_accident_cases,
        source_filename,
        source_row_number,
        loaded_at
    from cleaned

    union all

    select
        traffic_zone,
        traffic_police_station,
        2022,
        y2022_fatal_accidents,
        y2022_persons_killed,
        y2022_non_fatal_accidents,
        y2022_persons_injured,
        y2022_total_accident_cases,
        source_filename,
        source_row_number,
        loaded_at
    from cleaned

),

final as (

    select
        md5(
            concat_ws(
                '|',
                to_varchar(accident_year),
                upper(traffic_police_station)
            )
        ) as station_year_accident_id,

        traffic_zone,
        traffic_police_station,
        accident_year,
        fatal_accidents,
        persons_killed,
        non_fatal_accidents,
        persons_injured,
        total_accident_cases,

        source_filename,
        source_row_number,
        loaded_at

    from long_format

)

select *
from final