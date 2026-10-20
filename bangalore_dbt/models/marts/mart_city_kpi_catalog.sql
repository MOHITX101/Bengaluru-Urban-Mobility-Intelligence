{{ config(materialized = 'table') }}

with metro as (

    select
        count(distinct station_code) as station_count,
        sum(total_passenger_activity) as total_passenger_activity,
        max(last_observation_date) as as_of_date
    from {{ ref('mart_metro_station_summary') }}

),

air_quality as (

    select
        count(distinct station_id) as monitoring_station_count,

        round(
            sum(avg_valid_daily_pm25_ug_m3 * valid_pm25_days)
            / nullif(sum(valid_pm25_days), 0),
            2
        ) as weighted_avg_daily_pm25,

        sum(pm25_exceedance_days) as pm25_exceedance_station_days,

        round(
            100.0 * sum(pm25_exceedance_days)
            / nullif(sum(valid_pm25_days), 0),
            2
        ) as pm25_exceedance_rate_pct,

        max(last_observation_date) as as_of_date

    from {{ ref('mart_air_quality_station_summary') }}

),

latest_vehicle_total as (

    select
        fiscal_year,
        snapshot_date,
        closing_registered_vehicles

    from {{ ref('mart_vehicle_registration_city_yearly') }}

    qualify row_number() over (
        order by fiscal_year_start desc
    ) = 1

),

latest_cars as (

    select
        fiscal_year,
        snapshot_date,
        closing_registered_vehicles

    from {{ ref('mart_vehicle_type_yearly') }}

    where lower(trim(vehicle_type)) = 'cars'

    qualify row_number() over (
        order by fiscal_year_start desc
    ) = 1

),

latest_two_wheelers as (

    select
        fiscal_year,
        snapshot_date,
        closing_registered_vehicles

    from {{ ref('mart_vehicle_type_yearly') }}

    where lower(trim(vehicle_type)) = 'two wheelers'

    qualify row_number() over (
        order by fiscal_year_start desc
    ) = 1

),

latest_bmtc as (

    select
        fiscal_year,
        fiscal_year_end_date,
        vehicles_held,
        schedules_operated

    from {{ ref('mart_bmtc_yearly_performance') }}

    qualify row_number() over (
        order by fiscal_year_start desc
    ) = 1

),

latest_road_safety as (

    select
        accident_year,
        total_accident_cases,
        persons_killed,
        persons_injured

    from {{ ref('mart_road_safety_city_yearly') }}

    qualify row_number() over (
        order by accident_year desc
    ) = 1

),

kpis as (

    select
        1 as display_order,
        'Public Transport' as kpi_category,
        'metro_stations_observed' as kpi_id,
        'Metro stations represented' as kpi_name,
        station_count::number(38, 4) as metric_value,
        'stations' as metric_unit,
        'September 2025 dataset' as reporting_period,
        as_of_date,
        'mart_metro_station_summary' as source_model,
        'Counts stations represented in the supplied September Metro dataset; it is not necessarily the official operational network total.'
            as interpretation_note
    from metro

    union all

    select
        2,
        'Public Transport',
        'metro_passenger_activity',
        'Metro passenger activity',
        total_passenger_activity::number(38, 4),
        'entries plus exits',
        'September 2025 dataset',
        as_of_date,
        'mart_metro_station_summary',
        'Sum of station-level hourly entry and exit activity for the observed period.'
    from metro

    union all

    select
        3,
        'Air Quality',
        'air_quality_monitoring_stations',
        'Air-quality monitoring stations',
        monitoring_station_count::number(38, 4),
        'stations',
        'Available monitoring period',
        as_of_date,
        'mart_air_quality_station_summary',
        'Counts monitoring stations represented in the source data.'
    from air_quality

    union all

    select
        4,
        'Air Quality',
        'weighted_average_daily_pm25',
        'Weighted average daily PM2.5',
        weighted_avg_daily_pm25::number(38, 4),
        'micrograms per cubic metre',
        'Available valid station-days',
        as_of_date,
        'mart_air_quality_station_summary',
        'Weighted by valid PM2.5 observation days. Pollution concentrations are averaged and must not be summed across stations.'
    from air_quality

    union all

    select
        5,
        'Air Quality',
        'pm25_exceedance_station_days',
        'PM2.5 exceedance station-days',
        pm25_exceedance_station_days::number(38, 4),
        'station-days',
        'Available valid station-days',
        as_of_date,
        'mart_air_quality_station_summary',
        'One exceedance at one station on one date equals one station-day; this is not a count of unique citywide dates.'
    from air_quality

    union all

    select
        6,
        'Air Quality',
        'pm25_exceedance_rate',
        'PM2.5 exceedance rate',
        pm25_exceedance_rate_pct::number(38, 4),
        'percent of valid station-days',
        'Available valid station-days',
        as_of_date,
        'mart_air_quality_station_summary',
        'Percentage of valid station-days exceeding the PM2.5 threshold used in the air-quality mart.'
    from air_quality

    union all

    select
        7,
        'Vehicle Registration',
        'total_registered_vehicles',
        'Total registered vehicles',
        closing_registered_vehicles::number(38, 4),
        'vehicles',
        fiscal_year,
        snapshot_date,
        'mart_vehicle_registration_city_yearly',
        'Latest closing vehicle-registration snapshot available in the dataset.'
    from latest_vehicle_total

    union all

    select
        8,
        'Vehicle Registration',
        'registered_cars',
        'Registered cars',
        closing_registered_vehicles::number(38, 4),
        'vehicles',
        fiscal_year,
        snapshot_date,
        'mart_vehicle_type_yearly',
        'Latest closing registration count for the Cars vehicle type.'
    from latest_cars

    union all

    select
        9,
        'Vehicle Registration',
        'registered_two_wheelers',
        'Registered two-wheelers',
        closing_registered_vehicles::number(38, 4),
        'vehicles',
        fiscal_year,
        snapshot_date,
        'mart_vehicle_type_yearly',
        'Latest closing registration count for the Two Wheelers vehicle type.'
    from latest_two_wheelers

    union all

    select
        10,
        'BMTC',
        'bmtc_vehicles_held',
        'BMTC vehicles held',
        vehicles_held::number(38, 4),
        'vehicles',
        fiscal_year,
        fiscal_year_end_date,
        'mart_bmtc_yearly_performance',
        'Latest reported BMTC fleet held in the available financial-year data.'
    from latest_bmtc

    union all

    select
        11,
        'BMTC',
        'bmtc_schedules_operated',
        'BMTC schedules operated',
        schedules_operated::number(38, 4),
        'schedules',
        fiscal_year,
        fiscal_year_end_date,
        'mart_bmtc_yearly_performance',
        'Latest reported number of BMTC schedules operated.'
    from latest_bmtc

    union all

    select
        12,
        'Road Safety',
        'annual_accident_cases',
        'Annual road-accident cases',
        total_accident_cases::number(38, 4),
        'cases',
        accident_year::varchar,
        date_from_parts(accident_year, 12, 31),
        'mart_road_safety_city_yearly',
        'Latest calendar year available in the road-safety dataset.'
    from latest_road_safety

    union all

    select
        13,
        'Road Safety',
        'annual_persons_killed',
        'Persons killed in road accidents',
        persons_killed::number(38, 4),
        'persons',
        accident_year::varchar,
        date_from_parts(accident_year, 12, 31),
        'mart_road_safety_city_yearly',
        'Latest calendar year available; this is a reported count and not a rate.'
    from latest_road_safety

    union all

    select
        14,
        'Road Safety',
        'annual_persons_injured',
        'Persons injured in road accidents',
        persons_injured::number(38, 4),
        'persons',
        accident_year::varchar,
        date_from_parts(accident_year, 12, 31),
        'mart_road_safety_city_yearly',
        'Latest calendar year available; this is a reported count and not a rate.'
    from latest_road_safety

)

select
    display_order,
    kpi_category,
    kpi_id,
    kpi_name,
    metric_value,
    metric_unit,
    reporting_period,
    as_of_date,
    source_model,
    interpretation_note
from kpis
order by display_order