gcp_project_id              = "your-gcp-project-id"
environment                 = "devel"
notification_email          = "team@example.com"
pubsub_error_threshold      = 10
pubsub_volume_drop_duration = "3600s"
blueprint_error_threshold   = 5
pubsub_topics               = ["crisis-alert-events", "crisis-alert-notifications"]
