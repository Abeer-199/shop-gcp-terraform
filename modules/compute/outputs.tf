output "lb_ip" {
  description = "Global Load Balancer External IP"
  value       = google_compute_global_address.lb_ip.address
}

output "mig_name" {
  description = "Managed Instance Group name"
  value       = google_compute_region_instance_group_manager.web.name
}

output "instance_template_name" {
  description = "Instance Template name"
  value       = google_compute_instance_template.web.name
}

output "backend_service_name" {
  description = "Backend service name"
  value       = google_compute_backend_service.web.name
}
