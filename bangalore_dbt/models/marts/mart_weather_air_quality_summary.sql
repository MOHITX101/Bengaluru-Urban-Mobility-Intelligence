{{ config(materialized = 'table') }}

with daily as (

    select *
    from {{ ref('mart_city_air_quality_weather_daily') }}

),

precipitation_summary as (

    select
        case
            when precipitation_band = 'No rain' then 1
            when precipitation_band = 'More than 0 to 2.5 mm' then 2
            when precipitation_band = 'More than 2.5 to 7.5 mm' then 3
            when precipitation_band = 'More than 7.5 mm' then 4
            else 5
        end as precipitation_band_order,

        precipitation_band,

        count(*) as observed_dates,

        count_if(is_high_coverage_pm25_date)
            as valid_pm25_dates,

        count_if(is_high_coverage_pm10_date)
            as valid_pm10_dates,

        count_if(is_high_coverage_no2_date)
            as valid_no2_dates,

        round(avg(precipitation_mm), 2)
            as avg_precipitation_mm,

        round(avg(temperature_2m_c), 2)
            as avg_temperature_2m_c,

        round(avg(relative_humidity_2m_pct), 2)
            as avg_relative_humidity_2m_pct,

        round(avg(wind_speed_2m), 2)
            as avg_wind_speed_2m,

        round(
            avg(
                case
                    when is_high_coverage_pm25_date
                        then city_avg_pm25_ug_m3
                end
            ),
            2
        ) as avg_city_pm25_ug_m3,

        round(
            median(
                case
                    when is_high_coverage_pm25_date
                        then city_avg_pm25_ug_m3
                end
            ),
            2
        ) as median_city_pm25_ug_m3,

        round(
            avg(
                case
                    when is_high_coverage_pm10_date
                        then city_avg_pm10_ug_m3
                end
            ),
            2
        ) as avg_city_pm10_ug_m3,

        round(
            avg(
                case
                    when is_high_coverage_no2_date
                        then city_avg_no2_ug_m3
                end
            ),
            2
        ) as avg_city_no2_ug_m3,

        count_if(
            is_high_coverage_pm25_date
            and pm25_exceeding_stations > 0
        ) as pm25_any_exceedance_dates,

        round(
            100.0
            * count_if(
                is_high_coverage_pm25_date
                and pm25_exceeding_stations > 0
            )
            / nullif(
                count_if(is_high_coverage_pm25_date),
                0
            ),
            2
        ) as pm25_any_exceedance_date_pct

    from daily

    group by
        precipitation_band_order,
        precipitation_band

),

summary_with_baseline as (

    select
        *,

        max(
            case
                when precipitation_band = 'No rain'
                    then avg_city_pm25_ug_m3
            end
        ) over () as no_rain_avg_pm25_ug_m3,

        max(
            case
                when precipitation_band = 'No rain'
                    then avg_city_pm10_ug_m3
            end
        ) over () as no_rain_avg_pm10_ug_m3,

        max(
            case
                when precipitation_band = 'No rain'
                    then avg_city_no2_ug_m3
            end
        ) over () as no_rain_avg_no2_ug_m3

    from precipitation_summary

),

weather_correlations as (

    select
        round(
            corr(
                case
                    when is_high_coverage_pm25_date
                        then temperature_2m_c
                end,
                case
                    when is_high_coverage_pm25_date
                        then city_avg_pm25_ug_m3
                end
            ),
            3
        ) as temperature_pm25_correlation,

        round(
            corr(
                case
                    when is_high_coverage_pm25_date
                        then relative_humidity_2m_pct
                end,
                case
                    when is_high_coverage_pm25_date
                        then city_avg_pm25_ug_m3
                end
            ),
            3
        ) as humidity_pm25_correlation,

        round(
            corr(
                case
                    when is_high_coverage_pm25_date
                        then precipitation_mm
                end,
                case
                    when is_high_coverage_pm25_date
                        then city_avg_pm25_ug_m3
                end
            ),
            3
        ) as precipitation_pm25_correlation,

        round(
            corr(
                case
                    when is_high_coverage_pm25_date
                        then wind_speed_2m
                end,
                case
                    when is_high_coverage_pm25_date
                        then city_avg_pm25_ug_m3
                end
            ),
            3
        ) as wind_pm25_correlation,

        round(
            corr(
                case
                    when is_high_coverage_pm10_date
                        then temperature_2m_c
                end,
                case
                    when is_high_coverage_pm10_date
                        then city_avg_pm10_ug_m3
                end
            ),
            3
        ) as temperature_pm10_correlation,

        round(
            corr(
                case
                    when is_high_coverage_pm10_date
                        then relative_humidity_2m_pct
                end,
                case
                    when is_high_coverage_pm10_date
                        then city_avg_pm10_ug_m3
                end
            ),
            3
        ) as humidity_pm10_correlation,

        round(
            corr(
                case
                    when is_high_coverage_pm10_date
                        then precipitation_mm
                end,
                case
                    when is_high_coverage_pm10_date
                        then city_avg_pm10_ug_m3
                end
            ),
            3
        ) as precipitation_pm10_correlation,

        round(
            corr(
                case
                    when is_high_coverage_pm10_date
                        then wind_speed_2m
                end,
                case
                    when is_high_coverage_pm10_date
                        then city_avg_pm10_ug_m3
                end
            ),
            3
        ) as wind_pm10_correlation,

        round(
            corr(
                case
                    when is_high_coverage_no2_date
                        then temperature_2m_c
                end,
                case
                    when is_high_coverage_no2_date
                        then city_avg_no2_ug_m3
                end
            ),
            3
        ) as temperature_no2_correlation,

        round(
            corr(
                case
                    when is_high_coverage_no2_date
                        then relative_humidity_2m_pct
                end,
                case
                    when is_high_coverage_no2_date
                        then city_avg_no2_ug_m3
                end
            ),
            3
        ) as humidity_no2_correlation,

        round(
            corr(
                case
                    when is_high_coverage_no2_date
                        then precipitation_mm
                end,
                case
                    when is_high_coverage_no2_date
                        then city_avg_no2_ug_m3
                end
            ),
            3
        ) as precipitation_no2_correlation,

        round(
            corr(
                case
                    when is_high_coverage_no2_date
                        then wind_speed_2m
                end,
                case
                    when is_high_coverage_no2_date
                        then city_avg_no2_ug_m3
                end
            ),
            3
        ) as wind_no2_correlation

    from daily

),

final as (

    select
        summary.precipitation_band_order,
        summary.precipitation_band,
        summary.observed_dates,

        summary.valid_pm25_dates,
        summary.valid_pm10_dates,
        summary.valid_no2_dates,

        summary.avg_precipitation_mm,
        summary.avg_temperature_2m_c,
        summary.avg_relative_humidity_2m_pct,
        summary.avg_wind_speed_2m,

        summary.avg_city_pm25_ug_m3,
        summary.median_city_pm25_ug_m3,
        summary.avg_city_pm10_ug_m3,
        summary.avg_city_no2_ug_m3,

        summary.pm25_any_exceedance_dates,
        summary.pm25_any_exceedance_date_pct,

        round(
            summary.avg_city_pm25_ug_m3
            - summary.no_rain_avg_pm25_ug_m3,
            2
        ) as pm25_difference_vs_no_rain,

        round(
            100.0
            * (
                summary.avg_city_pm25_ug_m3
                - summary.no_rain_avg_pm25_ug_m3
            )
            / nullif(summary.no_rain_avg_pm25_ug_m3, 0),
            2
        ) as pm25_pct_difference_vs_no_rain,

        round(
            summary.avg_city_pm10_ug_m3
            - summary.no_rain_avg_pm10_ug_m3,
            2
        ) as pm10_difference_vs_no_rain,

        round(
            100.0
            * (
                summary.avg_city_pm10_ug_m3
                - summary.no_rain_avg_pm10_ug_m3
            )
            / nullif(summary.no_rain_avg_pm10_ug_m3, 0),
            2
        ) as pm10_pct_difference_vs_no_rain,

        round(
            summary.avg_city_no2_ug_m3
            - summary.no_rain_avg_no2_ug_m3,
            2
        ) as no2_difference_vs_no_rain,

        round(
            100.0
            * (
                summary.avg_city_no2_ug_m3
                - summary.no_rain_avg_no2_ug_m3
            )
            / nullif(summary.no_rain_avg_no2_ug_m3, 0),
            2
        ) as no2_pct_difference_vs_no_rain,

        correlations.temperature_pm25_correlation,
        correlations.humidity_pm25_correlation,
        correlations.precipitation_pm25_correlation,
        correlations.wind_pm25_correlation,

        correlations.temperature_pm10_correlation,
        correlations.humidity_pm10_correlation,
        correlations.precipitation_pm10_correlation,
        correlations.wind_pm10_correlation,

        correlations.temperature_no2_correlation,
        correlations.humidity_no2_correlation,
        correlations.precipitation_no2_correlation,
        correlations.wind_no2_correlation

    from summary_with_baseline as summary
    cross join weather_correlations as correlations

)

select *
from final
order by precipitation_band_order