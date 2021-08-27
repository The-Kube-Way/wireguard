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
    wg-quick down "$interface" || true
    echo "Starting Wireguard $interface..."
    wg-quick up "$interface"
done


# Masquerade trafic from VPN
ETH0_IP=$(ip address show dev eth0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f 1)
if ! iptables -t nat -C POSTROUTING -o eth0 -j SNAT --to-source "$ETH0_IP" 2> /dev/null; then
    iptables -t nat -A POSTROUTING -o eth0 -j SNAT --to-source "$ETH0_IP"
fi


# Setup port forwarding
if [ -e "/etc/wireguard-port-forwarding/rules.conf" ]; then
    echo "Configuring port forwarding..." 

    cat "/etc/wireguard-port-forwarding/rules.conf" | while read line
        do

        # Line format is: VPN_INTERFACE CLIENT_IP PROTOCOL SRC_PORT [DEST_PORT]
        VPN_INTERFACE=$(echo "$line" | awk '{print $1}')
        CLIENT_IP=$(echo "$line" | awk '{print $2}')
        PROTOCOL=$(echo "$line" | awk '{print $3}')
        SRC_PORT=$(echo "$line" | awk '{print $4}')
        DEST_PORT=$(echo "$line" | awk '{print $5}')
        if [ -z "$DEST_PORT" ]; then
            DEST_PORT=$SRC_PORT
        fi

        # Setup masquerade source IP for packets coming from outside (if needed)
        VPN_INTERFACE_IP=$(ip address show dev "$VPN_INTERFACE" | grep 'inet ' | awk '{print $2}' | cut -d/ -f 1)
        if ! iptables -t nat -C POSTROUTING -o "$VPN_INTERFACE" -j SNAT --to-source "$VPN_INTERFACE_IP" 2> /dev/null; then
            iptables -t nat -A POSTROUTING -o "$VPN_INTERFACE" -j SNAT --to-source "$VPN_INTERFACE_IP"
        fi

        # Setup port forwarding
        if ! iptables \
            -t nat -C PREROUTING \
            -d "$ETH0_IP" \
            -p "$PROTOCOL" --dport "$SRC_PORT" \
            -j DNAT --to-destination "$CLIENT_IP:$DEST_PORT" 2> /dev/null;
        then
            iptables \
                -t nat -A PREROUTING \
                -d "$ETH0_IP" \
                -p "$PROTOCOL" --dport "$SRC_PORT" \
                -j DNAT --to-destination "$CLIENT_IP:$DEST_PORT"
        fi
        
        echo "Port forward added on $VPN_INTERFACE: $PROTOCOL/$SRC_PORT -> $CLIENT_IP:$DEST_PORT"
    done
fi


# Handle stop
trap 'exit 0' 15


# Show stats
while true
do
    wg show
    sleep 60 &
    wait $!
done
