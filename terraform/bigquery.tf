resource "google_bigquery_dataset" "logs" {
  dataset_id                 = "gke_logs"
  friendly_name              = "GKE Application Logs"
  description                = "Application and GKE workload logs exported from Cloud Logging"
  location                   = "US"
  delete_contents_on_destroy = true
}

resource "google_logging_project_sink" "gke_logs" {
  name        = "gke-application-logs-to-bigquery"
  destination = "bigquery.googleapis.com/projects/${var.project_id}/datasets/${google_bigquery_dataset.logs.dataset_id}"

  filter = <<-EOT
    resource.type="k8s_container"
    AND resource.labels.namespace_name="demo"
  EOT

  unique_writer_identity = true
}

resource "google_bigquery_dataset_iam_member" "sink_writer" {
  dataset_id = google_bigquery_dataset.logs.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = google_logging_project_sink.gke_logs.writer_identity
}
