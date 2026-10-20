{{ config(
    materialized = 'view'
) }}

with raw_accidents as (

    select *
    from {{ source('raw_bangalore', 'accidents_2018_2020') }}

),

cleaned as (

    select
        nullif(initcap(trim(zone_raw)), '') as traffic_zone,
        nullif(trim(station_raw), '') as traffic_police_station,

        try_to_number(y2018_fatal_raw) as y2018_fatal_accidents,
        try_to_number(y2018_killed_raw) as y2018_persons_killed,
        try_to_number(y2018_non_fatal_raw) as y2018_non_fatal_accidents,
        try_to_number(y2018_injured_raw) as y2018_persons_injured,
        try_to_number(y2018_total_cases_raw) as y2018_total_accident_cases,

        try_to_number(y2019_fatal_raw) as y2019_fatal_accidents,
        try_to_number(y2019_killed_raw) as y2019_persons_killed,
        try_to_number(y2019_non_fatal_raw) as y2019_non_fatal_accidents,
        try_to_number(y2019_injured_raw) as y2019_persons_injured,
        try_to_number(y2019_total_cases_raw) as y2019_total_accident_cases,

        try_to_number(y2020_fatal_raw) as y2020_fatal_accidents,
        try_to_number(y2020_killed_raw) as y2020_persons_killed,
        try_to_number(y2020_non_fatal_raw) as y2020_non_fatal_accidents,
        try_to_number(y2020_injured_raw) as y2020_persons_injured,
        try_to_number(y2020_total_cases_raw) as y2020_total_accident_cases,

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
        2018 as accident_year,
        y2018_fatal_accidents as fatal_accidents,
        y2018_persons_killed as persons_killed,
        y2018_non_fatal_accidents as non_fatal_accidents,
        y2018_persons_injured as persons_injured,
        y2018_total_accident_cases as total_accident_cases,
        source_filename,
        source_row_number,
        loaded_at
    from cleaned

    union all

    select
        traffic_zone,
        traffic_police_station,
        2019,
        y2019_fatal_accidents,
        y2019_persons_killed,
        y2019_non_fatal_accidents,
        y2019_persons_injured,
        y2019_total_accident_cases,
        source_filename,
        source_row_number,
        loaded_at
    from cleaned

    union all

    select
        traffic_zone,
        traffic_police_station,
        2020,
        y2020_fatal_accidents,
        y2020_persons_killed,
        y2020_non_fatal_accidents,
        y2020_persons_injured,
        y2020_total_accident_cases,
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