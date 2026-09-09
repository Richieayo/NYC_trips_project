with unioned as (
    select * from {{ ref('stg_yellow_trips')}}
    union all
    select * from {{ ref('stg_green_trips')}}
),

flagged as (
    select
        {{ dbt_utils.generate_surrogate_key([
            'taxi_type',
            'vendor_id',
            'pickup_datetime',
            'pickup_location_id',
            'dropoff_datetime',
            'dropoff_location_id'
        ]) }} as trip_id,
        *,

        case
            when dropoff_datetime < pickup_datetime then true
            else false
        end as is_invalid_timestamps,

        case
            when trip_distance = 0 and fare_amount > 2.50 then true
            else false
        end as is_zero_distance_fare,


        case
            when timestamp_diff(dropoff_datetime, pickup_datetime, second) <= 10 then true
            else false
        end as is_near_instant_trip,


        case
            when fare_amount < 0 then true
            else false  
        end as is_negative_fare,

        -- replace the two separate checks with one combined flag
        case
            when passenger_count is null then true
            when passenger_count = 0 then true
            else false
        end as is_unreliable_passenger_count,

        -- keep this one separate — 565 rows out of 37M is a genuinely rare, real anomaly
        case
            when passenger_count > 6 then true
            else false
        end as is_invalid_passenger_count

        from unioned

)


Select 
    *,
    case
            when count(*) over (partition by trip_id) > 1 then true
            else false
        end as is_refund_pair,

    (
        is_invalid_timestamps 
        or is_zero_distance_fare 
        or is_near_instant_trip
        or is_negative_fare
        or is_unreliable_passenger_count
        or is_invalid_passenger_count
    ) as is_suspicious_trip

from flagged