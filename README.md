# unoq_food — PicoMate Food Server on Arduino Uno Q

Ports the PicoMate food-manager server from Mac to the Arduino Uno Q SBC,
making it a self-contained food appliance. The Uno Q also broadcasts a 2.4GHz
WiFi AP ("picomate") that the Pico W connects to directly.

## Architecture

```
Pico W ──── WiFi AP (192.168.4.1) ────▶ Uno Q (food-manager :9091)
                                               │
                                         SQLite: food.db
                                               │
                                    Tailscale ─┘
                                               │
                                         Mac (Ollama :11434)
                                         nemotron-3-nano → recipes
```

## !! Tailscale Required !!

**Every command in `flash.sh` that touches the Uno Q uses Tailscale IPs.**
If Tailscale is off on either machine, all `adb` and `curl` commands will
hang or fail immediately.

| Machine | Tailscale IP    | Role                              |
|---------|-----------------|-----------------------------------|
| Mac     | 100.114.105.110 | Ollama (recipe generation)        |
| Uno Q   | 100.110.53.104  | food-manager server, AP host      |

**Before running any `flash.sh` command:**
```sh
# Check Tailscale is up on Mac
tailscale status

# Verify Uno Q is reachable
ping 100.110.53.104
```

If Tailscale is down:
- `deploy`, `push`, `restart`, `logs`, `status`, `setup` → adb connect hangs
- `health` → curl times out
- Recipe generation → Ollama unreachable (server continues, recipes return error)

Start Tailscale: open the menu bar app, or `sudo tailscale up`.

## Usage

```sh
./flash.sh              # cross-compile + push + systemd restart (default)
./flash.sh build        # compile only
./flash.sh push         # push binary + data, restart service
./flash.sh logs         # tail journalctl on Uno Q
./flash.sh status       # systemd status
./flash.sh health       # curl /health + /api/menu/packed
./flash.sh setup        # first-time: create dirs + install systemd unit
```

### First-time setup

```sh
# 1. Add cross-compile target (once)
rustup target add aarch64-unknown-linux-gnu

# 2. Create remote dirs + install systemd unit on Uno Q
./flash.sh setup

# 3. Build + deploy
./flash.sh
```

### Env vars

| Var         | Default                        | Description                    |
|-------------|-------------------------------|--------------------------------|
| `UNOQ_IP`   | `100.110.53.104`              | Uno Q Tailscale IP             |
| `OLLAMA_URL`| `http://100.114.105.110:11434`| Ollama on Mac via Tailscale    |

## Phase 2 — WiFi AP Setup

Run `network/setup-ap.sh` **on the Uno Q** to configure concurrent STA+AP:
- `wlan0` stays connected to home WiFi (for Tailscale)
- `wlan0_ap` broadcasts `picomate` SSID on 2.4GHz (for Pico W)

Before running, set the AP password in `network/hostapd.conf`:
```
wpa_passphrase=your-password-here
```

Push and run:
```sh
adb push network/ /home/arduino/unoq_food/network/
adb shell "bash /home/arduino/unoq_food/network/setup-ap.sh"
```

## Phase 3 — Re-flash Pico W

Point the Pico W at the Uno Q's AP (no code changes, just new credentials):
```sh
# In the picomate repo:
WIFI_SSID="picomate" WIFI_PASS="your-ap-password" HOST_IP="192.168.4.1" ./flash.sh
```
