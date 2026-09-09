-- analyses/investigate_vendor6_invalid_rate_by_hour.sql

with invalid as (
    select
        extract(hour from pickup_datetime) as pickup_hour,
        count(*) as invalid_count
    from {{ ref('int_trips_unioned') }}
    where dropoff_datetime < pickup_datetime
      and vendor_id = '6'
    group by pickup_hour
),

total as (
    select
        extract(hour from pickup_datetime) as pickup_hour,
        count(*) as total_count
    from {{ ref('int_trips_unioned') }}
    where vendor_id = '6'
    group by pickup_hour
)

select
    t.pickup_hour,
    t.total_count,
    coalesce(i.invalid_count, 0) as invalid_count,
    round(coalesce(i.invalid_count, 0) / t.total_count * 100, 4) as invalid_pct
from total t
left join invalid i on t.pickup_hour = i.pickup_hour
order by t.pickup_hour