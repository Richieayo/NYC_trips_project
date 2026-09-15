
select
    trip_id,
    taxi_type,
    vendor_id,
    pickup_datetime,
    dropoff_datetime,
    timestamp_diff(pickup_datetime, dropoff_datetime, minute) as minutes_reversed,
    trip_distance,
    fare_amount
from {{ ref('int_trips_unioned') }}
where dropoff_datetime < pickup_datetime
order by minutes_reversed desc

