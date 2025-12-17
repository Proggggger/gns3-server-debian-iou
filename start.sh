#!/bin/sh
# Use 'dash' explicitly if /bin/sh points to it, ensures strict POSIX compliance.

# --- 1. CONFIG FILE SETUP ---
# Fix syntax error: Use standard 'test' format or modern [[ ]] format. 
# We'll stick to robust POSIX sh format for compatibility.

CONFIG_PATH=${CONFIG:-/data/config.ini}

if [ ! -e "$CONFIG_PATH" ]; then
    echo "Config file not found at $CONFIG_PATH, copying default..."
    cp /config.ini "$CONFIG_PATH"
fi
# Use the determined path for the rest of the script
CONFIG=$CONFIG_PATH


# --- 2. NETWORK SETUP & CLEANUP ---
# Ensure the bridge is clean if it already exists from a previous run
echo "Setting up network bridge virbr0..."

# Stop existing dnsmasq instance if running on virbr0
killall dnsmasq || true

# Check if virbr0 exists and clean it up
if ip link show virbr0 &> /dev/null; then
    echo "virbr0 already exists. Tearing it down first."
    ip link set dev virbr0 down
    brctl delbr virbr0
fi

brctl addbr virbr0
ip link set dev virbr0 up


# --- 3. IP ADDRESS CONFIGURATION ---
# Fix syntax error: Use robust POSIX parameter expansion for default value
# and use a variable that is guaranteed not to be empty if you need the 'x' check.

# Set a default address if BRIDGE_ADDRESS is not set
BRIDGE_ADDR=${BRIDGE_ADDRESS:-172.27.1.1/24}
echo "Using bridge address: $BRIDGE_ADDR"

# Ensure the address is added cleanly
ip ad flush dev virbr0
ip ad add "${BRIDGE_ADDR}" dev virbr0

# Set up NAT (requires --privileged container mode)
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE


# --- 4. START SERVICES ---
echo "Starting dnsmasq and dockerd..."
dnsmasq -i virbr0 -z -h --dhcp-range=192.168.122.10,192.168.122.250,4h
dockerd --storage-driver=vfs --data-root=/data/docker/ &

echo "Starting gns3server..."
gns3server -A --config $CONFIG
