{{ config(materialized = 'table') }}

with findings as (

    select
        column1::number as finding_order,
        column2::number as dashboard_page_number,
        column3::varchar as dashboard_page,
        column4::varchar as finding_id,
        column5::varchar as finding_title,
        column6::varchar as finding_statement,
        column7::number(38, 2) as primary_metric_value,
        column8::varchar as primary_metric_unit,
        column9::varchar as reporting_period,
        column10::varchar as source_model,
        column11::varchar as evidence_type,
        column12::varchar as limitation_note

    from values

        (
            1,
            1,
            'Bengaluru Mobility Overview',
            'registered_vehicle_scale',
            'Bengaluru has more than 12.59 million registered vehicles',
            'Registered vehicles reached 12.59 million in FY 2025–26. Two-wheelers accounted for approximately 8.60 million vehicles and cars accounted for approximately 2.48 million.',
            12594899,
            'registered vehicles',
            'FY 2025–26',
            'mart_city_kpi_catalog',
            'Descriptive KPI',
            'Registration totals do not represent the number of vehicles operating on the road each day.'
        ),

        (
            2,
            1,
            'Bengaluru Mobility Overview',
            'metro_network_activity',
            'The Metro dataset represents 83 stations',
            'The September 2025 Metro dataset represents 83 stations and records approximately 21.67 million passenger entries plus exits.',
            21667826,
            'entries plus exits',
            'September 2025',
            'mart_city_kpi_catalog',
            'Descriptive KPI',
            'Entries plus exits are passenger movements, not unique passengers. Station count refers to stations represented in the dataset.'
        ),

        (
            3,
            2,
            'Commute Burden and Metro Demand',
            'highest_area_commute_burden',
            'Koramangala had the highest observed area-level commute burden',
            'Koramangala ranked first in both the full and balanced samples, with a balanced average travel-time index of 1.467 across 119 common comparison dates.',
            1.467,
            'balanced average travel-time index',
            '2022 to August 2024',
            'mart_area_commute_burden_balanced',
            'Balanced descriptive comparison',
            'The traffic dataset covers eight selected areas and does not represent every Bengaluru neighbourhood.'
        ),

        (
            4,
            2,
            'Commute Burden and Metro Demand',
            'highest_road_commute_burden',
            'Sony World Junction had the highest observed road-level burden',
            'Sony World Junction ranked first among the 16 observed road and intersection pairs, with an average travel-time index of 1.470 and an estimated 46.96 percent additional travel-time burden.',
            1.470,
            'average travel-time index',
            '2022 to August 2024',
            'mart_road_commute_burden',
            'Descriptive ranking',
            'The travel-time index is capped at 1.5 in the source and should not be treated as an unrestricted continuous measure.'
        ),

        (
            5,
            2,
            'Commute Burden and Metro Demand',
            'rain_traffic_difference',
            'Rain produced little difference in the traffic dataset',
            'Average speed was 39.46 km/h during rainy observations and 39.42 km/h during non-rain observations. Other traffic measures also showed only small average differences.',
            0.04,
            'km/h rainy-minus-dry speed difference',
            '2022 to August 2024',
            'mart_rain_traffic_summary',
            'Cross-dataset descriptive comparison',
            'The result is an association and may reflect the construction and coverage of the traffic dataset.'
        ),

        (
            6,
            3,
            'Air Quality and Commuter Exposure',
            'city_pm25_summary',
            'Weighted daily PM2.5 averaged 30.49 micrograms per cubic metre',
            'Across valid monitoring station-days, weighted average daily PM2.5 was 30.49 micrograms per cubic metre and 5.73 percent of valid station-days exceeded the selected threshold.',
            30.49,
            'micrograms per cubic metre',
            '2024 to 2025',
            'mart_city_kpi_catalog',
            'Coverage-weighted descriptive KPI',
            'This is an average concentration. Pollution concentrations must not be summed across monitoring stations.'
        ),

        (
            7,
            3,
            'Air Quality and Commuter Exposure',
            'rainfall_particulate_relationship',
            'Particulate pollution was lower on rainy dates',
            'Average city-level PM2.5 declined from 40.17 micrograms per cubic metre on dry dates to 21.13 on dates receiving more than 7.5 mm of precipitation, a difference of 47.40 percent.',
            -47.40,
            'percent difference versus dry dates',
            '2024 to 2025',
            'mart_weather_air_quality_summary',
            'Cross-dataset descriptive comparison',
            'This association does not prove that rainfall caused the reduction because seasonality, wind and emissions may also influence pollution.'
        ),

        (
            8,
            3,
            'Air Quality and Commuter Exposure',
            'pm25_weather_correlations',
            'Humidity had the strongest observed PM2.5 weather correlation',
            'PM2.5 correlation was -0.395 with humidity, -0.332 with wind, -0.255 with precipitation and -0.043 with temperature.',
            -0.395,
            'humidity-PM2.5 correlation',
            '2024 to 2025',
            'mart_weather_air_quality_summary',
            'Pearson correlation',
            'Correlation measures linear association and does not control for season, emissions or other confounding variables.'
        ),

        (
            9,
            3,
            'Air Quality and Commuter Exposure',
            'pm10_weather_correlations',
            'PM10 was more weather-sensitive than NO2',
            'PM10 had a -0.536 correlation with humidity and a -0.329 correlation with precipitation. NO2 had almost no precipitation relationship, with a correlation of 0.005.',
            -0.536,
            'humidity-PM10 correlation',
            '2024 to 2025',
            'mart_weather_air_quality_summary',
            'Pearson correlation',
            'Weather relationships may differ by pollutant and do not establish causal effects.'
        ),

        (
            10,
            3,
            'Air Quality and Commuter Exposure',
            'evening_commuter_exposure',
            'Weekday evening peak had the highest combined commuter-exposure proxy',
            'Across complete fixed-panel hours, weekday evening peak periods averaged approximately 63,883.66 passenger movements and a passenger-weighted PM2.5 concentration of 18.99 micrograms per cubic metre.',
            18.99,
            'passenger-weighted PM2.5',
            'September 2025',
            'mart_commuter_exposure_fixed_panel_summary',
            'Cross-dataset exposure proxy',
            'The metric represents coincident passenger activity and ambient monitoring data; it is not an individual exposure or health-impact measurement.'
        ),

        (
            11,
            4,
            'Transport Growth, Safety and Sustainability',
            'vehicle_bmtc_growth_gap',
            'Registered vehicles grew faster than BMTC schedules',
            'From FY 2021–22 to FY 2025–26, registered vehicles increased by 21 percent while BMTC schedules increased by 14.53 percent.',
            6.47,
            'percentage-point cumulative growth difference',
            'FY 2021–22 to FY 2025–26',
            'mart_public_transport_vehicle_pressure_yearly',
            'Cross-dataset indexed comparison',
            'The comparison does not measure route coverage, passenger capacity, service frequency by corridor or actual vehicle usage.'
        ),

        (
            12,
            4,
            'Transport Growth, Safety and Sustainability',
            'vehicles_per_bmtc_schedule',
            'Relative public-transport supply improved in FY 2025–26',
            'Registered vehicles per BMTC schedule increased from 1,898 in FY 2021–22 to 2,104 in FY 2024–25 before improving to 2,005 in FY 2025–26.',
            2005.24,
            'registered vehicles per BMTC schedule',
            'FY 2021–22 to FY 2025–26',
            'mart_public_transport_vehicle_pressure_yearly',
            'Cross-dataset ratio',
            'This ratio is a system-level pressure indicator and not a measure of individual service quality.'
        ),

        (
            13,
            4,
            'Transport Growth, Safety and Sustainability',
            'bmtc_service_recovery',
            'BMTC service supply recovered beyond its pre-pandemic level',
            'BMTC operated 6,281 schedules and 4,439.54 lakh service kilometres in FY 2025–26, compared with 6,159 schedules and 4,065.51 lakh kilometres in FY 2019–20.',
            6281,
            'schedules operated',
            'FY 2019–20 versus FY 2025–26',
            'mart_bmtc_operational_recovery',
            'Longitudinal descriptive comparison',
            'Service supply does not by itself measure ridership, accessibility, crowding or service quality.'
        ),

        (
            14,
            4,
            'Transport Growth, Safety and Sustainability',
            'bmtc_breakdown_anomaly',
            'Reported BMTC breakdowns increased sharply in FY 2025–26',
            'Reported breakdowns increased from 645 in FY 2024–25 to 4,519 in FY 2025–26, while the reported breakdown rate increased from 0.02 to 0.10 per 10,000 kilometres.',
            4519,
            'reported breakdowns',
            'FY 2024–25 to FY 2025–26',
            'mart_bmtc_reliability_trends',
            'Source-validated anomaly',
            'The figures reconcile mathematically, but the source does not establish whether the increase reflects operational deterioration or a reporting-method change.'
        ),

        (
            15,
            4,
            'Transport Growth, Safety and Sustainability',
            'road_safety_2022_change',
            'Road-accident cases increased again in 2022',
            'Reported road-accident cases increased by 19.06 percent in 2022 to 3,823 cases, with 771 persons killed and 3,218 persons injured.',
            19.06,
            'year-over-year accident-case increase percent',
            'Calendar year 2022',
            'mart_road_safety_city_yearly',
            'Annual descriptive trend',
            'The source covers reported police-station-level accidents and may not capture unreported events.'
        ),

        (
            16,
            4,
            'Transport Growth, Safety and Sustainability',
            'enforcement_automation',
            'Traffic enforcement became highly automated',
            'Automation accounted for 87.83 percent of reported enforcement cases in 2025. Total cases declined by 15.69 percent while total fine collections increased by 204.04 percent from the preceding year.',
            87.83,
            'automation case share percent',
            'Calendar year 2025',
            'mart_traffic_enforcement_yearly',
            'Annual descriptive trend',
            'Changes in fines can reflect penalties, collection practices, offence composition and reporting differences, not only enforcement intensity.'
        ),

        (
            17,
            4,
            'Transport Growth, Safety and Sustainability',
            'leading_traffic_offence',
            'Helmet violations were the largest reported offence category in 2025',
            'Riding without a helmet accounted for 2,033,259 reported cases in 2025, representing 29.09 percent of categorised Motor Vehicles Act offences.',
            29.09,
            'percent of categorised offences',
            'Calendar year 2025',
            'mart_mv_act_offence_category_yearly',
            'Offence-category ranking',
            'The result describes enforcement records and should not be interpreted as the underlying prevalence of unsafe behaviour.'
        )

),

final as (

    select
        finding_order,
        dashboard_page_number,
        dashboard_page,
        finding_id,
        finding_title,
        finding_statement,
        primary_metric_value,
        primary_metric_unit,
        reporting_period,
        source_model,
        evidence_type,
        limitation_note,
        '2026-09-17'::date as finding_snapshot_date,
        current_timestamp() as model_built_at

    from findings

)

select *
from final
order by dashboard_page_number, finding_order