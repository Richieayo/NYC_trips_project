

select
    vendor_id,
    taxi_type,
    count(*) as invalid_count
from {{ ref('int_trips_unioned') }}
where dropoff_datetime < pickup_datetime
group by vendor_id, taxi_type
order by invalid_count desc