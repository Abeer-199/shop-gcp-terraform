output "bucket_name" {
  description = "GCS Bucket name"
  value       = google_storage_bucket.bucket.name
}

output "bucket_url" {
  description = "GCS Bucket URL"
  value       = google_storage_bucket.bucket.url
}
