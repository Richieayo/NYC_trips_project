---checks if the passenger_count column has any 0 value and counts them by vendor_id, checking if the data gap is more prevalent in one vendor's data than the other

select vendor_id, taxi_type, count(*) as zero_passenger_count
from {{ref('int_trips_unioned')}}
where passenger_count = 0
group by vendor_id, taxi_type
order by zero_passenger_count desc