#!/bin/bash
while true; do
    essid=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)
    if [ -n "$essid" ]; then
        echo "🌐 $essid"
    else
        echo "⚠️ Disconnected"
    fi
    sleep 2
done
