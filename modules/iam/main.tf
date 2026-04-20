# ================================================================
# modules/iam/main.tf
# Service Account for VMs with least-privilege IAM
# ================================================================

# ---------------------------------------------------------------
# Service Account for Web VMs
# ---------------------------------------------------------------
resource "google_service_account" "vm_sa" {
  account_id   = "${var.app_name}-vm-sa"
  display_name = "${var.app_name} VM Service Account"
  description  = "Service account used by web VMs for GCS + signed URLs"
}

# ---------------------------------------------------------------
# Project-level IAM roles
# ---------------------------------------------------------------
resource "google_project_iam_member" "sa_roles" {
  for_each = toset([
    "roles/iam.serviceAccountTokenCreator",  # For signed URLs
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.vm_sa.email}"
}

# ---------------------------------------------------------------
# Allow SA to sign blobs on itself (for signed URLs)
# ---------------------------------------------------------------
resource "google_service_account_iam_member" "sa_self_signer" {
  service_account_id = google_service_account.vm_sa.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.vm_sa.email}"
}
