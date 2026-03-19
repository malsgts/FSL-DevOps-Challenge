# Crisis Alert Observability – Services & Validation Guide

This document describes the services, metrics, and configuration needed to
build the PubSub and Blueprint observability dashboards and alerts for the
`crisis-alert-api-node` service.

---

## Services to Validate

Before the dashboards and alerts defined in this repository will function
correctly, verify that each of the following services is properly configured
and accessible.

### 1. GCP Cloud Logging

| Item | Detail |
|------|--------|
| **Why** | Log-based metrics rely on container logs being shipped to Cloud Logging. |
| **What to check** | Verify that `crisis-alert-api-node` container logs appear in **Logs Explorer** with `resource.type="k8s_container"`. |
| **Key log lines** | `"Error serializing message"` (pubsubObserver.js L412) and `"site data not available for Nearmap check"` (Blueprint – planned). |
| **GCP API** | `logging.googleapis.com` must be enabled in the project. |

### 2. GCP Cloud Monitoring

| Item | Detail |
|------|--------|
| **Why** | Alert policies and the monitoring dashboard are created in Cloud Monitoring. |
| **What to check** | Verify the `monitoring.googleapis.com` API is enabled. Confirm the Terraform service account has `roles/monitoring.editor`. |
| **Dashboard** | After applying Terraform, the dashboard **"Crisis Alert Observability"** should appear in the Monitoring console. |
| **Alert policies** | Three alert policies are created – see [Alert Policies](#alert-policies) below. |

### 3. GCP Pub/Sub

| Item | Detail |
|------|--------|
| **Why** | Built-in Pub/Sub metrics are used to detect volume drops and subscription backlog. |
| **What to check** | Verify topic(s) exist and the `pubsub.googleapis.com` API is enabled. |
| **Key metrics (free from GCP)** | `pubsub.googleapis.com/topic/send_message_operation_count`, `pubsub.googleapis.com/subscription/num_undelivered_messages`, `pubsub.googleapis.com/subscription/oldest_unacked_message_age` |
| **Topics to monitor** | Configured via `pubsub_topics` Terraform variable (e.g., `crisis-alert-events`, `crisis-alert-notifications`). |

### 4. Prometheus

| Item | Detail |
|------|--------|
| **Why** | Application-level metrics are scraped by Prometheus for fine-grained alerting and Grafana dashboards. |
| **What to check** | Verify that the Prometheus instance can scrape `crisis-alert-api-node` at its `/metrics` endpoint. |
| **Required counters** | The application must expose the following counters (see [Application Instrumentation](#application-instrumentation)): `pubsub_serialization_errors_total`, `pubsub_messages_published_total`, `blueprint_site_data_missing_total` |
| **Alert rules** | Load `monitoring/prometheus/alerts.yml` into the Prometheus configuration. |

### 5. Grafana

| Item | Detail |
|------|--------|
| **Why** | Grafana provides the interactive dashboard for visualizing all metrics. |
| **What to check** | Verify that Grafana has a Prometheus data source configured and named `Prometheus`. |
| **Dashboard** | Import `monitoring/grafana/crisis-alert-dashboard.json` via the Grafana UI or provisioning API. |

### 6. GKE / Kubernetes Cluster

| Item | Detail |
|------|--------|
| **Why** | The `crisis-alert-api-node` pods run on GKE. Logging, monitoring agents, and Prometheus all depend on cluster configuration. |
| **What to check** | GKE logging and monitoring are enabled on the cluster (`--enable-stackdriver-kubernetes`). Prometheus operator or GMP (Google Managed Prometheus) is installed. |

---

## Alert Policies

| Alert | Condition | Severity |
|-------|-----------|----------|
| **PubSub Serialization Errors** | Log-based metric count > threshold in 24 h | Warning |
| **PubSub Serialization Error Spike** | Prometheus rate > 0.1/s for 10 min | Critical |
| **PubSub Topic Volume Drop** | GCP built-in metric = 0 for configured duration | Warning |
| **Blueprint Site Data Missing** | Log-based metric count > threshold in 24 h | Warning |
| **HTTP 5xx Error Rate** | > 5 % for 10 min (Prometheus) | Critical |
| **Service Down** | Prometheus `up` = 0 for 5 min | Critical |

---

## Application Instrumentation

The `crisis-alert-api-node` application needs to expose the following
Prometheus counters. These should be registered using a Prometheus client
library (e.g., `prom-client` for Node.js).

```javascript
const { Counter } = require('prom-client');

// Increment when a PubSub message fails to serialize (pubsubObserver.js L412)
const pubsubSerializationErrors = new Counter({
  name: 'pubsub_serialization_errors_total',
  help: 'Total PubSub message serialization errors',
  labelNames: ['topic'],
});

// Increment on every successful PubSub publish
const pubsubMessagesPublished = new Counter({
  name: 'pubsub_messages_published_total',
  help: 'Total messages published to PubSub',
  labelNames: ['topic'],
});

// Increment when site data is unavailable for the Nearmap check (Blueprint)
const blueprintSiteDataMissing = new Counter({
  name: 'blueprint_site_data_missing_total',
  help: 'Total times site data was not available for Nearmap availability check',
});
```

---

## Directory Layout

```
monitoring/
├── terraform/                  # GCP monitoring infrastructure
│   ├── main.tf                 # Log-based metrics, alert policies, dashboard
│   ├── variables.tf            # Input variables
│   ├── outputs.tf              # Terraform outputs
│   ├── versions.tf             # Provider requirements
│   └── env/
│       ├── devel.tfvars        # Development environment values
│       └── stage.tfvars        # Staging environment values
├── prometheus/
│   └── alerts.yml              # Prometheus alerting rules
└── grafana/
    └── crisis-alert-dashboard.json  # Grafana dashboard JSON
```

---

## Deployment

### Terraform (GCP Monitoring)

```bash
cd monitoring/terraform
terraform init
terraform apply -var-file=env/devel.tfvars   # or stage.tfvars
```

### Prometheus

Add the alert rules file to your Prometheus configuration:

```yaml
# prometheus.yml
rule_files:
  - /path/to/monitoring/prometheus/alerts.yml
```

### Grafana

Import the dashboard via the Grafana UI (**Dashboards → Import**) or by
placing the JSON file in your Grafana provisioning directory.
