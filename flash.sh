#!/usr/bin/env bash
# flash.sh — unoq_food build + deploy tool
#
# !! REQUIRES TAILSCALE !!
#   ALL commands that touch the Uno Q (deploy, push, restart, stop, status,
#   logs, health, setup) connect via Tailscale IPs. If Tailscale is off on
#   either this Mac or the Uno Q, every ssh/scp/curl command will hang or fail.
#
#   Mac:   tailscale status          — must show 100.114.105.110 (this Mac)
#   Uno Q: tailscale status on board — must show 100.110.53.104
#   Start: open Tailscale menu bar app, or: sudo tailscale up
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
#   UNOQ_PASS  — SSH password (default: Ramana@1964)
#   OLLAMA_URL — Ollama endpoint for recipe generation (default: http://100.114.105.110:11434)
#              — Ollama also reached via Tailscale; recipes fail silently if Mac Tailscale is off

set -euo pipefail
cd "$(dirname "$0")"
REPO_ROOT="$(pwd)"

UNOQ_IP="${UNOQ_IP:-100.110.53.104}"
UNOQ_USER="${UNOQ_USER:-arduino}"
UNOQ_PASS="${UNOQ_PASS:-Ramana@1964}"
OLLAMA_URL="${OLLAMA_URL:-http://100.114.105.110:11434}"
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

check_tailscale() {
  if ! /Applications/Tailscale.app/Contents/MacOS/Tailscale status --peers=false &>/dev/null; then
    echo "ERROR: Tailscale is not running on this Mac."
    echo "  Start it: open the Tailscale menu bar app, or run: sudo tailscale up"
    exit 1
  fi
  if ! ping -c1 -W1 "${UNOQ_IP}" &>/dev/null; then
    echo "ERROR: Uno Q (${UNOQ_IP}) is unreachable via Tailscale."
    echo "  Check: tailscale status | grep ${UNOQ_IP}"
    echo "  The Uno Q must also have Tailscale running and connected."
    exit 1
  fi
}

build() {
  echo "==> Cross-compiling food-manager (${TARGET})..."
  cargo build --release --target "${TARGET}" -p food-manager
  echo "    $(ls -lh ${BINARY} | awk '{print $5, $9}')"
}

push() {
  check_tailscale
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
    check_tailscale
    service_restart
    ;;
  stop)
    check_tailscale
    echo "==> Stopping food-manager..."
    rsudo systemctl stop food-manager
    ;;
  status)
    check_tailscale
    rsudo systemctl status food-manager --no-pager
    ;;
  logs)
    check_tailscale
    rsudo journalctl -u food-manager -f --no-pager
    ;;
  health)
    curl -sf "http://${UNOQ_IP}:9091/health" && echo "OK"
    curl -s "http://${UNOQ_IP}:9091/api/menu/packed" | head -5
    ;;
  setup)
    check_tailscale
    echo "==> Creating remote directories..."
    rssh "mkdir -p ${REMOTE_DIR}/{data,server/src/static}"
    echo "==> Installing systemd unit..."
    ${SCP} systemd/food-manager.service "${UNOQ_USER}@${UNOQ_IP}:/tmp/food-manager.service"
    rsudo "mv /tmp/food-manager.service /etc/systemd/system/food-manager.service"
    rsudo systemctl daemon-reload
    rsudo systemctl enable food-manager
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
