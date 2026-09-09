-- analyses/investigate_vendor6_timestamp_pattern.sql

select
    extract(hour from pickup_datetime) as pickup_hour,
    count(*) as invalid_count
from {{ ref('int_trips_unioned') }}
where dropoff_datetime < pickup_datetime
  and vendor_id = '6'
group by pickup_hour
order by invalid_count desc