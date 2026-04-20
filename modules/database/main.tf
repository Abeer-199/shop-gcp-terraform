# ================================================================
# modules/database/main.tf
# MariaDB VM — no external IP, private subnet
# ================================================================

resource "google_compute_instance" "db" {
  name         = "${var.app_name}-db"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["mysql-server"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    network    = var.network_id
    subnetwork = var.subnet_id
    # 🔒 No access_config = no external IP
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  # Startup script to install and configure MariaDB
  metadata_startup_script = templatefile("${path.module}/../../scripts/db-startup.sh", {
    db_password = var.db_password
  })

  service_account {
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  allow_stopping_for_update = true

  labels = {
    app        = var.app_name
    role       = "database"
    managed_by = "terraform"
  }
}
