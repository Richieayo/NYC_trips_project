# NYC Taxi Trip Analytics (2022)

A dbt project that builds a trip-level analytics mart from NYC TLC yellow and green taxi trip data on BigQuery.

## Data sources

All sources are declared in [`models/staging/sources.yml`](nyc_trips_project/models/staging/sources.yml), under the `tlc` source:

| Table | Description |
|---|---|
| `tlc_yellow_trips_2022` | Yellow taxi trips, full 2022 calendar year |
| `tlc_green_trips_2022` | Green taxi trips, full 2022 calendar year |
| `taxi_zone_geom` | TLC taxi zone lookup (zone_id → borough/zone name) |

## Project structure

```
sources (tlc_yellow_trips_2022, tlc_green_trips_2022, taxi_zone_geom)
        │
        ▼
staging (views)          stg_yellow_trips, stg_green_trips
        │
        ▼
intermediate (table)     int_trips_unioned
        │
        ▼
marts                    fct_trip_metrics (incremental), dim_location, dim_date
```

### Staging
- **stg_yellow_trips** / **stg_green_trips** — 1:1 cleanup of each raw source (type casting, column renaming), conformed to a shared column shape with a `taxi_type` literal so yellow- and green-only fields (e.g. `ehail_fee`, `trip_type_green`) line up in one union.

### Intermediate
- **int_trips_unioned** — unions the two staging models and adds:
  - a generated `trip_id` surrogate key (`dbt_utils.generate_surrogate_key` over `taxi_type`, `vendor_id`, `pickup_datetime`, `pickup_location_id`, `dropoff_datetime`, `dropoff_location_id`), since none of the source tables have a natural trip identifier
  - data-quality flags: `is_invalid_timestamps`, `is_zero_distance_fare`, `is_near_instant_trip`, `is_negative_fare`, `is_unreliable_passenger_count`, `is_invalid_passenger_count`, `is_refund_pair`, and a rollup `is_suspicious_trip`
  - no rows are dropped here — this model preserves the full audit trail, including both sides of charge/refund pairs (matching rows with mirrored fare amounts), so anomalies can be investigated rather than silently removed

### Marts
- **fct_trip_metrics** (incremental, partitioned by `pickup_date`, clustered by `pickup_borough`) — one row per trip, net of refund pairs (fares are summed per `trip_id`). Excludes rows flagged with invalid timestamps and trips referencing placeholder/deprecated zone IDs (`105`, `57`, `264`, `265`). Adds `is_cash` and a readable `payment_type_label` derived from the TLC `payment_type` code.
- **dim_location** — one row per taxi zone, deduplicated from `taxi_zone_geom` by `zone_id`.
- **dim_date** — a calendar spine from 2022-01-01 to 2022-12-31, generated with `dbt_utils.date_spine`.

## Data quality investigations

The `analyses/` folder holds the exploratory queries (kept as dbt analyses, version-controlled via `ref()`, never materialized) behind the key decisions above:

- `investigate_trip_id_duplicates.sql` / `investigate_vendor_6_timestamp_pattern.sql` / `investigate_vendor6_invalid_rate_by_hour.sql` — traced duplicate keys and invalid timestamps (`dropoff_datetime < pickup_datetime`) back to specific vendors rather than assuming random noise
- `investigate_passenger_count_nulls.sql` / `investigate_passenger_count_zero.sql` / `investigate_passenger_count_threshold.sql` — checked whether null/zero passenger counts cluster by vendor
- `investigate_zone_id_duplicates.sql` / `investigate_relationship_fct_with_dim_location.sql` — confirmed which location IDs in trip data have no match in the zone lookup
- `investigate_near_instant_trip_threshold.sql` — explores the distribution of very short trip durations used for the `is_near_instant_trip` flag

## Testing

- **Source tests** ([`sources.yml`](nyc_trips_project/models/staging/sources.yml)): `not_null` on key fields, `dbt_utils.accepted_range` (warn) on `fare_amount`/`total_amount`, `unique`/`not_null` (warn) on `taxi_zone_geom.zone_id`.
- **`int_trips_unioned`** ([`models/intermediate/schema.yml`](nyc_trips_project/models/intermediate/schema.yml)): `not_null` on `trip_id` and the flag columns, `accepted_values` on `taxi_type`. (`trip_id` is intentionally not tested for uniqueness here — duplicates are expected from refund pairs.)
- **`fct_trip_metrics` / `dim_location` / `dim_date`** ([`models/marts/schema.yml`](nyc_trips_project/models/marts/schema.yml)): `unique`/`not_null` on primary keys, `relationships` tests tying `pickup_location_id`/`dropoff_location_id` to `dim_location`, `accepted_values` on `payment_type_label`, `not_null` on `pickup_borough`/`dropoff_borough`.
- **Singular test** ([`tests/assert_no_invalid_timestamps.sql`](nyc_trips_project/tests/assert_no_invalid_timestamps.sql)): a hard rule that a dropoff can never precede its pickup. Configured `warn_if: >0`, `error_if: >15000`, calibrated against a known, already-investigated baseline of 13,510 rows so the test flags genuinely new regressions rather than the documented existing issue.

### Latest `dbt build` results

A full `dbt build --full-refresh` against BigQuery completed with **31 pass / 6 warn / 0 error** across 37 nodes (6 models, 31 tests) in ~3m40s:

| Model | Materialization | Rows | Bytes processed |
|---|---|---|---|
| `stg_yellow_trips` / `stg_green_trips` | view | — | — |
| `dim_date` | table | 365 | — |
| `dim_location` | table | 260 | 8.2 KiB |
| `int_trips_unioned` | table | 37.0M | 6.0 GiB |
| `fct_trip_metrics` | incremental | 36.1M | 3.6 GiB |

All 6 warnings are known, already-investigated issues (see [Data quality investigations](#data-quality-investigations)) rather than new regressions:

| Test | Result |
|---|---|
| `assert_no_invalid_timestamps` | 13,510 rows (matches the documented baseline exactly) |
| `accepted_range` on yellow `total_amount` (negative) | 228,292 rows |
| `accepted_range` on yellow `fare_amount` (negative) | 225,608 rows |
| `accepted_range` on green `total_amount` (negative) | 1,973 rows |
| `accepted_range` on green `fare_amount` (negative) | 1,944 rows |
| `unique` on `taxi_zone_geom.zone_id` | 2 duplicate zone IDs (handled by the `row_number()` dedup in `dim_location`) |

## CI/CD

[`.github/workflows/dbt_ci.yml`](.github/workflows/dbt_ci.yml) runs on every pull request to `main`:

1. Install dependencies with `uv sync`
2. Install dbt packages with `dbt deps`
3. Write the BigQuery service account key from a GitHub secret
4. Run `dbt build` (runs models and tests together, in dependency order)

Credentials (`GCP_PROJECT_ID`, `GOOGLE_APPLICATION_CREDENTIALS_JSON`) are stored as GitHub Actions secrets and never committed.

## Setup

```bash
git clone <this-repo>
cd nyc_trips_project
uv sync
dbt deps
dbt debug
dbt build
```

Requires the following environment variables (see [`profiles.yml`](nyc_trips_project/profiles.yml)):

- `GCP_PROJECT_ID` — target BigQuery project
- `GOOGLE_APPLICATION_CREDENTIALS` — path to a service account key file
- `BQ_LOCATION` — optional, defaults to `US`

Dataset naming is controlled by [`macros/generate_schema_name.sql`](nyc_trips_project/macros/generate_schema_name.sql), which uses each model's configured `schema` (`nyctrips_staging`, `nyctrips_intermediate`, `nyctrips_marts`) as-is instead of dbt's default target-schema concatenation.

## Dependencies

- [dbt-labs/dbt_utils](https://github.com/dbt-labs/dbt-utils) — surrogate keys (`generate_surrogate_key`) and the calendar spine (`date_spine`)
