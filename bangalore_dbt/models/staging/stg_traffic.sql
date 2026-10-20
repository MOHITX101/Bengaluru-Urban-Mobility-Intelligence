{{ config(
    materialized = 'view'
) }}


with raw_traffic as (

    select *
    from {{ source('raw_bangalore', 'traffic') }}

),

cleaned as (

    select
        try_to_date(date_raw)                            as traffic_date,
        nullif(trim(area_name), '')                      as area_name,
        nullif(trim(road_intersection_name), '')         as road_name,

        try_to_number(traffic_volume)                    as traffic_volume,
        try_to_double(average_speed)                     as average_speed_kmph,
        try_to_double(travel_time_index)                 as travel_time_index,
        try_to_double(congestion_level)                  as congestion_level,
        try_to_double(road_capacity_utilization)         as road_capacity_utilization,
        try_to_number(incident_reports)                  as incident_reports,
        try_to_double(environmental_impact)              as environmental_impact,
        try_to_double(public_transport_usage)            as public_transport_usage,
        try_to_double(traffic_signal_compliance)         as traffic_signal_compliance,
        try_to_double(parking_usage)                     as parking_usage,
        try_to_number(pedestrian_cyclist_count)          as pedestrian_cyclist_count,

        nullif(initcap(trim(weather_conditions)), '')    as weather_condition,
        nullif(
            trim(roadwork_construction_activity),
            ''
        )                                                as roadwork_activity,

        source_filename,
        source_row_number,
        loaded_at

    from raw_traffic

),

final as (

    select
        md5(
            concat_ws(
                '|',
                to_varchar(traffic_date),
                upper(area_name),
                upper(road_name)
            )
        ) as traffic_record_id,

        *

    from cleaned

    where traffic_date is not null
      and area_name is not null
      and road_name is not null

)

select *
from final