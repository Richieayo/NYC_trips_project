--Select 
    --pickup_location_id,
    --pickup_borough,
    --count(*)

--    *
--from {{ ref("int_trips_unioned")}}
--where pickup_location_id = "105"
--order by trip_id
--group by pickup_location_id, pickup_borough

Select 
    *
from {{ ref("dim_location")}}
where location_id = "105" 
or location_id = "264" 
or location_id = "57" 
or location_id = "265"


--Select
--pickup_location_id,
--count(pickup_location_id)
--from {{ ref("fct_trip_metrics")}}
--where pickup_borough is null
--group by pickup_location_id




