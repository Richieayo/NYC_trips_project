{{
    config(
        materialized='incremental',
        unique_key='trip_id',
        partition_by={'field':'pickup_date', 'data_type':'date'},
        cluster_by=['pickup_borough']
    )
}}


with base as (
    select 
        trip_id,
        taxi_type,
        vendor_id,
        cast(pickup_datetime as date) as pickup_date,
        pickup_location_id,
        dropoff_location_id,
        passenger_count,
        fare_amount,
        total_amount,
        payment_type,
        is_suspicious_trip

    from {{ ref('int_trips_unioned') }}
    where is_invalid_timestamps = false
    and pickup_location_id not in ("105", "264", "57", "265")
    and dropoff_location_id not in ("105", "264", "57", "265")          ------Made an error with these two (pickup and dropoff location, 
                                                                    ----------I should have checked the relationship with the staging tables at the staging level)
                                                                    -------Always bring all source tables in staging and test for relationship where necessary
                                                                    --------Relationship test between Location and the two statging tables
    {% if is_incremental() %}
    and pickup_date >= (select max(pickup_date) from {{ this }})
    {% endif %}
),

netted as (
    select 
        trip_id,
        taxi_type,
        max(vendor_id)            as vendor_id,
        max(pickup_date)          as pickup_date,
        max(pickup_location_id)   as pickup_location_id,
        max(dropoff_location_id)  as dropoff_location_id,
        max(passenger_count)      as passenger_count,
        sum(fare_amount)          as fare_amount,
        sum(total_amount)         as total_amount,
        max(payment_type)         as payment_type,
        max(is_suspicious_trip)   as is_suspicious_trip
    from base 
    group by trip_id, taxi_type
)

select
    n.trip_id,
    n.taxi_type,
    n.pickup_date,
    n.pickup_location_id,
    n.dropoff_location_id,
    pu.borough                     as pickup_borough,
    dr.borough                     as dropoff_borough,
    n.passenger_count,
    n.fare_amount,
    n.total_amount,
    n.is_suspicious_trip,
    case when n.payment_type = '2' then 1 else 0 end as is_cash,
    case n.payment_type
        when '0' then 'Flex Fare'
        when '1' then 'Credit Card'
        when '2' then 'Cash'
        when '3' then 'No Charge'
        when '4' then 'Dispute'
        when '5' then 'Unknown'
        when '6' then 'Voided'
        else 'Unrecognized'
    end as payment_type_label

from netted n
left join {{ ref('dim_location') }} pu on n.pickup_location_id = pu.location_id
left join {{ ref('dim_location') }} dr on n.dropoff_location_id = dr.location_id