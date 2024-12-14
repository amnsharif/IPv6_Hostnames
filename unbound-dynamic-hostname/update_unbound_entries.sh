#!/bin/bash
# Ensure the script is run with root privileges
if [ $EUID -ne 0 ]; then
   echo "This script must be run as root."
   exit 1
fi
# Temporary files
ARP_FILE="/tmp/arp_table.txt"
NDP_FILE="/tmp/ndp_table.txt"
LEASES_FILE="/var/unbound/host_entries.conf"
TEMP_LEASES_FILE="/tmp/temp_host_entries.conf"
# Backup existing leases file
if [ -f "$LEASES_FILE" ]; then
    cp "$LEASES_FILE" "${LEASES_FILE}.bak"
    cp "$LEASES_FILE" "$TEMP_LEASES_FILE"
else
    cat << EOF > "$TEMP_LEASES_FILE"
local-zone: "home" transparent
local-data-ptr: "127.0.0.1 localhost"
local-data: "localhost A 127.0.0.1"
local-data-ptr: "::1 localhost"
local-data: "localhost AAAA ::1"
EOF
fi
# Step 1: Extract IPv4 -> MAC mappings
echo "Gathering IPv4 to MAC mappings..."
arp -an | awk '/at/ {print $2, $4}' | tr -d '()' > "$ARP_FILE"
echo "IPv4 -> MAC mappings:"
cat "$ARP_FILE"
# Step 2: Extract IPv6 -> MAC mappings
echo "Gathering IPv6 to MAC mappings..."
ndp -an | awk '/([0-9a-f]{2}:){5}[0-9a-f]{2}/ {print $1, $2}' > "$NDP_FILE"
echo "IPv6 -> MAC mappings:"
cat "$NDP_FILE"
# Step 3: Match MAC addresses and assign hostnames to IPv6 addresses
echo "Matching MAC addresses and updating Unbound leases file..."
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
                # Skip link-local addresses
                if [[ "$ipv6" == fe80::* ]]; then
                    echo "Skipping link-local IPv6 address: $ipv6"
                    continue
                fi
                echo "Assigning hostname $hostname to IPv6 address $ipv6"
                # Add entries for Unbound leases, avoiding duplicates
                grep -q "$ipv6" "$TEMP_LEASES_FILE" || {
                    echo "local-data-ptr: \"$ipv6 $hostname\"" >> "$TEMP_LEASES_FILE"
                    echo "local-data: \"$hostname AAAA $ipv6\"" >> "$TEMP_LEASES_FILE"
                }
            done
        fi
    else
        echo "Warning: Unable to resolve hostname for IPv4 $ipv4"
    fi
done < "$ARP_FILE"
# Step 4: Replace the original leases file
mv "$TEMP_LEASES_FILE" "$LEASES_FILE"
# Step 5: Restart Unbound to apply changes
echo "Restarting Unbound service..."
configctl unbound onerestart
# Clean up temporary files
rm -f "$ARP_FILE" "$NDP_FILE"
echo "Script execution complete."
