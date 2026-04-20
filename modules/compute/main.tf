# ================================================================
# modules/compute/main.tf
# Instance Template + MIG + Autoscaling + Global HTTP Load Balancer
# ================================================================

# ---------------------------------------------------------------
# Instance Template
# ---------------------------------------------------------------
resource "google_compute_instance_template" "web" {
  name_prefix  = "${var.app_name}-web-"
  machine_type = var.machine_type
  tags         = ["web-server"]

  disk {
    source_image = "debian-cloud/debian-12"
    auto_delete  = true
    boot         = true
    disk_size_gb = 20
    disk_type    = "pd-balanced"
  }

  network_interface {
    network    = var.network_name
    subnetwork = var.subnet_name

    # Public IP for outbound (apt install, GCS access)
    access_config {}
  }

  # Startup script — installs everything
  metadata = {
    startup-script = templatefile("${path.module}/../../scripts/web-startup.sh", {
      bucket_name = var.bucket_name
      db_ip       = var.db_ip
      db_password = var.db_password
    })
    enable-oslogin = "TRUE"
  }

  service_account {
    email  = var.sa_email
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  lifecycle {
    create_before_destroy = true
  }

  labels = {
    app        = var.app_name
    role       = "web"
    managed_by = "terraform"
  }
}

# ---------------------------------------------------------------
# Health Check
# ---------------------------------------------------------------
resource "google_compute_health_check" "web" {
  name                = "${var.app_name}-web-hc"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 80
    request_path = "/health"
  }
}

# ---------------------------------------------------------------
# Regional (Multi-Zone) Managed Instance Group
# ---------------------------------------------------------------
resource "google_compute_region_instance_group_manager" "web" {
  name               = "${var.app_name}-web-mig"
  base_instance_name = "${var.app_name}-web"
  region             = var.region

  version {
    instance_template = google_compute_instance_template.web.self_link
  }

  named_port {
    name = "http"
    port = 80
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.web.id
    initial_delay_sec = 300 # 5 min for startup script
  }

  update_policy {
    type                           = "PROACTIVE"
    minimal_action                 = "REPLACE"
    max_surge_fixed                = 3
    max_unavailable_fixed          = 0
    replacement_method             = "SUBSTITUTE"
    instance_redistribution_type   = "PROACTIVE"
  }
}

# ---------------------------------------------------------------
# Autoscaler (CPU-based)
# ---------------------------------------------------------------
resource "google_compute_region_autoscaler" "web" {
  name   = "${var.app_name}-web-autoscaler"
  region = var.region
  target = google_compute_region_instance_group_manager.web.id

  autoscaling_policy {
    max_replicas    = var.max_replicas
    min_replicas    = var.min_replicas
    cooldown_period = 90

    cpu_utilization {
      target = var.cpu_target
    }
  }
}

# ===============================================================
# 🌐 Global HTTP Load Balancer
# ===============================================================

# Global Static IP
resource "google_compute_global_address" "lb_ip" {
  name = "${var.app_name}-lb-ip"
}

# Backend Service
resource "google_compute_backend_service" "web" {
  name                  = "${var.app_name}-web-backend"
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL"

  health_checks = [google_compute_health_check.web.id]

  backend {
    group           = google_compute_region_instance_group_manager.web.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# URL Map
resource "google_compute_url_map" "web" {
  name            = "${var.app_name}-url-map"
  default_service = google_compute_backend_service.web.id
}

# HTTP Proxy
resource "google_compute_target_http_proxy" "web" {
  name    = "${var.app_name}-http-proxy"
  url_map = google_compute_url_map.web.id
}

# Global Forwarding Rule
resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${var.app_name}-http-rule"
  target                = google_compute_target_http_proxy.web.id
  port_range            = "80"
  ip_address            = google_compute_global_address.lb_ip.address
  load_balancing_scheme = "EXTERNAL"
}
