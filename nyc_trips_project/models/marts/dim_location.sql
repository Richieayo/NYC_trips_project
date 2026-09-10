With dedup_location as (
    Select
    zone_id as location_id,
    zone_name as zone,
    borough,
    row_number() over (partition by zone_id) as row_num
from {{ source('tlc', 'taxi_zone_geom')}}
)

Select
    location_id,
    zone,
    borough
from dedup_location
where row_num = 1

