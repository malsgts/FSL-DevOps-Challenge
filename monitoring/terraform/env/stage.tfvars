gcp_project_id              = "your-gcp-project-id"
environment                 = "stage"
notification_email          = "team@example.com"
pubsub_error_threshold      = 5
pubsub_volume_drop_duration = "1800s"
blueprint_error_threshold   = 3
pubsub_topics               = ["crisis-alert-events", "crisis-alert-notifications"]
