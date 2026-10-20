{{ config(
    materialized = 'view'
) }}

with raw_air_quality as (

    select *
    from {{ source('raw_bangalore', 'air_quality') }}

),

typed as (

    select
        nullif(trim(station_id), '') as station_id,
        nullif(trim(state_name), '') as state_name,
        nullif(trim(city_name), '') as city_name,
        nullif(trim(station_name), '') as station_name,

        coalesce(
            try_to_timestamp_tz(
                timestamp_raw,
                'YYYY-MM-DD"T"HH24:MI:SS.FF6TZHTZM'
            ),
            try_to_timestamp_tz(timestamp_raw)
        ) as observed_at_utc,

        try_to_double(pm25_raw) as pm25_ug_m3,
        try_to_double(pm10_raw) as pm10_ug_m3,
        try_to_double(no_raw) as no_ug_m3,
        try_to_double(no2_raw) as no2_ug_m3,
        try_to_double(nox_raw) as nox_ppb,
        try_to_double(nh3_raw) as nh3_ug_m3,
        try_to_double(so2_raw) as so2_ug_m3,
        try_to_double(co_raw) as co_mg_m3,
        try_to_double(ozone_raw) as ozone_ug_m3,
        try_to_double(benzene_raw) as benzene_ug_m3,
        try_to_double(toluene_raw) as toluene_ug_m3,
        try_to_double(xylene_raw) as xylene_ug_m3,
        try_to_double(o_xylene_raw) as o_xylene_ug_m3,
        try_to_double(ethyl_benzene_raw) as ethyl_benzene_ug_m3,
        try_to_double(mp_xylene_raw) as mp_xylene_ug_m3,

        try_to_double(air_temperature_raw) as station_temperature_c,
        try_to_double(relative_humidity_raw) as station_relative_humidity_pct,
        try_to_double(wind_speed_raw) as station_wind_speed_m_s,
        try_to_double(wind_direction_raw) as station_wind_direction_degrees,
        try_to_double(rainfall_raw) as station_rainfall_mm,
        try_to_double(total_rainfall_raw) as station_total_rainfall_mm,
        try_to_double(solar_radiation_raw) as solar_radiation_w_m2,
        try_to_double(barometric_pressure_raw) as barometric_pressure_mmhg,
        try_to_double(vertical_wind_speed_raw) as vertical_wind_speed_m_s,

        source_filename,
        source_row_number,
        loaded_at

    from raw_air_quality

),

localized as (

    select
        *,
        convert_timezone(
            'Asia/Kolkata',
            observed_at_utc
        ) as observed_at_ist

    from typed

    where observed_at_utc is not null
      and station_id is not null
      and station_name is not null

),

final as (

    select
        md5(
            concat_ws(
                '|',
                upper(station_id),
                to_varchar(observed_at_utc)
            )
        ) as air_quality_observation_id,

        station_id,
        state_name,
        city_name,
        station_name,
        trim(split_part(station_name, ',', 1)) as station_short_name,

        observed_at_utc,
        observed_at_ist,
        observed_at_ist::date as observation_date_ist,
        hour(observed_at_ist) as observation_hour_ist,

        pm25_ug_m3,
        pm10_ug_m3,
        no_ug_m3,
        no2_ug_m3,
        nox_ppb,
        nh3_ug_m3,
        so2_ug_m3,
        co_mg_m3,
        ozone_ug_m3,
        benzene_ug_m3,
        toluene_ug_m3,
        xylene_ug_m3,
        o_xylene_ug_m3,
        ethyl_benzene_ug_m3,
        mp_xylene_ug_m3,

        station_temperature_c,
        station_relative_humidity_pct,
        station_wind_speed_m_s,
        station_wind_direction_degrees,
        station_rainfall_mm,
        station_total_rainfall_mm,
        solar_radiation_w_m2,
        barometric_pressure_mmhg,
        vertical_wind_speed_m_s,

        source_filename,
        source_row_number,
        loaded_at

    from localized

)

select *
from final