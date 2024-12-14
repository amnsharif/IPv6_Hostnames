#!/bin/bash

# Ensure the script is run with root privileges
if [ $EUID -ne 0 ]; then
   echo "This script must be run as root."
   exit 1
fi

# Define paths
TEMPLATE_DIR="/usr/local/opnsense/service/templates/custom/Unbound"
TARGETS_FILE="$TEMPLATE_DIR/+TARGETS"
TEMPLATE_FILE="$TEMPLATE_DIR/custom_entries.conf"
TEMP_TEMPLATE_FILE="/tmp/temp_custom_entries.conf"

# Ensure the template directory exists
mkdir -p "$TEMPLATE_DIR"

# Create or truncate the temporary template file
cat << EOF > "$TEMP_TEMPLATE_FILE"
server:
  local-zone: "home" transparent
  local-data-ptr: "127.0.0.1 localhost"
  local-data: "localhost A 127.0.0.1"
  local-data-ptr: "::1 localhost"
  local-data: "localhost AAAA ::1"
EOF

# Step 1: Extract IPv4 -> MAC mappings
echo "Gathering IPv4 to MAC mappings..."
ARP_FILE="/tmp/arp_table.txt"
arp -an | awk '/at/ {print $2, $4}' | tr -d '()' > "$ARP_FILE"

# Step 2: Extract IPv6 -> MAC mappings
echo "Gathering IPv6 to MAC mappings..."
NDP_FILE="/tmp/ndp_table.txt"
ndp -an | awk '/([0-9a-f]{2}:){5}[0-9a-f]{2}/ {print $1, $2}' > "$NDP_FILE"

# Step 3: Match MAC addresses and assign hostnames to IPv6 addresses
echo "Matching MAC addresses and updating Unbound template file..."

while IFS= read -r line; do
    ipv4=$(echo "$line" | awk '{print $1}')
    mac=$(echo "$line" | awk '{print $2}')

    # Retrieve hostname using the IPv4 address
    hostname=$(host "$ipv4" 2>/dev/null | awk '/pointer/ {print $NF}' | sed 's/\.$//')

    # Skip if hostname is empty
    if [ -n "$hostname" ]; then
        # Find matching IPv6 for the MAC address
        ipv6_list=$(grep -i "$mac" "$NDP_FILE" | awk '{print $1}' | sed 's/%.*//')
        
        if [ -n "$ipv6_list" ]; then
            for ipv6 in $ipv6_list; do
                echo "Assigning hostname $hostname to IPv6 address $ipv6"

                # Add entries for Unbound leases, avoiding duplicates
                grep -q "$ipv6" "$TEMP_TEMPLATE_FILE" || {
                    echo "  local-data-ptr: \"$ipv6 $hostname\"" >> "$TEMP_TEMPLATE_FILE"
                    echo "  local-data: \"$hostname AAAA $ipv6\"" >> "$TEMP_TEMPLATE_FILE"
                }
            done
        fi
    else
        echo "Warning: Unable to resolve hostname for IPv4 $ipv4"
    fi

done < "$ARP_FILE"

# Step 4: Move the template file to the correct directory
mv "$TEMP_TEMPLATE_FILE" "$TEMPLATE_FILE"

# Step 5: Create the +TARGETS file to link the template to the configuration directory
cat << EOF > "$TARGETS_FILE"
custom_entries.conf:/usr/local/etc/unbound.opnsense.d/custom_entries.conf
EOF

# Step 6: Generate the Unbound configuration
echo "Generating Unbound configuration from the template..."
configctl template reload custom/Unbound || {
    echo "Template generation failed. Exiting."
    exit 1
}

# Step 7: Validate the Unbound configuration
echo "Validating Unbound configuration..."
configctl unbound check || {
    echo "Unbound configuration validation failed. Exiting."
    exit 1
}

# Step 8: Restart Unbound to apply changes
echo "Restarting Unbound service..."
configctl unbound restart

# Clean up temporary files
rm -f "$ARP_FILE" "$NDP_FILE"

echo "Script execution complete."
