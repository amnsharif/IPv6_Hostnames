# Retrieve the IPINFO_TOKEN from www.conf and remove double quotes
IPINFO_TOKEN=$(grep 'env\[IPINFO_TOKEN\]' /etc/php/8.3/fpm/pool.d/www.conf | awk -F '=' '{print $2}' | tr -d '"')

# Debug: Print the cleaned token
#echo "Token: '$IPINFO_TOKEN'"

# Process the logs and fetch IP locations
#grep -h 'qoran.top*' /var/log/nginx/access.log* | awk '$1 !~ /^127.0.0.1$/ && $1 !~ /^192\.168\.2\./ {print $1, $4, $5}' | sort | awk '
grep -h 'ddnsfree.com*' /var/log/nginx/access.log* | awk '$1 !~ /^127.0.0.1$/ && $1 !~ /^192\.168\.2\./ {print $1, $4, $5}' | sort | awk '
{
    ip = $1;
    timestamp = $2 " " $3;
    count[ip]++;
    last_access[ip] = timestamp;
}
END {
    for (ip in count) {
        printf "%d %s %s\n", count[ip], ip, last_access[ip];
    }
}' | sort -nr | while read -r count ip timestamp; do
    # Debug: Print the IP being processed
    #echo "Processing IP: $ip"

    # Fetch org
    org=$(curl -s "https://ipinfo.io/$ip/org?token="$IPINFO_TOKEN)

    # Fetch city
    city=$(curl -s "https://ipinfo.io/$ip/city?token="$IPINFO_TOKEN)

    # Fetch country
    country=$(curl -s "https://ipinfo.io/$ip/country?token="$IPINFO_TOKEN)

    # Debug: Print the raw API responses
    #echo "Org: $org"
    #echo "City: $city"
    #echo "Country: $country"

    # Fallback for empty locations
    if [ -z "$org" ]; then
	org="Unknown"
    fi
    if [ -z "$city" ]; then
        city="Unknown"
    fi
    if [ -z "$country" ]; then
        country="Unknown"
    fi

    # Print the final output
    printf "%d %s %s %s %s %s\n" "$count" "$ip" "$timestamp" "$org" "$city" "$country"

    # Add a delay to avoid hitting API rate limits
    sleep 1
done
