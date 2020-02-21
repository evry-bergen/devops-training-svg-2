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

resource "google_compute_router_nat" "nat" {
  name                               = "my-router-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}


resource "google_compute_router" "router" {
  name    = "my-router"
  region  = "europe-north1"
  network = google_compute_network.vpc_network.self_link

  bgp {
    asn = 64514
  }
}


resource "google_compute_firewall" "pgsql" {
  name    = "test-firewall-pgsql"
  network = google_compute_network.vpc_network.name


  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  target_tags   = ["database"]
  source_tags   = ["backend"]
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]

}



resource "google_compute_firewall" "ssh" {
  name    = "test-firewall-ssh"
  network = google_compute_network.vpc_network.name


  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = ["database", "backend", "frontend"]


}

resource "google_compute_instance_group" "frontendig" {
  name        = "frontendig"
  description = "frontendig"
  zone        = "europe-north1-a"

  instances = google_compute_instance.vm_instance.*.self_link


  network = google_compute_network.vpc_network.self_link
}





resource "google_compute_instance_group" "backendig" {
  name        = "backendig"
  description = "backendig"
  zone        = "europe-north1-a"
  network     = google_compute_network.vpc_network.self_link
  instances   = google_compute_instance.backend_vms.*.self_link


}





resource "google_compute_health_check" "postgresql-hc" {
  name = "tcp-health-check"

  timeout_sec        = 10
  check_interval_sec = 10

  tcp_health_check {
    port = "5432"
  }
}




resource "google_compute_region_backend_service" "db-backend" {
  region   = "europe-north1"
  name     = "dbbackend"
  protocol = "TCP"


  health_checks = [google_compute_health_check.postgresql-hc.self_link]

  backend {
    group = google_compute_instance_group.databaseig.self_link
  }
}
# resource "google_compute_global_forwarding_rule" "fe-forwarding-rule" {

#   name                  = "fe-forwarding-rule"

#   load_balancing_scheme = "EXTERNAL"

#   port_range = "80"



# }



resource "google_compute_forwarding_rule" "db-forwarding-rule" {

  name                  = "db-forwarding-rule"
  region                = "europe-north1"
  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.db-backend.self_link
  all_ports             = true

  network    = google_compute_network.vpc_network.self_link
  subnetwork = google_compute_subnetwork.db-network.self_link
}

resource "google_compute_forwarding_rule" "middleware-forwarding-rule" {

  name                  = "backend-forwarding-rule"
  region                = "europe-north1"
  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.middleware-backend.self_link
  all_ports             = true

  network    = google_compute_network.vpc_network.self_link
  subnetwork = google_compute_subnetwork.backend-network.self_link
}


resource "google_compute_region_backend_service" "middleware-backend" {
  region = "europe-north1"
  name   = "middlewarebackend"


  health_checks = [google_compute_health_check.http-health-check.self_link]

  backend {
    group = google_compute_instance_group.backendig.self_link
  }
}




# Frontend LB

resource "google_compute_global_forwarding_rule" "default" {
  name       = "global-rule"
  target     = google_compute_target_http_proxy.default.self_link
  port_range = "80"
}

resource "google_compute_target_http_proxy" "default" {
  name        = "target-proxy"
  description = "a description"
  url_map     = google_compute_url_map.default.self_link
}

resource "google_compute_url_map" "default" {
  name            = "url-map-target-proxy"
  description     = "a description"
  default_service = google_compute_backend_service.frontend-backend.self_link


}

# end Frontend LB


resource "google_compute_backend_service" "frontend-backend" {

  name     = "frontendebackend"
  protocol = "HTTP"


  health_checks = [google_compute_health_check.http-health-check.self_link]

  backend {
    balancing_mode = "UTILIZATION"
    group          = google_compute_instance_group.frontendig.self_link
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

resource "google_compute_http_health_check" "real-http" {
  name               = "example-name"
  request_path       = "/"
  timeout_sec        = 1
  check_interval_sec = 1
}

resource "google_compute_instance_group" "databaseig" {
  name        = "databaseig"
  description = "databaseig"
  zone        = "europe-north1-a"
  network     = google_compute_network.vpc_network.self_link
  instances   = google_compute_instance.database_vms.*.self_link


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
  metadata_startup_script = "sudo apt-get -y update && sudo apt-get -y install postgresql"


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
  metadata_startup_script = "sudo apt-get -y update && sudo apt-get -y install nginx && sudo service nginx start"


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
  metadata_startup_script = "sudo apt-get -y update && sudo apt-get -y install nginx && sudo service nginx start"


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