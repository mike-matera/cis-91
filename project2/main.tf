variable "credentials_file" { 
  default = "../secrets/cis-91-e7c9827011d3.json" 
}

variable "project" {
  default = "cis-91"
}

variable "region" {
  default = "us-west1"
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
  region  = var.region
  project = var.project
}

resource "google_compute_network" "vpc_network" {
  name = "project2-network"
}

resource "google_compute_instance" "db_instance" {
  name         = "db"
  machine_type = "e2-medium"
  zone         = "us-west1-a"
  allow_stopping_for_update = true 

  tags = ["db"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
      size = 16
     }
  }
  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
    }
  }
}

resource "google_compute_instance" "webservers" {
  name         = "web${count.index}"
  machine_type = "e2-medium"
  zone         = "us-west1-b"
  allow_stopping_for_update = true 
  count        = 3
    
  tags = ["web"]
  labels = {
    name: "web${count.index}"
  }

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
      size = 16
    }
  }
  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
    }
  }
}

resource "google_compute_firewall" "default-firewall" {
  name = "default-firewall"
  network = google_compute_network.vpc_network.name
  allow {
    protocol = "tcp"
    ports = ["22"]
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "db-firewall" {
  name = "db-firewall"
  network = google_compute_network.vpc_network.name
  allow {
    protocol = "tcp"
    ports = ["5432"]
  }
  source_tags = ["web"]
  target_tags = ["db"]
}

resource "google_compute_firewall" "web-firewall" {
  name = "web-firewall"
  network = google_compute_network.vpc_network.name
  allow {
    protocol = "tcp"
    ports = ["80"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags = ["web"]
}

resource "google_compute_health_check" "webservers" {
  name = "webserver-health-check"

  timeout_sec        = 1
  check_interval_sec = 1

  http_health_check {
    port = 80
    request_path = "/index.php/Main_Page"
  }
}

resource "google_compute_instance_group" "webservers" {
  name        = "cis91-webservers"
  description = "Webserver instance group"
  zone        = "us-west1-b"

  instances = google_compute_instance.webservers[*].self_link

  named_port {
    name = "http"
    port = "80"
  }
}

resource "google_compute_backend_service" "webservice" {
  name      = "web-service"
  port_name = "http"
  protocol  = "HTTP"

  backend {
    group = google_compute_instance_group.webservers.id
  }

  health_checks = [
    google_compute_health_check.webservers.id
  ]
}

resource "google_compute_url_map" "default" {
  name            = "my-site"
  default_service = google_compute_backend_service.webservice.id
}

resource "google_compute_target_http_proxy" "default" {
  name     = "web-proxy"
  url_map  = google_compute_url_map.default.id
}

resource "google_compute_global_address" "default" {
  name = "external-address"
}

resource "google_compute_global_forwarding_rule" "default" {
  name                  = "forward-application"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "80"
  target                = google_compute_target_http_proxy.default.id
  ip_address            = google_compute_global_address.default.address
}

output "db-ip" {
  value = google_compute_instance.db_instance.network_interface[0].access_config[0].nat_ip
}

output "web-ip" {
  value = google_compute_instance.webservers[*].network_interface[0].access_config[0].nat_ip
}

output "lb-ip" {
  value = google_compute_global_address.default.address
}
