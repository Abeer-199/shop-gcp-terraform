variable "project_id"   { type = string }
variable "region"       { type = string }
variable "zone"         { type = string }
variable "app_name"     { type = string }
variable "machine_type" { type = string }
variable "network_id"   { type = string }
variable "subnet_id"    { type = string }
variable "db_password"  {
  type      = string
  sensitive = true
}
