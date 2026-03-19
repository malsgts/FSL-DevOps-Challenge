output "pubsub_serialization_error_metric_name" {
  value       = google_logging_metric.pubsub_serialization_errors.name
  description = "The name of the log-based metric tracking PubSub serialization errors"
}

output "blueprint_site_data_missing_metric_name" {
  value       = google_logging_metric.blueprint_site_data_missing.name
  description = "The name of the log-based metric tracking Blueprint site data availability errors"
}

output "pubsub_error_alert_policy_name" {
  value       = google_monitoring_alert_policy.pubsub_serialization_error_alert.name
  description = "The name of the alert policy for PubSub serialization errors"
}

output "pubsub_volume_drop_alert_policy_names" {
  value       = [for policy in google_monitoring_alert_policy.pubsub_topic_volume_drop : policy.name]
  description = "The names of the alert policies for PubSub topic volume drops"
}

output "blueprint_error_alert_policy_name" {
  value       = google_monitoring_alert_policy.blueprint_site_data_alert.name
  description = "The name of the alert policy for Blueprint site data errors"
}

output "notification_channel_name" {
  value       = google_monitoring_notification_channel.email.display_name
  description = "The display name of the notification channel"
}

output "monitoring_dashboard_id" {
  value       = google_monitoring_dashboard.crisis_alert_observability.id
  description = "The ID of the GCP Monitoring dashboard"
}
