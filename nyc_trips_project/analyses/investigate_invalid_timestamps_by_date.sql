

select
    date(pickup_datetime) as pickup_date,
    count(*) as invalid_count
from {{ ref('int_trips_unioned') }}
where dropoff_datetime < pickup_datetime
group by pickup_date
order by invalid_count desc
