# ================================================================
# modules/storage/main.tf
# Private GCS Bucket — with product images uploaded automatically
# ================================================================

# Random suffix to ensure unique bucket name
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# ---------------------------------------------------------------
# GCS Bucket (Private)
# ---------------------------------------------------------------
resource "google_storage_bucket" "bucket" {
  name                        = "${var.project_id}-${var.app_name}-assets-${random_id.bucket_suffix.hex}"
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true

  versioning {
    enabled = false
  }

  lifecycle_rule {
    condition { age = 30 }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  labels = {
    app        = var.app_name
    managed_by = "terraform"
  }
}

# ---------------------------------------------------------------
# Grant SA access to bucket
# ---------------------------------------------------------------
resource "google_storage_bucket_iam_member" "sa_admin" {
  bucket = google_storage_bucket.bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.sa_email}"
}

# ---------------------------------------------------------------
# Product SVG images (auto-generated + uploaded)
# ---------------------------------------------------------------
locals {
  products = {
    "iphone"     = { emoji = "📱", color = "#e3f2fd", name = "iPhone 15 Pro" }
    "samsung"    = { emoji = "📱", color = "#f3e5f5", name = "Galaxy S24" }
    "macbook"    = { emoji = "💻", color = "#fff3e0", name = "MacBook Pro" }
    "headphones" = { emoji = "🎧", color = "#e8f5e9", name = "Sony Headphones" }
    "ipad"       = { emoji = "📱", color = "#fce4ec", name = "iPad Pro" }
  }
}

resource "google_storage_bucket_object" "product_images" {
  for_each = local.products

  name         = "products/${each.key}.svg"
  bucket       = google_storage_bucket.bucket.name
  content_type = "image/svg+xml"

  content = <<-EOT
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="${each.value.color}"/>
      <stop offset="100%" stop-color="#ffffff"/>
    </linearGradient>
  </defs>
  <rect width="400" height="400" fill="url(#bg)"/>
  <text x="200" y="200" font-size="180" text-anchor="middle" dominant-baseline="central">${each.value.emoji}</text>
  <text x="200" y="340" font-size="28" font-family="Arial" font-weight="bold"
        text-anchor="middle" fill="#1a1a1a">${each.value.name}</text>
</svg>
  EOT
}

# ---------------------------------------------------------------
# Upload app code files (backend.py, index.html, etc.)
# ---------------------------------------------------------------
resource "google_storage_bucket_object" "app_backend" {
  name         = "app-code/backend.py"
  bucket       = google_storage_bucket.bucket.name
  source       = "${path.module}/../../app/backend.py"
  content_type = "text/x-python"
}

resource "google_storage_bucket_object" "app_frontend" {
  name         = "app-code/index.html"
  bucket       = google_storage_bucket.bucket.name
  source       = "${path.module}/../../app/index.html"
  content_type = "text/html"
}

resource "google_storage_bucket_object" "app_nginx" {
  name         = "app-code/nginx.conf"
  bucket       = google_storage_bucket.bucket.name
  source       = "${path.module}/../../app/nginx.conf"
  content_type = "text/plain"
}

resource "google_storage_bucket_object" "app_requirements" {
  name         = "app-code/requirements.txt"
  bucket       = google_storage_bucket.bucket.name
  source       = "${path.module}/../../app/requirements.txt"
  content_type = "text/plain"
}
