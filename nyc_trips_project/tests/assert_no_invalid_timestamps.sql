-- Hard rule: a trip's dropoff can never occur before its pickup.
-- This is a logical impossibility,
-- if this test ever returns rows, the pipeline should stop and be investigated,
-- not just flagged for later review.


Select
      trip_id,
      taxi_type,
      pickup_datetime,
      dropoff_datetime,
    from {{ ref('int_trips_unioned') }}
    where dropoff_datetime < pickup_datetime
