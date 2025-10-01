# ============================================================================
# Provider Configuration
# ============================================================================
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ============================================================================
# RDS VPC (10.170.144.0/20)
# ============================================================================

resource "aws_vpc" "rds_vpc" {
  cidr_block           = "10.170.144.0/20"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "rds-vpc" }
}

resource "aws_internet_gateway" "rds_igw" {
  vpc_id = aws_vpc.rds_vpc.id
  tags   = { Name = "rds-igw" }
}

resource "aws_subnet" "rds_public" {
  count                   = 2
  vpc_id                  = aws_vpc.rds_vpc.id
  cidr_block              = "10.170.${146 + count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "rds-public-${count.index + 1}" }
}

resource "aws_subnet" "rds_private" {
  count             = 2
  vpc_id            = aws_vpc.rds_vpc.id
  cidr_block        = "10.170.${150 + count.index}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags              = { Name = "rds-private-${count.index + 1}" }
}

resource "aws_eip" "rds_nat" {
  domain = "vpc"
  tags   = { Name = "rds-nat-eip" }
}

resource "aws_nat_gateway" "rds_nat" {
  allocation_id = aws_eip.rds_nat.id
  subnet_id     = aws_subnet.rds_public[0].id
  tags          = { Name = "rds-nat-gateway" }
}

resource "aws_route_table" "rds_public" {
  vpc_id = aws_vpc.rds_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.rds_igw.id
  }
  tags = { Name = "rds-public-rt" }
}

resource "aws_route_table" "rds_private" {
  vpc_id = aws_vpc.rds_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.rds_nat.id
  }
  tags = { Name = "rds-private-rt" }
}

resource "aws_route_table_association" "rds_public" {
  count          = 2
  subnet_id      = aws_subnet.rds_public[count.index].id
  route_table_id = aws_route_table.rds_public.id
}

resource "aws_route_table_association" "rds_private" {
  count          = 2
  subnet_id      = aws_subnet.rds_private[count.index].id
  route_table_id = aws_route_table.rds_private.id
}

# ============================================================================
# VPN VPC (10.170.160.0/24)
# ============================================================================

resource "aws_vpc" "vpn_vpc" {
  cidr_block           = "10.170.160.0/24"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "vpn-vpc" }
}

resource "aws_internet_gateway" "vpn_igw" {
  vpc_id = aws_vpc.vpn_vpc.id
  tags   = { Name = "vpn-igw" }
}

resource "aws_subnet" "vpn_public" {
  count                   = 2
  vpc_id                  = aws_vpc.vpn_vpc.id
  cidr_block              = "10.170.160.${count.index * 64}/26"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "vpn-public-${count.index + 1}" }
}

resource "aws_subnet" "vpn_private" {
  count             = 2
  vpc_id            = aws_vpc.vpn_vpc.id
  cidr_block        = "10.170.160.${128 + count.index * 64}/26"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags              = { Name = "vpn-private-${count.index + 1}" }
}

resource "aws_route_table" "vpn_public" {
  vpc_id = aws_vpc.vpn_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpn_igw.id
  }
  tags = { Name = "vpn-public-rt" }
}

resource "aws_route_table" "vpn_private" {
  vpc_id = aws_vpc.vpn_vpc.id
  tags   = { Name = "vpn-private-rt" }
}

resource "aws_route_table_association" "vpn_public" {
  count          = 2
  subnet_id      = aws_subnet.vpn_public[count.index].id
  route_table_id = aws_route_table.vpn_public.id
}

resource "aws_route_table_association" "vpn_private" {
  count          = 2
  subnet_id      = aws_subnet.vpn_private[count.index].id
  route_table_id = aws_route_table.vpn_private.id
}

# ============================================================================
# VPC Peering
# ============================================================================

resource "aws_vpc_peering_connection" "rds_to_vpn" {
  peer_vpc_id = aws_vpc.vpn_vpc.id
  vpc_id      = aws_vpc.rds_vpc.id
  auto_accept = true
  tags        = { Name = "rds-to-vpn-peering" }
}

resource "aws_route" "rds_to_vpn" {
  route_table_id            = aws_route_table.rds_private.id
  destination_cidr_block    = aws_vpc.vpn_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.rds_to_vpn.id
}

resource "aws_route" "vpn_to_rds" {
  route_table_id            = aws_route_table.vpn_private.id
  destination_cidr_block    = "10.170.150.0/23"
  vpc_peering_connection_id = aws_vpc_peering_connection.rds_to_vpn.id
}

resource "aws_route" "rds_to_vpn_clients" {
  route_table_id            = aws_route_table.rds_private.id
  destination_cidr_block    = "10.170.240.0/22"
  vpc_peering_connection_id = aws_vpc_peering_connection.rds_to_vpn.id
}

# ============================================================================
# Certificates
# ============================================================================

resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem
  subject {
    common_name  = "rds-vpn-ca.local"
    organization = "RDS VPN CA"
  }
  validity_period_hours = 8760
  is_ca_certificate     = true
  allowed_uses          = ["key_encipherment", "digital_signature", "cert_signing"]
}

resource "tls_private_key" "server" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "server" {
  private_key_pem = tls_private_key.server.private_key_pem
  subject {
    common_name  = "server.rds-vpn.local"
    organization = "RDS VPN Server"
  }
  dns_names = ["server.rds-vpn.local", "vpn-server.local"]
}

resource "tls_locally_signed_cert" "server" {
  cert_request_pem      = tls_cert_request.server.cert_request_pem
  ca_private_key_pem    = tls_private_key.ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  validity_period_hours = 8760
  allowed_uses          = ["key_encipherment", "digital_signature", "server_auth"]
}

resource "tls_private_key" "client" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "client" {
  private_key_pem = tls_private_key.client.private_key_pem
  subject {
    common_name  = "client.rds-vpn.local"
    organization = "RDS VPN Client"
  }
  dns_names = ["client.rds-vpn.local", "vpn-client.local"]
}

resource "tls_locally_signed_cert" "client" {
  cert_request_pem      = tls_cert_request.client.cert_request_pem
  ca_private_key_pem    = tls_private_key.ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  validity_period_hours = 8760
  allowed_uses          = ["key_encipherment", "digital_signature", "client_auth"]
}

resource "aws_acm_certificate" "server" {
  private_key       = tls_private_key.server.private_key_pem
  certificate_body  = tls_locally_signed_cert.server.cert_pem
  certificate_chain = tls_self_signed_cert.ca.cert_pem
  tags              = { Name = "client-vpn-server" }
}

resource "aws_acm_certificate" "client" {
  private_key       = tls_private_key.client.private_key_pem
  certificate_body  = tls_locally_signed_cert.client.cert_pem
  certificate_chain = tls_self_signed_cert.ca.cert_pem
  tags              = { Name = "client-vpn-client" }
}

# ============================================================================
# Client VPN
# ============================================================================

resource "aws_ec2_client_vpn_endpoint" "main" {
  description            = "RDS Access Client VPN"
  server_certificate_arn = aws_acm_certificate.server.arn
  client_cidr_block      = "10.170.240.0/22"
  split_tunnel           = true

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.client.arn
  }

  connection_log_options { enabled = false }

  dns_servers = ["8.8.8.8", "1.1.1.1"]

  tags = { Name = "rds-client-vpn" }
}

resource "aws_ec2_client_vpn_network_association" "main" {
  count                  = 2
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  subnet_id              = aws_subnet.vpn_private[count.index].id
}

resource "aws_ec2_client_vpn_authorization_rule" "vpn_subnet" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  target_network_cidr    = "10.170.160.0/24"
  authorize_all_groups   = true
  depends_on             = [aws_ec2_client_vpn_network_association.main]
}

resource "aws_ec2_client_vpn_authorization_rule" "rds_access" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  target_network_cidr    = "10.170.150.0/23"
  authorize_all_groups   = true
  depends_on             = [aws_ec2_client_vpn_network_association.main]
}

resource "aws_ec2_client_vpn_route" "rds_route_1" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  destination_cidr_block = "10.170.150.0/23"
  target_vpc_subnet_id   = aws_subnet.vpn_private[0].id
  depends_on             = [aws_ec2_client_vpn_network_association.main, aws_vpc_peering_connection.rds_to_vpn]
}

resource "aws_ec2_client_vpn_route" "rds_route_2" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  destination_cidr_block = "10.170.150.0/23"
  target_vpc_subnet_id   = aws_subnet.vpn_private[1].id
  depends_on             = [aws_ec2_client_vpn_network_association.main, aws_vpc_peering_connection.rds_to_vpn]
}

# ============================================================================
# RDS Instance
# ============================================================================

resource "aws_security_group" "rds" {
  name_prefix = "rds-sg"
  vpc_id      = aws_vpc.rds_vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.170.240.0/22", aws_vpc.vpn_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "rds-security-group" }
}

resource "aws_db_subnet_group" "main" {
  name       = "rds-subnet-group"
  subnet_ids = aws_subnet.rds_private[*].id
  tags       = { Name = "rds-subnet-group" }
}

resource "aws_db_instance" "main" {
  identifier              = "main-database"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  storage_type            = "gp2"
  storage_encrypted       = false
  db_name                 = "testdb"
  username                = "admin"
  password                = "password123"
  vpc_security_group_ids  = [aws_security_group.rds.id]
  db_subnet_group_name    = aws_db_subnet_group.main.name
  backup_retention_period = 0
  skip_final_snapshot     = true
  tags                    = { Name = "main-database" }
}
