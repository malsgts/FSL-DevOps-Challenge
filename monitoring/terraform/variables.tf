variable "gcp_project_id" {
  description = "The GCP project ID where monitoring resources will be created"
  type        = string
}

variable "gcp_region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "The deployment environment (e.g., devel, stage, prod)"
  type        = string
  default     = "devel"
}

variable "notification_email" {
  description = "Email address for alert notifications"
  type        = string
}

variable "pubsub_error_threshold" {
  description = "Threshold count of PubSub serialization errors per day before alerting"
  type        = number
  default     = 10
}

variable "pubsub_volume_drop_duration" {
  description = "Duration in seconds of zero events on a PubSub topic before alerting"
  type        = string
  default     = "3600s"
}

variable "blueprint_error_threshold" {
  description = "Threshold count of Blueprint site-data-missing errors per day before alerting"
  type        = number
  default     = 5
}

variable "pubsub_topics" {
  description = "List of PubSub topic names to monitor for volume drops"
  type        = list(string)
  default     = []
}
