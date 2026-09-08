resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
  depends_on              = [google_project_service.required]
}

resource "google_compute_subnetwork" "primary" {
  name          = "gke-primary-subnet"
  ip_cidr_range = var.primary_subnet_cidr
  region        = var.primary_region
  network       = google_compute_network.vpc.id

  secondary_ip_range {
    range_name    = "pods-primary"
    ip_cidr_range = var.pods_primary_cidr
  }

  secondary_ip_range {
    range_name    = "services-primary"
    ip_cidr_range = var.services_primary_cidr
  }
}

resource "google_compute_subnetwork" "secondary" {
  name          = "gke-secondary-subnet"
  ip_cidr_range = var.secondary_subnet_cidr
  region        = var.secondary_region
  network       = google_compute_network.vpc.id

  secondary_ip_range {
    range_name    = "pods-secondary"
    ip_cidr_range = var.pods_secondary_cidr
  }

  secondary_ip_range {
    range_name    = "services-secondary"
    ip_cidr_range = var.services_secondary_cidr
  }
}

resource "google_compute_router" "primary" {
  name    = "primary-router"
  region  = var.primary_region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "primary" {
  name                               = "primary-nat"
  router                             = google_compute_router.primary.name
  region                             = var.primary_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.primary.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

resource "google_compute_router" "secondary" {
  name    = "secondary-router"
  region  = var.secondary_region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "secondary" {
  name                               = "secondary-nat"
  router                             = google_compute_router.secondary.name
  region                             = var.secondary_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.secondary.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}
