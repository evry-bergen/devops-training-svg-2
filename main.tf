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

resource "google_compute_instance_group" "frontendig" {
  name        = "frontendig"
  description = "frontendig"
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





resource "google_compute_instance_group" "backendig" {
  name        = "backendig"
  description = "backendig"
  zone        = "europe-north1-a"
  network     = google_compute_network.vpc_network.self_link
  instances   = google_compute_instance.backend_vms.*.self_link

  named_port {
    name = "http"
    port = "8080"
  }

  named_port {
    name = "https"
    port = "8443"
  }
}





resource "google_compute_health_check" "postgresql-hc" {
  name = "tcp-health-check"

  timeout_sec        = 100
  check_interval_sec = 100

  tcp_health_check {
    port = "5432"
  }
}


resource "google_compute_backend_service" "db-backend" {
  name          = "dbbackend"
  protocol      = "TCP"
  health_checks = [google_compute_health_check.postgresql-hc.self_link]

  backend {
    group = google_compute_instance_group.databaseig.self_link
  }
}



resource "google_compute_backend_service" "middleware-backend" {
  name          = "middlewarebackend"
  health_checks = [google_compute_health_check.http-health-check.self_link]

  backend {
    group = google_compute_instance_group.backendig.self_link
  }

}




resource "google_compute_health_check" "http-health-check" {
  name = "http-health-check"

  timeout_sec        = 1
  check_interval_sec = 1

  http_health_check {
    port = 80
  }
}

resource "google_compute_instance_group" "databaseig" {
  name        = "databaseig"
  description = "databaseig"
  zone        = "europe-north1-a"
  network     = google_compute_network.vpc_network.self_link
  instances   = google_compute_instance.database_vms.*.self_link

  named_port {
    name = "http"
    port = "8080"
  }

  named_port {
    name = "https"
    port = "8443"
  }
}


resource "google_compute_instance" "database_vms" {
  count        = 3
  name         = "databasevm${count.index}"
  machine_type = "g1-small"
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }
  network_interface {
    network    = google_compute_network.vpc_network.self_link
    subnetwork = google_compute_subnetwork.db-network.self_link
  }
  tags                    = ["database"]
  metadata_startup_script = "sudo apt get -y update && sudo apt-get -y install nginx && sudo service nginx start"


}


resource "google_compute_instance" "backend_vms" {
  count        = 3
  name         = "backendvm${count.index}"
  machine_type = "g1-small"
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }
  network_interface {
    network    = google_compute_network.vpc_network.self_link
    subnetwork = google_compute_subnetwork.backend-network.self_link
  }
  tags                    = ["backend"]
  metadata_startup_script = "sudo apt get -y update && sudo apt-get -y install nginx && sudo service nginx start"


}


resource "google_compute_instance" "vm_instance" {
  count        = 3
  name         = "frontendvm${count.index}"
  machine_type = "g1-small"
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }
  network_interface {
    network    = google_compute_network.vpc_network.self_link
    subnetwork = google_compute_subnetwork.frontend-network.self_link
  }
  tags                    = ["frontend"]
  metadata_startup_script = "sudo apt get -y update"


}


resource "google_compute_subnetwork" "frontend-network" {
  name          = "frontend-subnetwork"
  ip_cidr_range = "10.0.10.0/24"
  region        = "europe-north1"
  network       = google_compute_network.vpc_network.self_link

}

resource "google_compute_subnetwork" "backend-network" {
  name          = "backend-subnetwork"
  ip_cidr_range = "10.0.20.0/24"
  region        = "europe-north1"
  network       = google_compute_network.vpc_network.self_link

}

resource "google_compute_subnetwork" "db-network" {
  name          = "db-subnetwork"
  ip_cidr_range = "10.0.30.0/24"
  region        = "europe-north1"
  network       = google_compute_network.vpc_network.self_link

}

resource "google_compute_network" "vpc_network" {
  name                    = "my-name"
  auto_create_subnetworks = "false"
}