# unoq_food — TODOs

## Architecture: Rethink STA vs AP mode

**Current state (Phase 2 as built):**
- Uno Q runs wlan0 as a pure 2.4GHz AP (`picomate`, 192.168.4.1)
- No home WiFi connection on Uno Q — no internet, no Tailscale, no browser access
- Pico W connects to Uno Q's AP directly

**Why this is wrong:**
- Web UI and REST API are inaccessible from home network / browser
- No Tailscale → can't deploy remotely, can't reach Ollama for recipes
- STA+AP concurrent mode on the Qualcomm chip does NOT beacon (hardware limitation)
  — wlan0_ap interface creates but never transmits when wlan0 STA is active
  — channels must match; chip supports #channels<=1 for STA+AP combo

**Better architecture:**
- Uno Q on home WiFi (STA) → food-manager accessible from LAN + browser + Tailscale
- Pico W also on home WiFi → hits Uno Q's LAN IP (not a dedicated AP)
- Pico W only needs to sync once per hour — no tight coupling required
- Recipe generation works again (Ollama reachable via Tailscale)

**TODO:**
- [ ] Revert Uno Q to STA mode (reconnect to home WiFi, drop AP mode)
- [ ] Assign Uno Q a static LAN IP or known hostname (e.g. via DHCP reservation)
- [ ] Re-flash Pico W with `HOST_IP=<uno-q-lan-ip>` pointing at Uno Q
- [ ] Update flash.sh: remove ap-cutover, default UNOQ_IP back to Tailscale IP
- [ ] Optional: keep AP as a fallback if home WiFi unreachable (but don't default to it)

---

## flash.sh — Setup Complexity

The 3-step setup sequence is non-obvious and easy to forget:
```
UNOQ_IP=<ip> ./flash.sh setup
UNOQ_IP=<ip> ./flash.sh deploy
UNOQ_IP=<ip> ./flash.sh ap-cutover   # only if AP mode is intentional
```
- [ ] Add `./flash.sh help` output that explains the sequence explicitly
- [ ] README: add a "First time on a new board" section with step-by-step
- [ ] Consider a `./flash.sh first-run` command that does setup + deploy in one shot

---

## Pico W Sync Frequency

Currently the Pico W fetches menu data on every encoder button press.
A background hourly sync (fetch + cache to flash) would let the OLED
show today's menu instantly without a network round-trip.

- [ ] Add hourly background HTTP GET in Pico W firmware (picomate repo)
- [ ] Cache result in flash — OLED reads from cache, no WiFi needed per-press
