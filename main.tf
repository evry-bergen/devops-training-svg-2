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


data "google_container_engine_versions" "gke-versions" {

}

resource "google_compute_network" "vpc_network" {
  name                    = "my-name"
  auto_create_subnetworks = "false"
}


resource "google_compute_subnetwork" "network-with-private-secondary-ip-ranges" {
  name          = "test-subnetwork"
  ip_cidr_range = "10.0.0.0/24"
  region        = "europe-north1"
  network       = google_compute_network.vpc_network.self_link

}

resource "google_container_cluster" "primary" {
  name       = "my-gke-cluster"
  location   = "europe-north1"
  network    = google_compute_network.vpc_network.self_link
  subnetwork = google_compute_subnetwork.network-with-private-secondary-ip-ranges.self_link
  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "my-node-pool"
  location   = "europe-north1"
  cluster    = google_container_cluster.primary.name
  node_count = 1
  version    = data.google_container_engine_versions.gke-versions.latest_node_version


  node_config {

    preemptible     = true
    machine_type    = "n1-standard-1"
    service_account = "terraform-shamops@svg-devops-training-2.iam.gserviceaccount.com"

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}


