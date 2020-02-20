terraform {
  backend "gcs" {
    bucket = "tf-state-prod-shamglam"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = "svg-devops-training-2"
  region  = "europe-north1"
  zone    = "europe-north1-a"

}

resource "google_compute_instance_group" "frontend_ig" {
  name        = "frontend_ig"
  description = "frontend_ig"
  zone        = "europe-north1-a"

  instances = google_compute_instance.vm_instance.*.self_link

  named_port {
    name = "http"
    port = "8080"
  }

  named_port {
    name = "https"
    port = "8443"
  }

  network = google_compute_network.vpc_network.self_link
}

resource "google_compute_instance_group" "backend_ig" {
  name        = "backend_ig"
  description = "frontend_ig"
  zone        = "europe-north1-a"
  network     = google_compute_network.vpc_network.self_link
}

resource "google_compute_instance_group" "database_ig" {
  name        = "database"
  description = "database_ig"
  zone        = "europe-north1-a"
  network     = google_compute_network.vpc_network.self_link
}


resource "google_compute_instance" "vm_instance" {
  count        = 3
  name         = "vm${count.index}"
  machine_type = "g1-small"
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }
  network_interface {
    network    = "${google_compute_network.vpc_network.self_link}"
    subnetwork = "test-subnetwork"
  }

  metadata_startup_script = "sudo apt get -y update && sudo apt-get -y install nginx && sudo service nginx start"


}


resource "google_compute_subnetwork" "network-with-private-secondary-ip-ranges" {
  name          = "test-subnetwork"
  ip_cidr_range = "10.0.0.0/24"
  region        = "europe-north1"
  network       = google_compute_network.vpc_network.self_link

}

resource "google_compute_network" "vpc_network" {
  name                    = "my-name"
  auto_create_subnetworks = "false"
}