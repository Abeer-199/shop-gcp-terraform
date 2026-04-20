# ================================================================
# main.tf — Root Module
# ================================================================

# ---------------------------------------------------------------
# Enable required GCP APIs
# ---------------------------------------------------------------
resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "storage.googleapis.com",
    "iap.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

# ---------------------------------------------------------------
# 1. Networking — VPCs, Subnets, Firewall, Peering, NAT
# ---------------------------------------------------------------
module "network" {
  source = "./modules/network"

  project_id = var.project_id
  region     = var.region
  app_name   = var.app_name

  depends_on = [google_project_service.apis]
}

# ---------------------------------------------------------------
# 2. IAM — Service Account
# ---------------------------------------------------------------
module "iam" {
  source = "./modules/iam"

  project_id = var.project_id
  app_name   = var.app_name

  depends_on = [google_project_service.apis]
}

# ---------------------------------------------------------------
# 3. Storage — GCS Bucket (private)
# ---------------------------------------------------------------
module "storage" {
  source = "./modules/storage"

  project_id = var.project_id
  region     = var.region
  app_name   = var.app_name
  sa_email   = module.iam.sa_email

  depends_on = [module.iam]
}

# ---------------------------------------------------------------
# 4. Database — MariaDB VM (no external IP)
# ---------------------------------------------------------------
module "database" {
  source = "./modules/database"

  project_id   = var.project_id
  region       = var.region
  zone         = var.zone
  app_name     = var.app_name
  machine_type = var.db_machine_type
  network_id   = module.network.db_vpc_id
  subnet_id    = module.network.db_subnet_id
  db_password  = var.db_password

  depends_on = [module.network]
}

# ---------------------------------------------------------------
# 5. Compute — Instance Template, MIG, Load Balancer
# ---------------------------------------------------------------
module "compute" {
  source = "./modules/compute"

  project_id       = var.project_id
  region           = var.region
  app_name         = var.app_name
  machine_type     = var.web_machine_type
  network_name     = module.network.web_vpc_name
  subnet_name      = module.network.web_subnet_name
  sa_email         = module.iam.sa_email
  bucket_name      = module.storage.bucket_name
  db_ip            = module.database.db_private_ip
  db_password      = var.db_password
  min_replicas     = var.min_replicas
  max_replicas     = var.max_replicas
  cpu_target       = var.cpu_target

  depends_on = [
    module.network,
    module.iam,
    module.storage,
    module.database,
  ]
}
