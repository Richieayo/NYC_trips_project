---checks if the passenger_count column has any null values and counts them by vendor_id, checking if the data gap is more prevalent in one vendor's data than the other

select vendor_id, taxi_type, count(*) as null_passenger_count
from {{ref('int_trips_unioned')}}
where passenger_count is null
group by vendor_id, taxi_type
order by null_passenger_count desc