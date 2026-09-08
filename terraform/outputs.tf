output "vpc_name" {
  value = google_compute_network.vpc.name
}

output "primary_subnet" {
  value = google_compute_subnetwork.primary.name
}

output "secondary_subnet" {
  value = google_compute_subnetwork.secondary.name
}
