{{ config(
    materialized = 'view'
) }}

with raw_weather as (

    select *
    from {{ source('raw_bangalore', 'daily_weather') }}

),

cleaned as (

    select
        try_to_date(
            concat(
                trim(year_raw),
                '-',
                lpad(trim(month_raw), 2, '0'),
                '-',
                lpad(trim(day_raw), 2, '0')
            )
        ) as weather_date,

        nullif(
            try_to_double(temperature_2m_raw),
            -999.0
        ) as temperature_2m_c,

        nullif(
            try_to_double(relative_humidity_2m_raw),
            -999.0
        ) as relative_humidity_2m_pct,

        nullif(
            try_to_double(precipitation_raw),
            -999.0
        ) as precipitation_mm,

        nullif(
            try_to_double(wind_speed_2m_raw),
            -999.0
        ) as wind_speed_2m,

        source_filename,
        source_row_number,
        loaded_at

    from raw_weather

),

final as (

    select
        md5(to_varchar(weather_date)) as weather_record_id,
        *

    from cleaned

    where weather_date is not null

)

select *
from final