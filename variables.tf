# ================================================================
# variables.tf — Root Variables
# ================================================================

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-east4"
}

variable "zone" {
  description = "Primary GCP Zone"
  type        = string
  default     = "us-east4-a"
}

variable "app_name" {
  description = "Application name (used as prefix)"
  type        = string
  default     = "shop"
}

variable "db_password" {
  description = "MariaDB application user password"
  type        = string
  sensitive   = true
  default     = "AppPass123!"
}

variable "db_machine_type" {
  description = "Machine type for database VM"
  type        = string
  default     = "e2-medium"
}

variable "web_machine_type" {
  description = "Machine type for web VMs"
  type        = string
  default     = "e2-medium"
}

variable "min_replicas" {
  description = "Minimum number of web VMs"
  type        = number
  default     = 2
}

variable "max_replicas" {
  description = "Maximum number of web VMs"
  type        = number
  default     = 6
}

variable "cpu_target" {
  description = "Target CPU utilization for autoscaling (0.0 - 1.0)"
  type        = number
  default     = 0.65
}
