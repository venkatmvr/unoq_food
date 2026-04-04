#!/usr/bin/env bash
# flash.sh — unoq_food build + deploy tool
#
# First-time setup on a fresh Uno Q (while it still has home WiFi):
#   UNOQ_IP=<tailscale-or-lan-ip> ./flash.sh setup       — install all services + AP config
#   UNOQ_IP=<tailscale-or-lan-ip> ./flash.sh             — build + deploy food-manager binary
#   UNOQ_IP=<tailscale-or-lan-ip> ./flash.sh ap-cutover  — switch wlan0 to AP (SSH dies)
#   After cutover: join Mac to picomate WiFi, then use ./flash.sh normally.
#
# !! AFTER AP CUTOVER: REQUIRES MAC TO BE ON picomate WiFi !!
#   The Uno Q runs wlan0 as a 2.4GHz AP ("picomate") with NO home WiFi / Tailscale.
#   ALL commands that touch the Uno Q connect via the AP IP 192.168.4.1.
#   If the Mac is not joined to picomate, every ssh/scp/curl command will fail.
#
#   Join picomate: SSID=picomate, password=srilakshmi
#   Uno Q AP IP:  192.168.4.1
#
#   Note: Ollama recipe generation is unavailable (no internet on Uno Q).
#   Recipes already cached in food.db continue to work.
#
# Commands:
#   ./flash.sh deploy       — cross-compile + push + restart on Uno Q (default)
#   ./flash.sh build        — cross-compile only (no push)
#   ./flash.sh push         — push already-built binary + data (no compile)
#   ./flash.sh restart      — restart food-manager on Uno Q
#   ./flash.sh stop         — stop food-manager on Uno Q
#   ./flash.sh status       — show food-manager service status on Uno Q
#   ./flash.sh logs         — tail food-manager log on Uno Q
#   ./flash.sh health       — curl health check
#   ./flash.sh setup        — first-time: install all services, AP configs, sudoers
#   ./flash.sh ap-cutover   — switch wlan0 from home WiFi to picomate AP (SSH dies after)
#   ./flash.sh help         — show this message
#
# Env vars:
#   UNOQ_IP    — Uno Q IP (default: 192.168.4.1 — AP address on picomate network)
#   UNOQ_PASS  — SSH password (default: Ramana@1964)

set -euo pipefail
cd "$(dirname "$0")"
REPO_ROOT="$(pwd)"

UNOQ_IP="${UNOQ_IP:-192.168.4.1}"
UNOQ_USER="${UNOQ_USER:-arduino}"
UNOQ_PASS="${UNOQ_PASS:-Ramana@1964}"
TARGET="aarch64-unknown-linux-gnu"
BINARY="target/${TARGET}/release/food-manager"
REMOTE_DIR="/home/arduino/unoq_food"

SCP="sshpass -p ${UNOQ_PASS} scp -o StrictHostKeyChecking=no"

# run a command on Uno Q
rssh() { sshpass -p "${UNOQ_PASS}" ssh -o StrictHostKeyChecking=no -o LogLevel=QUIET "${UNOQ_USER}@${UNOQ_IP}" "$@"; }
# run a sudo command on Uno Q (feeds password to sudo -S)
rsudo() { rssh "sudo $*"; }

# ─────────────────────────────────────────────────────────────────────────────

usage() {
  grep '^#' "$0" | sed 's/^# \?//'
  exit 0
}

check_network() {
  if ! ping -c1 -W1 "${UNOQ_IP}" &>/dev/null; then
    echo "ERROR: Uno Q (${UNOQ_IP}) is unreachable."
    echo "  Join the 'picomate' WiFi network on this Mac first (password: srilakshmi)."
    exit 1
  fi
}

build() {
  echo "==> Cross-compiling food-manager (${TARGET})..."
  cargo build --release --target "${TARGET}" -p food-manager
  echo "    $(ls -lh ${BINARY} | awk '{print $5, $9}')"
}

push() {
  check_network
  echo "==> Pushing binary..."
  ${SCP} "${BINARY}" "${UNOQ_USER}@${UNOQ_IP}:${REMOTE_DIR}/food-manager"
  rssh "chmod +x ${REMOTE_DIR}/food-manager"

  echo "==> Pushing data..."
  ${SCP} data/food.db "${UNOQ_USER}@${UNOQ_IP}:${REMOTE_DIR}/data/food.db"

  echo "==> Pushing static files..."
  ${SCP} server/src/static/index.html "${UNOQ_USER}@${UNOQ_IP}:${REMOTE_DIR}/server/src/static/index.html"
}

service_restart() {
  echo "==> Restarting food-manager (systemd)..."
  rsudo systemctl restart food-manager
  sleep 2
  rsudo "systemctl is-active food-manager && echo 'Running OK' || echo 'ERROR: check logs'"
}

# ─── Commands ────────────────────────────────────────────────────────────────

cmd="${1:-deploy}"
shift || true

case "${cmd}" in
  deploy)
    build
    push
    service_restart
    echo "==> Health check..."
    sleep 1
    curl -sf "http://${UNOQ_IP}:9091/health" && echo "OK" || echo "FAILED"
    ;;
  build)
    build
    ;;
  push)
    push
    service_restart
    ;;
  restart)
    check_network
    service_restart
    ;;
  stop)
    check_network
    echo "==> Stopping food-manager..."
    rsudo systemctl stop food-manager
    ;;
  status)
    check_network
    rsudo systemctl status food-manager --no-pager
    ;;
  logs)
    check_network
    rsudo journalctl -u food-manager -f --no-pager
    ;;
  health)
    curl -sf "http://${UNOQ_IP}:9091/health" && echo "OK"
    curl -s "http://${UNOQ_IP}:9091/api/menu/packed" | head -5
    ;;
  setup)
    check_network
    echo "==> [1/6] Creating remote directories..."
    rssh "mkdir -p ${REMOTE_DIR}/{data,server/src/static}"

    echo "==> [2/6] Configuring passwordless sudo for arduino..."
    rssh "echo '${UNOQ_PASS}' | sudo -S -p '' bash -c \
      'echo \"arduino ALL=(ALL) NOPASSWD: ALL\" > /etc/sudoers.d/arduino-nopasswd && \
       chmod 440 /etc/sudoers.d/arduino-nopasswd'"

    echo "==> [3/6] Installing hostapd + dnsmasq..."
    rsudo apt-get install -y hostapd dnsmasq
    rsudo systemctl unmask hostapd

    echo "==> [4/6] Installing AP configs..."
    ${SCP} network/hostapd.conf  "${UNOQ_USER}@${UNOQ_IP}:/tmp/hostapd.conf"
    ${SCP} network/dnsmasq-ap.conf "${UNOQ_USER}@${UNOQ_IP}:/tmp/dnsmasq-ap.conf"
    rsudo "mv /tmp/hostapd.conf /etc/hostapd/hostapd.conf"
    rsudo "mv /tmp/dnsmasq-ap.conf /etc/dnsmasq.d/ap.conf"

    echo "==> [5/6] Installing systemd units..."
    ${SCP} systemd/food-manager.service "${UNOQ_USER}@${UNOQ_IP}:/tmp/food-manager.service"
    rsudo "mv /tmp/food-manager.service /etc/systemd/system/food-manager.service"
    rsudo bash -c "'tee /etc/systemd/system/ap-cutover.service > /dev/null << EOF
[Unit]
Description=Cut wlan0 from STA to AP mode (picomate)
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c \
  \"nmcli device set wlan0 managed no; \
  nmcli device disconnect wlan0 2>/dev/null; \
  sleep 2; \
  systemctl stop wlan0-ap hostapd 2>/dev/null; \
  iw dev wlan0_ap del 2>/dev/null; \
  sleep 1; \
  systemctl start hostapd; \
  sleep 2; \
  ip addr add 192.168.4.1/24 dev wlan0 2>/dev/null; \
  ip link set wlan0 up; \
  systemctl restart dnsmasq; \
  systemctl restart food-manager\"
EOF'"
    rsudo systemctl daemon-reload
    rsudo systemctl enable food-manager hostapd dnsmasq

    echo "==> [6/6] Done."
    echo ""
    echo "  Next steps:"
    echo "  1. UNOQ_IP=${UNOQ_IP} ./flash.sh       — build + deploy food-manager binary"
    echo "  2. UNOQ_IP=${UNOQ_IP} ./flash.sh ap-cutover — switch to AP (SSH will die)"
    echo "  3. Join Mac to 'picomate' WiFi, then use ./flash.sh normally"
    ;;
  ap-cutover)
    check_network
    echo "==> Triggering AP cutover on Uno Q..."
    echo "    wlan0 will switch from home WiFi to picomate AP."
    echo "    SSH will disconnect. Wait ~10s then join Mac to 'picomate' (pw: srilakshmi)."
    rssh "sudo systemctl start ap-cutover &"
    echo "==> Cutover triggered. Waiting 12s..."
    sleep 12
    if curl -sf --max-time 3 "http://192.168.4.1:9091/health" &>/dev/null; then
      echo "==> picomate AP is up. Health check OK."
      echo "    Join Mac to 'picomate' WiFi to use ./flash.sh deploy."
    else
      echo "==> 192.168.4.1 not reachable from Mac yet."
      echo "    Join Mac to 'picomate' WiFi first, then run: ./flash.sh health"
    fi
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo "Unknown command: ${cmd}"
    usage
    ;;
esac
