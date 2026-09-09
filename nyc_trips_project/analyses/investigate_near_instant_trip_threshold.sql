select 
    timestamp_diff(dropoff_datetime, pickup_datetime, second) as trip_duration_seconds,
    count(*) as trip_count
from ref('int_trips_unioned')
where timestamp_diff(dropoff_datetime, pickup_datetime, second) between 0 and 60
group by trip_duration_seconds
order by trip_duration_seconds