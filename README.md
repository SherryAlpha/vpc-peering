# VPC Peering + RDS VPN OpenTofu Setup

This project provisions a secure AWS architecture using OpenTofu:

- 🛡️ VPC 1: Hosts the RDS (MySQL) database  
- 🌐 VPC 2: Hosts the AWS Client VPN endpoint  
- 🔗 VPC Peering: Enables private communication between the two VPCs  
- 📜 Client VPN: Generates  config for secure DB access  
- 📊 Outputs: Connection details like RDS endpoint, VPN DNS, and CIDRs

## 🚀 How to Use

1. Initialize Terraform:
   tofu init

2. Plan and apply changes:
   tofu plan -out=tfplan
   tofu apply tfplan

3. Generate the VPN client configuration:
   ./generate-ovpn.sh

4. Connect to the VPN and access your RDS:
   mysql -h <rds-endpoint> -u admin -p

## 📁 Project Structure

- main.tf – Core OpenTofu infrastructure  
- outputs.tf – Connection details  
- generate-ovpn.sh – Script to build the .ovpn file  
- client.ovpn – VPN client configuration (auto-generated)


