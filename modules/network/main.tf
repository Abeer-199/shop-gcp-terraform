# ================================================================
# modules/network/main.tf
# Multi-VPC: Web VPC + DB VPC + Peering + NAT
# ================================================================

# ---------------------------------------------------------------
# 🌐 Web VPC (10.0.0.0/16)
# ---------------------------------------------------------------
resource "google_compute_network" "web_vpc" {
  name                    = "${var.app_name}-web-vpc"
  auto_create_subnetworks = false
  description             = "Web tier VPC"
}

resource "google_compute_subnetwork" "web_subnet" {
  name          = "${var.app_name}-web-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.web_vpc.id
}

# ---------------------------------------------------------------
# 🔒 DB VPC (10.1.0.0/16)
# ---------------------------------------------------------------
resource "google_compute_network" "db_vpc" {
  name                    = "${var.app_name}-db-vpc"
  auto_create_subnetworks = false
  description             = "Database tier VPC (isolated)"
}

resource "google_compute_subnetwork" "db_subnet" {
  name                     = "${var.app_name}-db-subnet"
  ip_cidr_range            = "10.1.1.0/24"
  region                   = var.region
  network                  = google_compute_network.db_vpc.id
  private_ip_google_access = true
}

# ---------------------------------------------------------------
# 🔗 VPC Peering (bidirectional)
# ---------------------------------------------------------------
resource "google_compute_network_peering" "web_to_db" {
  name         = "${var.app_name}-web-to-db"
  network      = google_compute_network.web_vpc.id
  peer_network = google_compute_network.db_vpc.id
}

resource "google_compute_network_peering" "db_to_web" {
  name         = "${var.app_name}-db-to-web"
  network      = google_compute_network.db_vpc.id
  peer_network = google_compute_network.web_vpc.id
}

# ---------------------------------------------------------------
# 🌍 Cloud Router + NAT (for DB VPC outbound)
# ---------------------------------------------------------------
resource "google_compute_router" "db_router" {
  name    = "${var.app_name}-db-router"
  region  = var.region
  network = google_compute_network.db_vpc.id
}

resource "google_compute_router_nat" "db_nat" {
  name                               = "${var.app_name}-db-nat"
  router                             = google_compute_router.db_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# ===============================================================
# 🔥 Firewall Rules — Web VPC
# ===============================================================

# Allow HTTP from internet (only to web-server VMs)
resource "google_compute_firewall" "web_allow_http" {
  name          = "${var.app_name}-web-allow-http"
  network       = google_compute_network.web_vpc.name
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web-server"]

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

# Allow Google Health Check IPs
resource "google_compute_firewall" "web_allow_health_checks" {
  name          = "${var.app_name}-web-allow-health-checks"
  network       = google_compute_network.web_vpc.name
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["web-server"]

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

# Allow SSH via IAP only
resource "google_compute_firewall" "web_allow_ssh_iap" {
  name          = "${var.app_name}-web-allow-ssh-iap"
  network       = google_compute_network.web_vpc.name
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["35.235.240.0/20"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# Allow internal traffic within Web VPC
resource "google_compute_firewall" "web_allow_internal" {
  name          = "${var.app_name}-web-allow-internal"
  network       = google_compute_network.web_vpc.name
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["10.0.0.0/16"]

  allow { protocol = "tcp" }
  allow { protocol = "udp" }
  allow { protocol = "icmp" }
}

# ===============================================================
# 🔥 Firewall Rules — DB VPC
# ===============================================================

# Allow MySQL ONLY from Web VPC (10.0.0.0/16)
resource "google_compute_firewall" "db_allow_mysql_from_web" {
  name          = "${var.app_name}-db-allow-mysql-from-web"
  network       = google_compute_network.db_vpc.name
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["10.0.0.0/16"]
  target_tags   = ["mysql-server"]

  allow {
    protocol = "tcp"
    ports    = ["3306"]
  }
}

# Allow SSH via IAP
resource "google_compute_firewall" "db_allow_ssh_iap" {
  name          = "${var.app_name}-db-allow-ssh-iap"
  network       = google_compute_network.db_vpc.name
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["35.235.240.0/20"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# Internal DB VPC traffic
resource "google_compute_firewall" "db_allow_internal" {
  name          = "${var.app_name}-db-allow-internal"
  network       = google_compute_network.db_vpc.name
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["10.1.0.0/16"]

  allow { protocol = "tcp" }
  allow { protocol = "udp" }
  allow { protocol = "icmp" }
}
