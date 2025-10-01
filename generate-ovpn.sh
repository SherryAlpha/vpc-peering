#!/bin/bash
set -euo pipefail

OVPN_FILE="client.ovpn"

cat > $OVPN_FILE <<EOF
client
dev tun
proto udp
remote $(tofu output -raw client_vpn_dns_name | sed 's/"//g') 443
remote-random-hostname
resolv-retry infinite
nobind
remote-cert-tls server
cipher AES-256-GCM
verb 3

<ca>
$(tofu output -raw ca_certificate)
</ca>

<cert>
$(tofu output -raw client_certificate)
</cert>

<key>
$(tofu output -raw client_private_key)
</key>

reneg-sec 0
verify-x509-name server.rds-vpn.local name
EOF

echo "✅ Generated $OVPN_FILE"
