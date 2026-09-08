resource "google_service_account" "grafana" {
  account_id   = "grafana-observer"
  display_name = "Grafana read-only observability service account"
}

resource "google_project_iam_member" "grafana_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.grafana.email}"
}

resource "google_project_iam_member" "grafana_bigquery_viewer" {
  project = var.project_id
  role    = "roles/bigquery.dataViewer"
  member  = "serviceAccount:${google_service_account.grafana.email}"
}

resource "google_project_iam_member" "grafana_bigquery_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.grafana.email}"
}

resource "google_service_account_iam_member" "grafana_workload_identity" {
  service_account_id = google_service_account.grafana.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[observability/grafana]"
}

output "grafana_service_account" {
  value = google_service_account.grafana.email
}

output "artifact_registry_repository" {
  value = google_artifact_registry_repository.apps.name
}

output "primary_cluster" {
  value = google_container_cluster.primary.name
}

output "secondary_cluster" {
  value = google_container_cluster.secondary.name
}

output "bigquery_dataset" {
  value = google_bigquery_dataset.logs.dataset_id
}
