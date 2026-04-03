#!/usr/bin/env bash
# setup-ap.sh — one-time AP setup on Arduino Uno Q
# Run this ON the Uno Q (copy via adb push or ssh)
# Sets up concurrent STA+AP: wlan0 stays on home WiFi, wlan0_ap broadcasts "picomate" on 2.4GHz
set -euo pipefail

AP_IP="192.168.4.1"
AP_NETMASK="255.255.255.0"

echo "==> Installing hostapd + dnsmasq..."
sudo apt-get install -y hostapd dnsmasq

echo "==> Configuring NetworkManager to ignore wlan0_ap..."
sudo tee /etc/NetworkManager/conf.d/ignore-ap.conf > /dev/null <<'EOF'
[keyfile]
unmanaged-devices=interface-name:wlan0_ap
EOF

echo "==> Creating virtual AP interface (wlan0_ap)..."
sudo iw dev wlan0 interface add wlan0_ap type __ap || echo "  (interface may already exist)"

echo "==> Assigning static IP to wlan0_ap..."
sudo ip addr add "${AP_IP}/${AP_NETMASK}" dev wlan0_ap 2>/dev/null || true
sudo ip link set wlan0_ap up

echo "==> Installing hostapd config..."
sudo cp /home/arduino/unoq_food/network/hostapd.conf /etc/hostapd/hostapd.conf
sudo sed -i 's/CONFIGURED=0/CONFIGURED=1/' /etc/default/hostapd 2>/dev/null || true
echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' | sudo tee -a /etc/default/hostapd

echo "==> Installing dnsmasq config (AP only)..."
sudo cp /home/arduino/unoq_food/network/dnsmasq-ap.conf /etc/dnsmasq.d/ap.conf

echo "==> Creating wlan0_ap startup service..."
sudo tee /etc/systemd/system/wlan0-ap.service > /dev/null <<EOF
[Unit]
Description=Create wlan0_ap virtual interface
Before=hostapd.service
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/iw dev wlan0 interface add wlan0_ap type __ap
ExecStartPost=/sbin/ip addr add ${AP_IP}/24 dev wlan0_ap
ExecStartPost=/sbin/ip link set wlan0_ap up

[Install]
WantedBy=multi-user.target
EOF

echo "==> Enabling services..."
sudo systemctl daemon-reload
sudo systemctl enable wlan0-ap hostapd dnsmasq
sudo systemctl restart wlan0-ap hostapd dnsmasq

echo ""
echo "==> AP setup complete."
echo "    SSID: picomate (2.4GHz, channel 6)"
echo "    AP IP: ${AP_IP}"
echo "    DHCP:  192.168.4.10 – 192.168.4.50"
echo ""
echo "    IMPORTANT: Edit /etc/hostapd/hostapd.conf and set wpa_passphrase before broadcasting."
echo "    Then: sudo systemctl restart hostapd"
