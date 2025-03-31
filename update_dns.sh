#!/bin/bash

# Configuration (Store these securely - ideally in environment variables)
API_KEY="hYCRSDXERyWAvptmf1VA"
API_SECRET="7FX6eseS3XFrIqBZD96Bxzfo1CkCYeMc3lhglCGZDvu2paME6xPhcbOdDXdC5cvc"
DOMAIN_NAME="qoran.top"  # Replace with your actual domain name

# Fetch current IP addresses
IP_ADDRESS=$(curl -s ifconfig.me)
IP_ADDRESS_6=$(curl -s -6 ifconfig.me)

# Validate IPs
[ -z "$IP_ADDRESS" ] && { echo "IPv4 fetch failed"; exit 1; }
[ -z "$IP_ADDRESS_6" ] && { echo "IPv6 fetch failed"; exit 1; }

# Fetch old IP addresses
ip4_old=$(curl --request GET --url "https://spaceship.dev/api/v1/dns/records/$DOMAIN_NAME?take=10&skip=0&orderBy=name" \
  --header "X-API-Key: $API_KEY" \
  --header "X-API-Secret: $API_SECRET" | jq -r '.items[] | select(.type=="A") | .address')

ipv6_old=$(curl --request GET --url "https://spaceship.dev/api/v1/dns/records/$DOMAIN_NAME?take=10&skip=0&orderBy=name" \
  --header "X-API-Key: $API_KEY" \
  --header "X-API-Secret: $API_SECRET" | jq -r '.items[] | select(.type=="AAAA") | .address')

# Check if old IPs are different from new IPs
if [[ "$ip4_old" != "$IP_ADDRESS" || "$ipv6_old" != "$IP_ADDRESS_6" ]]; then
  # Delete old DNS records
  curl --request DELETE --url "https://spaceship.dev/api/v1/dns/records/$DOMAIN_NAME" \
    --header "X-API-Key: $API_KEY" \
    --header "X-API-Secret: $API_SECRET" \
    --header "content-type: application/json" \
    --data '{"items": [{"type": "A", "name": "@"}, {"type": "AAAA", "name": "@"}, {"type": "A", "name": "www"}, {"type": "AAAA", "name": "www"}, {"type": "A", "name": "mail"}, {"type": "AAAA", "name": "mail"}, {"type": "A", "name": "immich"}, {"type": "AAAA", "name": "immich"}]}'

  # Build payload with new IP addresses
  PAYLOAD=$(jq -n \
    --arg ip4 "$IP_ADDRESS" \
    --arg ipv6 "$IP_ADDRESS_6" \
    '{
      "force": true,
      "items": [
        { "type": "A", "name": "@", "ttl": 1800, "Address": $ip4 },
        { "type": "AAAA", "name": "@", "ttl": 1800, "Address": $ipv6 },
        { "type": "A", "name": "www", "ttl": 1800, "Address": $ip4 },
        { "type": "AAAA", "name": "www", "ttl": 1800, "Address": $ipv6 },
        { "type": "A", "name": "mail", "ttl": 1800, "Address": $ip4 },
        { "type": "AAAA", "name": "mail", "ttl": 1800, "Address": $ipv6 },
        { "type": "A", "name": "immich", "ttl": 1800, "Address": $ip4 },
        { "type": "AAAA", "name": "immich", "ttl": 1800, "Address": $ipv6 }
      ]
    }'
  )

  # Send request to update DNS records
  response=$(curl -s -o /dev/null -w "%{http_code}" \
    --request PUT \
    --url "https://spaceship.dev/api/v1/dns/records/$DOMAIN_NAME" \
    --header "X-API-Key: $API_KEY" \
    --header "X-API-Secret: $API_SECRET" \
    --header "content-type: application/json" \
    --data "$PAYLOAD")

  # Check response
  if [ "$response" -eq 200 ]; then
    echo "DNS records fully replaced."
  else
    echo "Failed. HTTP Code: $response"
    exit 1
  fi
else
  echo "IP addresses are up to date. No changes needed."
fi
