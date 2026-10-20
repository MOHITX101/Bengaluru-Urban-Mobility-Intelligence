{{ config(
    materialized = 'view'
) }}

with raw_metro as (

    select *
    from {{ source('raw_bangalore', 'metro_station_hourly_september') }}

),

cleaned_wide as (

    select
        try_to_date(business_date_raw) as business_date,
        nullif(trim(station_raw), '') as station_raw,

        nullif(
            trim(split_part(station_raw, '-', 1)),
            ''
        ) as station_code,

        nullif(
            trim(
                regexp_replace(
                    station_raw,
                    '^[^-]+-',
                    ''
                )
            ),
            ''
        ) as station_name,

        h00_raw,
        h01_raw,
        h02_raw,
        h03_raw,
        h04_raw,
        h05_raw,
        h06_raw,
        h07_raw,
        h08_raw,
        h09_raw,
        h10_raw,
        h11_raw,
        h12_raw,
        h13_raw,
        h14_raw,
        h15_raw,
        h16_raw,
        h17_raw,
        h18_raw,
        h19_raw,
        h20_raw,
        h21_raw,
        h22_raw,
        h23_raw,

        try_to_number(total_raw) as reported_daily_total,

        source_filename,
        source_row_number,
        loaded_at

    from raw_metro

    where try_to_date(business_date_raw) is not null
      and nullif(trim(station_raw), '') is not null

),

unpivoted as (

    select
        business_date,
        station_code,
        station_name,

        try_to_number(
            replace(
                replace(hour_column, '_RAW', ''),
                'H',
                ''
            )
        ) as observation_hour,

        try_to_number(passenger_count_raw) as passenger_count,
        reported_daily_total,

        source_filename,
        source_row_number,
        loaded_at

    from cleaned_wide

    unpivot (
        passenger_count_raw for hour_column in (
            h00_raw,
            h01_raw,
            h02_raw,
            h03_raw,
            h04_raw,
            h05_raw,
            h06_raw,
            h07_raw,
            h08_raw,
            h09_raw,
            h10_raw,
            h11_raw,
            h12_raw,
            h13_raw,
            h14_raw,
            h15_raw,
            h16_raw,
            h17_raw,
            h18_raw,
            h19_raw,
            h20_raw,
            h21_raw,
            h22_raw,
            h23_raw
        )
    )

),

final as (

    select
        md5(
            concat_ws(
                '|',
                to_varchar(business_date),
                upper(station_code),
                to_varchar(observation_hour)
            )
        ) as metro_station_hour_id,

        business_date,
        year(business_date) as service_year,
        month(business_date) as service_month,
        dayname(business_date) as service_day_name,

        case
            when dayofweekiso(business_date) in (6, 7)
                then true
            else false
        end as is_weekend,

        station_code,
        station_name,
        observation_hour,

        dateadd(
            hour,
            observation_hour,
            business_date::timestamp_ntz
        ) as hour_start_ist,

        passenger_count,
        reported_daily_total,

        source_filename,
        source_row_number,
        loaded_at

    from unpivoted

    where observation_hour between 0 and 23
      and passenger_count is not null

)

select *
from final