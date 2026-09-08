-- BigQuery queries for the GKE application-log sink.
-- Replace PROJECT_ID with the assessment project ID.
-- The Terraform sink uses partitioned tables, so the GKE stdout log normally appears as:
-- `PROJECT_ID.gke_logs.stdout`
-- Verify the exact generated table/schema in BigQuery before running these queries.

-- 1. Application errors over time
SELECT
  TIMESTAMP_TRUNC(timestamp, MINUTE) AS time,
  COUNT(*) AS error_count
FROM `PROJECT_ID.gke_logs.stdout`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
  AND (
    severity = "ERROR"
    OR JSON_VALUE(TO_JSON_STRING(jsonPayload), '$.severity') = 'ERROR'
  )
GROUP BY time
ORDER BY time;

-- 2. Errors by application
SELECT
  COALESCE(
    JSON_VALUE(TO_JSON_STRING(jsonPayload), '$.application'),
    REGEXP_EXTRACT(textPayload, r'"application":"([^"]+)"')
  ) AS application,
  COUNT(*) AS error_count
FROM `PROJECT_ID.gke_logs.stdout`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
  AND (
    severity = "ERROR"
    OR JSON_VALUE(TO_JSON_STRING(jsonPayload), '$.severity') = 'ERROR'
  )
GROUP BY application
ORDER BY error_count DESC;

-- 3. Error count by cluster
SELECT
  COALESCE(
    JSON_VALUE(TO_JSON_STRING(jsonPayload), '$.cluster'),
    REGEXP_EXTRACT(textPayload, r'"cluster":"([^"]+)"')
  ) AS cluster,
  COUNT(*) AS error_count
FROM `PROJECT_ID.gke_logs.stdout`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
  AND (
    severity = "ERROR"
    OR JSON_VALUE(TO_JSON_STRING(jsonPayload), '$.severity') = 'ERROR'
  )
GROUP BY cluster
ORDER BY error_count DESC;

-- 4. Application latency percentiles from structured application logs.
SELECT
  TIMESTAMP_TRUNC(timestamp, MINUTE) AS time,
  APPROX_QUANTILES(
    CAST(JSON_VALUE(TO_JSON_STRING(jsonPayload), '$.latency_ms') AS INT64), 100
  )[OFFSET(50)] AS p50_ms,
  APPROX_QUANTILES(
    CAST(JSON_VALUE(TO_JSON_STRING(jsonPayload), '$.latency_ms') AS INT64), 100
  )[OFFSET(95)] AS p95_ms,
  APPROX_QUANTILES(
    CAST(JSON_VALUE(TO_JSON_STRING(jsonPayload), '$.latency_ms') AS INT64), 100
  )[OFFSET(99)] AS p99_ms
FROM `PROJECT_ID.gke_logs.stdout`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
  AND JSON_VALUE(TO_JSON_STRING(jsonPayload), '$.latency_ms') IS NOT NULL
GROUP BY time
ORDER BY time;

-- If your generated BigQuery schema stores application JSON as textPayload rather than
-- jsonPayload, replace JSON_VALUE(TO_JSON_STRING(jsonPayload), '$.field') with
-- JSON_VALUE(textPayload, '$.field').
