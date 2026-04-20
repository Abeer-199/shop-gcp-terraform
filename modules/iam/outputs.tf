output "sa_email" {
  description = "Service Account email"
  value       = google_service_account.vm_sa.email
}

output "sa_name" {
  description = "Service Account name"
  value       = google_service_account.vm_sa.name
}
