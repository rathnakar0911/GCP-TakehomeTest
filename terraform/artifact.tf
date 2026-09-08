resource "google_artifact_registry_repository" "apps" {
  location      = var.primary_region
  repository_id = "gke-assessment"
  description   = "Container images for the GKE take-home assessment"
  format        = "DOCKER"
}
