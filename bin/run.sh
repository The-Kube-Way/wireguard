#!/bin/sh

set -eux

# Setup interfaces
INTERFACES=$(find /etc/wireguard -type f -name "*.conf")
if [ -z "$INTERFACES" ]; then
    echo "No interface in /etc/wireguard" >&2
    exit 1
fi

for interface in $INTERFACES
do
    echo "Starting Wireguard $interface..."
    wg-quick up "$interface"
done

# Masquerade trafic from VPN
ETH0_IP=$(ip address show dev eth0 | grep inet | awk '{print $2}' | cut -d/ -f 1)
iptables -t nat -A POSTROUTING -o eth0 -j SNAT --to-source "$ETH0_IP"

# Show stats
while true
do
    wg show
    sleep 60
done
