# Grafana Dashboard Troubleshooting Guide

## Dashboard: Crisis Alert – PubSub & Blueprint Observability

This document explains the root causes identified for the dashboard showing **"No data"** and the fixes applied.

---

## Issues Identified & Fixes Applied

### 1. Hardcoded Datasource UID (`PBFA97CFB590B2093`)

**Problem:** Every panel and target in the original dashboard used a hardcoded Prometheus datasource UID (`PBFA97CFB590B2093`). This UID is specific to a single Grafana instance. When the dashboard is imported into any other Grafana instance, the UID does not match any configured datasource, so all queries fail silently and return no data.

**Fix:** Replaced all hardcoded UIDs with the `${DS_PROMETHEUS}` variable and added an `__inputs` block at the top of the JSON. This causes Grafana to prompt for datasource selection on import, ensuring the correct Prometheus instance is wired up.

### 2. HTML-Encoded Characters in Title and Annotations

**Problem:** The dashboard title contained `&amp;` instead of `&`:
- Title: `"Crisis Alert – PubSub &amp; Blueprint Observability"`
- Annotation name: `"Annotations &amp; Alerts"`

These are HTML entities that should not appear in JSON. While this may not directly cause "no data", it indicates the JSON was exported through an HTML context that corrupted values, and could cause import/matching issues.

**Fix:** Replaced `&amp;` with `&` throughout.

### 3. Template Variable Missing Datasource Reference

**Problem:** The `topic` template variable did not specify a datasource in the provided JSON. Without a datasource, the variable query `label_values(pubsub_messages_published_total, topic)` cannot execute, so the variable dropdown remains empty.

**Fix:** Added a proper datasource reference (`${DS_PROMETHEUS}`) to the template variable definition.

### 4. Template Variable Not Used in Panel Queries

**Problem:** The `topic` template variable was defined but **never referenced** in any PromQL expression. For example:
```promql
# Original – ignores the variable
sum(rate(pubsub_serialization_errors_total[5m])) by (topic)

# Fixed – filters by selected topic(s)
sum(rate(pubsub_serialization_errors_total{topic=~"$topic"}[5m])) by (topic)
```

Without the `{topic=~"$topic"}` label matcher, the Topic dropdown has no effect on the data shown.

**Fix:** Added `{topic=~"$topic"}` to all PubSub-related PromQL expressions (panels 1–4). The `allValue` was set to `.*` so selecting "All" returns all topics.

### 5. Missing `__inputs` and `__requires` Blocks

**Problem:** The JSON lacked the `__inputs` and `__requires` metadata that Grafana uses during dashboard import to map datasources and validate plugin dependencies.

**Fix:** Added both blocks so that Grafana prompts for the Prometheus datasource on import and validates that required panel plugins (`stat`, `timeseries`) are available.

### 6. Stat Panels Return "No Data" When Metric Has No Matching Series

**Problem:** When a Prometheus counter has never been incremented (or the metric doesn't exist yet), `sum(increase(metric[24h]))` returns an empty result set. Grafana stat panels display this as "No data" with no visual indication of health.

**Fix:**
- Added `or vector(0)` to stat panel queries so they return `0` instead of empty when no series match:
  ```promql
  # Before – returns empty when metric has no series
  sum(increase(pubsub_serialization_errors_total{topic=~"$topic"}[24h]))

  # After – returns 0 when metric has no series
  sum(increase(pubsub_serialization_errors_total{topic=~"$topic"}[24h])) or vector(0)
  ```
- Added `"noValue": "0"` to stat panel field configs as a secondary fallback
- Set `"instant": true` on stat panel targets since they only need a single value, not a time series range

---

## Additional Checks (Beyond Dashboard JSON)

If the dashboard still shows no data after importing the fixed JSON, verify these infrastructure prerequisites:

### A. Prometheus Datasource Configured in Grafana
1. Go to **Configuration → Data Sources** in Grafana
2. Verify a Prometheus datasource exists and is reachable
3. Click **"Test"** to confirm connectivity

### B. Application Metrics Are Instrumented
The dashboard queries these custom metrics which **must be instrumented** in the `crisis-alert-api-node` application using `prom-client`:

| Metric | Type | Labels |
|--------|------|--------|
| `pubsub_serialization_errors_total` | Counter | `topic` |
| `pubsub_messages_published_total` | Counter | `topic` |
| `blueprint_site_data_missing_total` | Counter | — |
| `http_requests_total` | Counter | `service`, `code` |

Example instrumentation:
```js
const { Counter } = require('prom-client');

const pubsubSerializationErrors = new Counter({
  name: 'pubsub_serialization_errors_total',
  help: 'Total PubSub message serialization errors',
  labelNames: ['topic'],
});
```

### C. `/metrics` Endpoint Exposed
The application must expose a `/metrics` HTTP endpoint that Prometheus can scrape:
```js
const { register } = require('prom-client');
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});
```

### D. Prometheus Scrape Target Configured
Verify Prometheus is scraping the application:
```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'crisis-alert-api-node'
    static_configs:
      - targets: ['<app-host>:<app-port>']
```

Confirm in Prometheus UI → **Status → Targets** that the job `crisis-alert-api-node` shows state `UP`.

### E. Verify Metrics Exist in Prometheus
Run these queries directly in the Prometheus expression browser:
```promql
pubsub_serialization_errors_total
pubsub_messages_published_total
blueprint_site_data_missing_total
http_requests_total{service="crisis-alert-api-node"}
up{job="crisis-alert-api-node"}
```

If any return "no data", the issue is in application instrumentation or Prometheus scraping, not the Grafana dashboard.

---

## Import Instructions

1. Open Grafana → **Dashboards → Import**
2. Upload `crisis-alert-dashboard.json` or paste its contents
3. When prompted, select your **Prometheus** datasource for `DS_PROMETHEUS`
4. Click **Import**

The dashboard will auto-refresh every 30 seconds and defaults to a 24-hour time range.
