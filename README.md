
# Unbound Dynamic Hostname Script
## Description
This script dynamically updates Unbound DNS server configurations with hostname-to-IP mappings for both IPv4 and IPv6 addresses. It is particularly useful for environments with devices obtaining IPs via DHCP, ensuring hostnames resolve locally without manual updates.
## Features
- Automatically extracts and assigns hostnames to IPv4 and IPv6 addresses.
- Skips link-local IPv6 addresses (`fe80::/10`) to avoid unnecessary entries.
- Integrates with OPNsense Unbound's template system for persistent configurations.
- Validates and applies configurations using OPNsense's tools.
## Requirements
- OPNsense firewall with Unbound DNS configured.
- Root access to the system.
- Bash shell.

## Installation
1. Clone the repository:
```
git clone https://github.com/amnsharif/IPv6_Hostnames.git
cd unbound-dynamic-hostname
```
2. Copy the script to /usr/local/bin and make it executable:
```
sudo cp update_unbound_entries.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/update_unbound_entries.sh
```
3. Run the script to generate the configuration:
```
sudo bash update_unbound_entries.sh
```
#### **Usage**
To run the script manually:
```
sudo /usr/local/bin/update_unbound_entries.sh
```
To automate the process, add a cron job:
```
sudo crontab -e
```
Add the following line:
```
0 * * * * /usr/local/bin/update_unbound_entries.sh
```
This will run the script hourly.

#### **How It Works**
1. Extracts IPv4 and IPv6-to-MAC mappings using arp and ndp commands.

2. Resolves hostnames for each IP address.

3. Filters out link-local (fe80::/10) IPv6 addresses.

4. Writes the hostname-IP mappings into the Unbound template file.

5. Reloads and validates the Unbound configuration.

#### **Examples**

Adding a new device: Simply ensure the device is connected to the network and has a valid hostname. Run the script to add it to Unbound DNS.

Skipping specific addresses: The script automatically skips link-local IPv6 addresses.

#### **Troubleshooting**

1. Error: Permission Denied Ensure the script is executable and run as root.
```
sudo chmod +x /usr/local/bin/update_unbound_entries.sh
```
2. Invalid Configuration Check the Unbound configuration:
```
configctl unbound check
```
3. No Hostname Found: Verify that the device has a hostname assigned via DHCP.

#### **Contributing**
If you find this helpful and would like to contribute, please consider visiting my [Patreon page](
https://patreon.com/amnsharif?utm_medium=unknown&utm_source=join_link&utm_campaign=creatorshare_creator&utm_content=copyLink)
