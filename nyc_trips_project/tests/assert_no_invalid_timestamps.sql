-- Hard rule: a trip's dropoff can never occur before its pickup.
-- This is a logical impossibility,
-- if this test ever returns rows, the pipeline should stop and be investigated,
-- not just flagged for later review.

-- 15000 count is used cause the total count is 13510, if new data is introduced and total count climbs above 13510 then the engineer should be notified
{{
  config(
    severity='error',
    warn_if='>0',
    error_if='>15000'     
  )
}}


Select
      trip_id,
      taxi_type,
      pickup_datetime,
      dropoff_datetime,
    from {{ ref('int_trips_unioned') }}
    where dropoff_datetime < pickup_datetime
