# ================================================================
# outputs.tf — Root Outputs
# ================================================================

output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "load_balancer_ip" {
  description = "🌐 Load Balancer External IP"
  value       = module.compute.lb_ip
}

output "website_url" {
  description = "🎉 Website URL — open this in browser"
  value       = "http://${module.compute.lb_ip}"
}

output "db_private_ip" {
  description = "Database VM internal IP"
  value       = module.database.db_private_ip
  sensitive   = true
}

output "db_vm_name" {
  description = "Database VM name"
  value       = module.database.db_vm_name
}

output "bucket_name" {
  description = "GCS Bucket name"
  value       = module.storage.bucket_name
}

output "service_account" {
  description = "Service Account email"
  value       = module.iam.sa_email
}

output "mig_name" {
  description = "Managed Instance Group name"
  value       = module.compute.mig_name
}

output "ssh_to_db_command" {
  description = "Command to SSH to Database VM"
  value       = "gcloud compute ssh ${module.database.db_vm_name} --zone=${var.zone} --tunnel-through-iap"
}

output "view_instances_command" {
  description = "List all instances in MIG"
  value       = "gcloud compute instance-groups managed list-instances ${module.compute.mig_name} --region=${var.region}"
}

output "next_steps" {
  description = "What to do after terraform apply"
  value       = <<-EOT
  
  ✅ Infrastructure deployed successfully!
  
  🌐 Website URL:     http://${module.compute.lb_ip}
  📦 Bucket:          gs://${module.storage.bucket_name}
  💾 Database VM:     ${module.database.db_vm_name}
  
  ⏳ Wait 3-5 minutes for:
     - MariaDB installation on DB VM
     - Web VMs to pull app code and start
     - Load Balancer health checks to pass
  
  🧪 Verify:
     curl http://${module.compute.lb_ip}/api/health
  
  🔧 Troubleshoot:
     gcloud compute ssh ${module.database.db_vm_name} --zone=${var.zone} --tunnel-through-iap
  
  EOT
}
