provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# ---------------------------------------------------------------------------
# Notification Channel
# ---------------------------------------------------------------------------

resource "google_monitoring_notification_channel" "email" {
  display_name = "crisis-alert-${var.environment}-email"
  type         = "email"

  labels = {
    email_address = var.notification_email
  }
}

# ---------------------------------------------------------------------------
# Log-Based Metrics
# ---------------------------------------------------------------------------

# 1. PubSub serialization error metric
#    Captures errors logged when the crisis-alert-api-node service fails to
#    serialize a message before publishing to PubSub.
#    Reference: pubsubObserver.js L412 – "Error serializing message"
resource "google_logging_metric" "pubsub_serialization_errors" {
  name   = "crisis-alert/${var.environment}/pubsub-serialization-errors"
  filter = <<-EOT
    resource.type="k8s_container"
    resource.labels.container_name="crisis-alert-api-node"
    severity>=ERROR
    textPayload=~"Error serializing message"
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"

    labels {
      key         = "topic"
      value_type  = "STRING"
      description = "The PubSub topic the message was destined for"
    }
  }

  label_extractors = {
    "topic" = "REGEXP_EXTRACT(textPayload, \"topic=([\\\\w-]+)\")"
  }
}

# 2. Blueprint site-data-missing metric
#    Captures errors logged when Blueprint cannot retrieve site data needed to
#    check Nearmap availability. Logging for this case is planned; this metric
#    will start counting once the application emits the log line.
resource "google_logging_metric" "blueprint_site_data_missing" {
  name   = "crisis-alert/${var.environment}/blueprint-site-data-missing"
  filter = <<-EOT
    resource.type="k8s_container"
    resource.labels.container_name="crisis-alert-api-node"
    severity>=ERROR
    textPayload=~"site data not available for Nearmap check"
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }
}

# ---------------------------------------------------------------------------
# Alert Policies
# ---------------------------------------------------------------------------

# Alert: PubSub serialization errors exceed threshold in a rolling 24-hour
# window.
resource "google_monitoring_alert_policy" "pubsub_serialization_error_alert" {
  display_name = "crisis-alert-${var.environment}: PubSub Serialization Errors"
  combiner     = "OR"

  conditions {
    display_name = "PubSub serialization error count exceeds ${var.pubsub_error_threshold}/day"

    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.pubsub_serialization_errors.name}\" AND resource.type=\"k8s_container\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.pubsub_error_threshold
      duration        = "0s"

      aggregations {
        alignment_period   = "86400s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  documentation {
    content   = <<-EOT
      ## PubSub Serialization Error Alert

      The crisis-alert-api-node service in the **${var.environment}** environment
      has logged more than ${var.pubsub_error_threshold} PubSub serialization
      errors in the last 24 hours.

      **What to check:**
      1. Container logs for `crisis-alert-api-node` — look for "Error serializing message"
      2. Recent deployments that may have changed the PubSub message schema
      3. PubSub topic configuration and IAM permissions

      **Reference:** pubsubObserver.js L412
    EOT
    mime_type = "text/markdown"
  }
}

# Alert: PubSub topic event volume drops to 0 for a sustained period.
# Created per-topic so that each topic can be monitored independently.
resource "google_monitoring_alert_policy" "pubsub_topic_volume_drop" {
  for_each = toset(var.pubsub_topics)

  display_name = "crisis-alert-${var.environment}: PubSub Volume Drop – ${each.value}"
  combiner     = "OR"

  conditions {
    display_name = "No messages published to ${each.value} for ${var.pubsub_volume_drop_duration}"

    condition_threshold {
      filter          = "metric.type=\"pubsub.googleapis.com/topic/send_message_operation_count\" AND resource.type=\"pubsub_topic\" AND resource.labels.topic_id=\"${each.value}\""
      comparison      = "COMPARISON_LT"
      threshold_value = 1
      duration        = var.pubsub_volume_drop_duration

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  documentation {
    content   = <<-EOT
      ## PubSub Volume Drop Alert

      The PubSub topic **${each.value}** in the **${var.environment}** environment
      has received zero published messages for ${var.pubsub_volume_drop_duration}.

      **What to check:**
      1. The crisis-alert-api-node pods are running and healthy
      2. Network connectivity between the service and PubSub
      3. Recent deployments or configuration changes
      4. PubSub topic and subscription status in the GCP Console
    EOT
    mime_type = "text/markdown"
  }
}

# Alert: Blueprint site-data-missing errors exceed threshold.
resource "google_monitoring_alert_policy" "blueprint_site_data_alert" {
  display_name = "crisis-alert-${var.environment}: Blueprint Site Data Missing"
  combiner     = "OR"

  conditions {
    display_name = "Blueprint site-data-missing count exceeds ${var.blueprint_error_threshold}/day"

    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.blueprint_site_data_missing.name}\" AND resource.type=\"k8s_container\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.blueprint_error_threshold
      duration        = "0s"

      aggregations {
        alignment_period   = "86400s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  documentation {
    content   = <<-EOT
      ## Blueprint Site Data Missing Alert

      The crisis-alert-api-node service in the **${var.environment}** environment
      has logged more than ${var.blueprint_error_threshold} errors where site data
      was not available for the Nearmap availability check in the last 24 hours.

      **What to check:**
      1. Container logs — look for "site data not available for Nearmap check"
      2. Upstream data sources that provide site information
      3. Database connectivity and query performance
    EOT
    mime_type = "text/markdown"
  }
}

# ---------------------------------------------------------------------------
# GCP Monitoring Dashboard
# ---------------------------------------------------------------------------

resource "google_monitoring_dashboard" "crisis_alert_observability" {
  dashboard_json = jsonencode({
    displayName = "Crisis Alert Observability – ${var.environment}"
    gridLayout = {
      columns = 2
      widgets = [
        {
          title = "PubSub Serialization Errors (24h)"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.pubsub_serialization_errors.name}\" AND resource.type=\"k8s_container\""
                  aggregation = {
                    alignmentPeriod  = "3600s"
                    perSeriesAligner = "ALIGN_SUM"
                  }
                }
              }
              plotType = "LINE"
            }]
            yAxis = { label = "Error Count" }
          }
        },
        {
          title = "Blueprint Site Data Missing Errors (24h)"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.blueprint_site_data_missing.name}\" AND resource.type=\"k8s_container\""
                  aggregation = {
                    alignmentPeriod  = "3600s"
                    perSeriesAligner = "ALIGN_SUM"
                  }
                }
              }
              plotType = "LINE"
            }]
            yAxis = { label = "Error Count" }
          }
        },
        {
          title = "PubSub Topic Message Volume"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"pubsub.googleapis.com/topic/send_message_operation_count\" AND resource.type=\"pubsub_topic\""
                  aggregation = {
                    alignmentPeriod    = "300s"
                    perSeriesAligner   = "ALIGN_SUM"
                    crossSeriesReducer = "REDUCE_SUM"
                    groupByFields      = ["resource.labels.topic_id"]
                  }
                }
              }
              plotType = "LINE"
            }]
            yAxis = { label = "Messages Published" }
          }
        },
        {
          title = "PubSub Undelivered Messages (Subscription Backlog)"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"pubsub.googleapis.com/subscription/num_undelivered_messages\" AND resource.type=\"pubsub_subscription\""
                  aggregation = {
                    alignmentPeriod    = "300s"
                    perSeriesAligner   = "ALIGN_MEAN"
                    crossSeriesReducer = "REDUCE_SUM"
                    groupByFields      = ["resource.labels.subscription_id"]
                  }
                }
              }
              plotType = "LINE"
            }]
            yAxis = { label = "Undelivered Messages" }
          }
        },
        {
          title = "Prometheus – crisis-alert-api-node Error Rate"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"prometheus.googleapis.com/http_requests_total/counter\" AND metric.labels.code=monitoring.regex.full_match(\"5..\") AND resource.type=\"prometheus_target\""
                  aggregation = {
                    alignmentPeriod    = "300s"
                    perSeriesAligner   = "ALIGN_RATE"
                    crossSeriesReducer = "REDUCE_SUM"
                  }
                }
              }
              plotType = "LINE"
            }]
            yAxis = { label = "5xx Errors / sec" }
          }
        },
        {
          title = "PubSub Oldest Unacked Message Age"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"pubsub.googleapis.com/subscription/oldest_unacked_message_age\" AND resource.type=\"pubsub_subscription\""
                  aggregation = {
                    alignmentPeriod    = "300s"
                    perSeriesAligner   = "ALIGN_MAX"
                    crossSeriesReducer = "REDUCE_MAX"
                    groupByFields      = ["resource.labels.subscription_id"]
                  }
                }
              }
              plotType = "LINE"
            }]
            yAxis = { label = "Age (seconds)" }
          }
        }
      ]
    }
  })
}
