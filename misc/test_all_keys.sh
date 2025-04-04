#!/bin/bash

# Test all SSH keys against an IP address
# Usage: ./test_all_keys.sh <ip_address> <username> [port]

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <ip_address> <username> [port]"
    echo "Example: $0 192.168.1.100 root"
    echo "Example with custom port: $0 192.168.1.100 root 2222"
    exit 1
fi

IP_ADDRESS="$1"
USERNAME="$2"
PORT="${3:-22}"  # Default port is 22 if not specified

# Find all private keys (excluding .pub files and known_hosts)
KEY_FILES=$(find . -type f -not -name "*.pub" -not -name "known_hosts*" -not -name "config" -not -name "*.sh" -not -name ".DS_Store")

echo "Testing all SSH keys against $USERNAME@$IP_ADDRESS:$PORT"
echo "==============================================="

# Function to test a single key
test_key() {
    key="$1"
    key_name=$(basename "$key")
    
    echo -n "Testing key: $key_name... "
    
    # Test the SSH connection with a 5-second timeout
    if ssh -i "$key" -o PasswordAuthentication=no -o StrictHostKeyChecking=no -o ConnectTimeout=5 -p "$PORT" "$USERNAME@$IP_ADDRESS" 'echo "Connection successful"; exit' &>/dev/null; then
        echo "SUCCESS ✅"
        return 0
    else
        echo "FAILED ❌"
        return 1
    fi
}

# Counter for successful keys
successful_keys=0

# Test each key
for key in $KEY_FILES; do
    # Skip directories and non-key files
    if [ -f "$key" ]; then
        if test_key "$key"; then
            successful_keys=$((successful_keys+1))
            # Store successful key name
            successful_key_name=$(basename "$key")
        fi
    fi
done

echo "==============================================="
echo "Results: $successful_keys successful connections out of $(echo "$KEY_FILES" | wc -w | tr -d ' ') keys"

if [ "$successful_keys" -gt 0 ]; then
    echo "Last successful key: $successful_key_name"
    echo ""
    echo "To connect using this key, run:"
    echo "ssh -i \"$successful_key_name\" -p $PORT $USERNAME@$IP_ADDRESS"
fi
