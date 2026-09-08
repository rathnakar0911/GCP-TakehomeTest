variable "project_id" {
  description = "Existing GCP project ID used for the assessment."
  type        = string
}

variable "primary_region" {
  type    = string
  default = "us-central1"
}

variable "primary_zone" {
  type    = string
  default = "us-central1-a"
}

variable "secondary_region" {
  type    = string
  default = "us-east1"
}

variable "secondary_zone" {
  type    = string
  default = "us-east1-b"
}

variable "network_name" {
  type    = string
  default = "assessment-vpc"
}

variable "primary_subnet_cidr" {
  type    = string
  default = "10.10.0.0/20"
}

variable "secondary_subnet_cidr" {
  type    = string
  default = "10.20.0.0/20"
}

variable "pods_primary_cidr" {
  type    = string
  default = "10.100.0.0/16"
}

variable "services_primary_cidr" {
  type    = string
  default = "10.110.0.0/20"
}

variable "pods_secondary_cidr" {
  type    = string
  default = "10.120.0.0/16"
}

variable "services_secondary_cidr" {
  type    = string
  default = "10.130.0.0/20"
}

variable "machine_type" {
  description = "Small VM type for the take-home environment. Increase for production."
  type        = string
  default     = "e2-standard-2"
}
