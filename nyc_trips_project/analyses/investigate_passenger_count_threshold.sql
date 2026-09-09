select passenger_count, count(*) as trip_count
from {{ref('int_trips_unioned')}}
group by passenger_count
order by passenger_count