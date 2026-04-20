variable "project_id"    { type = string }
variable "region"        { type = string }
variable "app_name"      { type = string }
variable "machine_type"  { type = string }
variable "network_name"  { type = string }
variable "subnet_name"   { type = string }
variable "sa_email"      { type = string }
variable "bucket_name"   { type = string }
variable "db_ip"         { type = string }
variable "db_password"   {
  type      = string
  sensitive = true
}
variable "min_replicas" { type = number }
variable "max_replicas" { type = number }
variable "cpu_target"   { type = number }
