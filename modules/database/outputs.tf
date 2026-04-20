output "db_vm_name" {
  description = "Database VM name"
  value       = google_compute_instance.db.name
}

output "db_private_ip" {
  description = "Database VM private IP address"
  value       = google_compute_instance.db.network_interface[0].network_ip
}
