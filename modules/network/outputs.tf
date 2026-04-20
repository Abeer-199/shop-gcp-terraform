output "web_vpc_id"        { value = google_compute_network.web_vpc.id }
output "web_vpc_name"      { value = google_compute_network.web_vpc.name }
output "web_subnet_id"     { value = google_compute_subnetwork.web_subnet.id }
output "web_subnet_name"   { value = google_compute_subnetwork.web_subnet.name }
output "db_vpc_id"         { value = google_compute_network.db_vpc.id }
output "db_vpc_name"       { value = google_compute_network.db_vpc.name }
output "db_subnet_id"      { value = google_compute_subnetwork.db_subnet.id }
output "db_subnet_name"    { value = google_compute_subnetwork.db_subnet.name }
