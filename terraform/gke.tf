resource "google_service_account" "gke_nodes" {
  account_id   = "gke-node-sa"
  display_name = "GKE node service account"
}

resource "google_project_iam_member" "gke_node_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_node_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_node_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_container_cluster" "primary" {
  name     = "gke-primary"
  location = var.primary_region

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.primary.name

  node_locations = [var.primary_zone]

  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  networking_mode = "VPC_NATIVE"

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods-primary"
    services_secondary_range_name = "services-primary"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  release_channel {
    channel = "REGULAR"
  }

  fleet {
    project = var.project_id
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
  }

  resource_labels = {
    environment = "assessment"
    cluster     = "primary"
  }

  depends_on = [google_project_service.required]
}

resource "google_container_node_pool" "primary" {
  name       = "general"
  location   = var.primary_region
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_locations = [var.primary_zone]

  node_config {
    machine_type    = var.machine_type
    disk_type       = "pd-balanced"
    disk_size_gb    = 30
    image_type      = "COS_CONTAINERD"
    service_account = google_service_account.gke_nodes.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    labels = {
      workload = "general"
    }
  }
}

resource "google_container_cluster" "secondary" {
  name     = "gke-secondary"
  location = var.secondary_region

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.secondary.name

  node_locations = [var.secondary_zone]

  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  networking_mode = "VPC_NATIVE"

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods-secondary"
    services_secondary_range_name = "services-secondary"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  release_channel {
    channel = "REGULAR"
  }

  fleet {
    project = var.project_id
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
  }

  resource_labels = {
    environment = "assessment"
    cluster     = "secondary"
  }

  depends_on = [google_project_service.required]
}

resource "google_container_node_pool" "secondary" {
  name       = "general"
  location   = var.secondary_region
  cluster    = google_container_cluster.secondary.name
  node_count = 1

  node_locations = [var.secondary_zone]

  node_config {
    machine_type    = var.machine_type
    disk_type       = "pd-balanced"
    disk_size_gb    = 30
    image_type      = "COS_CONTAINERD"
    service_account = google_service_account.gke_nodes.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    labels = {
      workload = "general"
    }
  }
}

resource "google_project_iam_member" "gke_node_artifact_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}
