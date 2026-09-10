with date_spine as (
    {{ dbt_utils.date_spine (
        datepart="day",
        start_date="cast('2022-01-01' as date)",
        end_date="cast('2023-01-01' as date)"
    )}}
)

Select
    date_day as date_key,
    extract(year from date_day) as year,
    extract(month from date_day) as month,
    extract(day from date_day) as day_of_month,
    extract(dayofweek from date_day) as day_of_week,
    format_date('%A', date_day) as day_name,
    format_date('%B', date_day) as month_name,

    case

    when extract(dayofweek from date_day) in (1,7) then true
    else false
    end as is_weekend
from date_spine