# ============================================================================
# Outputs
# ============================================================================

output "rds_endpoint" {
  description = "RDS endpoint with port"
  value       = "${aws_db_instance.main.address}:${aws_db_instance.main.port}"
}

output "rds_port" {
  description = "RDS database port"
  value       = aws_db_instance.main.port
}

output "rds_vpc_id" {
  description = "VPC ID for RDS"
  value       = aws_vpc.rds_vpc.id
}

output "vpn_vpc_id" {
  description = "VPC ID for VPN"
  value       = aws_vpc.vpn_vpc.id
}

output "client_vpn_endpoint_id" {
  description = "ID of the AWS Client VPN endpoint"
  value       = aws_ec2_client_vpn_endpoint.main.id
}

output "client_vpn_dns_name" {
  description = "DNS name of the AWS Client VPN endpoint"
  value       = aws_ec2_client_vpn_endpoint.main.dns_name
}

output "ca_certificate" {
  description = "CA root certificate (PEM)"
  value       = tls_self_signed_cert.ca.cert_pem
  sensitive   = true
}

output "client_certificate" {
  description = "Client certificate (PEM)"
  value       = tls_locally_signed_cert.client.cert_pem
  sensitive   = true
}

output "client_private_key" {
  description = "Client private key (PEM)"
  value       = tls_private_key.client.private_key_pem
  sensitive   = true
}

output "connection_info" {
  description = "Summary of key connection details"
  value = {
    client_vpn_cidr  = aws_ec2_client_vpn_endpoint.main.client_cidr_block
    rds_endpoint     = "${aws_db_instance.main.address}:${aws_db_instance.main.port}"
    rds_private_cidr = "10.170.150.0/23"
    database_name    = aws_db_instance.main.db_name
    username         = aws_db_instance.main.username
  }
}
