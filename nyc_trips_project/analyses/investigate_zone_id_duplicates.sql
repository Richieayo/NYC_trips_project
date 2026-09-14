
select location_id, zone, borough, count(*) as row_count
from {{ ref('dim_location') }}
group by location_id, zone, borough
having count(*) > 1
order by row_count desc

