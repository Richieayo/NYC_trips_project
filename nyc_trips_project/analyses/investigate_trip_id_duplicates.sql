-- analyses/investigate_trip_id_duplicates.sql

with dupes as (
    select trip_id
    from {{ ref('int_trips_unioned') }}
    group by trip_id
    having count(*) > 1
)

select t.*
from {{ ref('int_trips_unioned') }} t
join dupes d on t.trip_id = d.trip_id
order by t.trip_id
