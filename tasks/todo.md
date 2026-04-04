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

## Cloud + Multi-tenant Architecture (Product Vision)

**Target:** Ship Pico W devices to end users who connect to a cloud-hosted food server.
No Uno Q in the loop for end users. Uno Q remains a personal dev server.

### WiFi Provisioning — Pico W SoftAP flow

End users have no way to pre-configure WiFi credentials. Solution: Pico W acts as
a temporary AP on first boot (standard IoT onboarding pattern — same as Sonos, Hue).

```
First boot (no credentials in flash)
  └── Pico W → AP mode, broadcasts "picomate-setup"
      └── User joins "picomate-setup" on phone (no password)
          └── Captive portal opens in phone browser (served by Pico W lwIP)
              └── User fills in: home WiFi SSID / password / account email
                  └── Pico W saves credentials to flash → reboots in STA mode
                      └── Connects to home WiFi
                          └── POST /api/register {device_id, email} to cloud API
                              └── Normal operation — polls cloud for daily menu
```

Re-provisioning: hold encoder button 5s → clears WiFi flash → back to AP mode.
Device ID: derived from RP2040 unique hardware ID (no manual config).

- [ ] Implement SoftAP provisioning mode in Pico W firmware (picomate repo)
  - [ ] CYW43 AP mode init (cyw43_arch switches from STA to AP)
  - [ ] lwIP HTTP server serving a small HTML form (SSID + password + email)
  - [ ] On form submit: save credentials to flash, reboot into STA mode
  - [ ] 5-second long-press on encoder clears credentials and re-enters AP mode
- [ ] Cloud registration endpoint: `POST /api/register {device_id, email}`
- [ ] Device → user account linking in DB

### Cloud Server (Digital Ocean)

- [ ] Extend food-manager to multi-tenant (per-user food.db or shared DB with user_id)
- [ ] User auth (email + magic link or simple password)
- [ ] Device registration API (device_id → user account)
- [ ] Deploy to DO droplet ($6/mo, Rust + SQLite is very lightweight)
- [ ] Domain + TLS (Let's Encrypt via nginx reverse proxy)
- [ ] Update Pico W HOST_IP → cloud domain at compile time (or store in flash post-provisioning)

---

## Pico W Sync Frequency

Currently the Pico W fetches menu data on every encoder button press.
A background hourly sync (fetch + cache to flash) would let the OLED
show today's menu instantly without a network round-trip.

- [ ] Add hourly background HTTP GET in Pico W firmware (picomate repo)
- [ ] Cache result in flash — OLED reads from cache, no WiFi needed per-press
