variable "credentials_file" {
  default = "/home/lar4749/cis-91-361423-9a20bb86a72d.json"
}

variable "project" {
  default = "cis-91-361423"
}

variable "region" {
  default = "us-central1"
}

variable "zone" {
  default = "us-central1-c"
}

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.5.0"
    }
  }
}

provider "google" {
  credentials = file(var.credentials_file)
  region      = var.region
  zone        = var.zone
  project     = var.project
}

#
# Network Configuration
#

resource "google_compute_network" "vpc_network" {
  name = "dokuwiki-network"
}

resource "google_compute_firewall" "default_firewall" {
  name    = "dokuwiki-firewall"
  network = google_compute_network.vpc_network.name
  allow {
    protocol = "tcp"
    ports    = ["22", "80"]
  }
  source_ranges = ["0.0.0.0/0"]
}

#
# Instances
#

resource "google_compute_instance" "vm_instance" {
  name         = "dokuwiki"
  machine_type = "e2-micro"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
    }
  }
}

output "external-ip" {
  value = google_compute_instance.vm_instance.network_interface[0].access_config[0].nat_ip
}