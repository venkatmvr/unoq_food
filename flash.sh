#!/usr/bin/env bash
# flash.sh — unoq_food build + deploy tool
#
# Commands:
#   ./flash.sh              — cross-compile + push + restart on Uno Q (default)
#   ./flash.sh build        — cross-compile only (no push)
#   ./flash.sh push         — push already-built binary + data (no compile)
#   ./flash.sh restart      — restart food-manager on Uno Q
#   ./flash.sh stop         — stop food-manager on Uno Q
#   ./flash.sh status       — show food-manager service status on Uno Q
#   ./flash.sh logs         — tail food-manager log on Uno Q
#   ./flash.sh health       — curl health check via Tailscale
#   ./flash.sh setup        — first-time: create remote dirs + install systemd unit
#   ./flash.sh help         — show this message
#
# Env vars:
#   UNOQ_IP    — Uno Q Tailscale IP (default: 100.110.53.104)
#   OLLAMA_URL — Ollama endpoint for recipe generation (default: http://100.114.105.110:11434)

set -euo pipefail
cd "$(dirname "$0")"
REPO_ROOT="$(pwd)"

UNOQ_IP="${UNOQ_IP:-100.110.53.104}"
OLLAMA_URL="${OLLAMA_URL:-http://100.114.105.110:11434}"
TARGET="aarch64-unknown-linux-gnu"
BINARY="target/${TARGET}/release/food-manager"
REMOTE_DIR="/home/arduino/unoq_food"
ADB="adb -s ${UNOQ_IP}:5555"

# ─────────────────────────────────────────────────────────────────────────────

usage() {
  grep '^#' "$0" | sed 's/^# \?//'
  exit 0
}

adb_connect() {
  adb connect "${UNOQ_IP}:5555" 2>&1 | grep -v "already connected" || true
}

build() {
  echo "==> Cross-compiling food-manager (${TARGET})..."
  cargo build --release --target "${TARGET}" -p food-manager
  echo "    $(ls -lh ${BINARY} | awk '{print $5, $9}')"
}

push() {
  adb_connect
  echo "==> Pushing binary..."
  ${ADB} push "${BINARY}" "${REMOTE_DIR}/food-manager"
  ${ADB} shell "chmod +x ${REMOTE_DIR}/food-manager"

  echo "==> Pushing data..."
  ${ADB} push data/food.db "${REMOTE_DIR}/data/food.db"

  echo "==> Pushing static files..."
  ${ADB} push server/src/static/index.html "${REMOTE_DIR}/server/src/static/index.html"
}

service_restart() {
  echo "==> Restarting food-manager (systemd)..."
  ${ADB} shell "sudo systemctl restart food-manager"
  sleep 2
  ${ADB} shell "sudo systemctl is-active food-manager && echo 'Running OK' || echo 'ERROR: check logs'"
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
    adb_connect
    service_restart
    ;;
  stop)
    adb_connect
    echo "==> Stopping food-manager..."
    ${ADB} shell "sudo systemctl stop food-manager"
    ;;
  status)
    adb_connect
    ${ADB} shell "sudo systemctl status food-manager --no-pager"
    ;;
  logs)
    adb_connect
    ${ADB} shell "sudo journalctl -u food-manager -f --no-pager"
    ;;
  health)
    curl -sf "http://${UNOQ_IP}:9091/health" && echo "OK"
    curl -s "http://${UNOQ_IP}:9091/api/menu/packed" | head -5
    ;;
  setup)
    adb_connect
    echo "==> Creating remote directories..."
    ${ADB} shell "mkdir -p ${REMOTE_DIR}/{data,server/src/static}"
    echo "==> Installing systemd unit..."
    ${ADB} push systemd/food-manager.service /tmp/food-manager.service
    ${ADB} shell "sudo mv /tmp/food-manager.service /etc/systemd/system/food-manager.service"
    ${ADB} shell "sudo systemctl daemon-reload"
    ${ADB} shell "sudo systemctl enable food-manager"
    echo "==> Setup done. Run './flash.sh' to build and deploy."
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo "Unknown command: ${cmd}"
    usage
    ;;
esac
