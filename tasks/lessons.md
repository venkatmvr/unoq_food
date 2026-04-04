# Lessons Learned

## WiFi AP/STA on Qualcomm (Uno Q / MVVR-Q)

### STA+AP concurrent mode does not beacon

**What happened:**
Set up `wlan0_ap` virtual interface via `iw dev wlan0 interface add wlan0_ap type __ap`.
hostapd reported `AP-ENABLED` and `iw dev wlan0_ap info` showed the correct SSID and channel.
Neither the Pico W nor a Mac could detect the `picomate` SSID. No connection attempts
appeared in hostapd debug logs.

**Root cause:**
The Qualcomm chip (phy0) declares this interface combination:
```
#{ managed } <= 2, #{ AP, P2P-client, P2P-GO } <= 2,  #channels <= 1
```
STA and AP must share the **same channel**. The STA (wlan0) was connected to home WiFi on
**5GHz channel 157** while the AP was configured for **2.4GHz channel 6**. Different bands =
the hardware could not transmit AP beacons. The AP interface exists in software but the
single radio is locked to the STA's channel.

**Fix attempted:**
Forced wlan0 to 2.4GHz (`nmcli connection modify band=bg`). Even with both interfaces
on the same 2.4GHz channel, the AP still did not beacon. The driver appears to silently
suppress AP beacons when a STA connection is active, despite the hardware combination
claiming it is supported.

**Resolution:**
Dropped wlan0_ap entirely. Used wlan0 directly as the AP (pure AP mode, no STA).
Trade-off: Uno Q loses home WiFi / internet / Tailscale.

**For future reference:**
- Do not assume STA+AP works on a Qualcomm chip just because `iw list` says `#channels <= 1`
  — the driver may not implement concurrent beaconing even when the hardware claims support.
- Verify AP is actually beaconing before debugging the client: `iw dev <phy> scan` from
  another interface on the same machine, or check from a second device.
- P2P-device trick (`iw phy phy0 interface add p2p-dev0 type p2p-device`) to unlock the
  2-channel combination was not supported: `invalid interface type p2p-device`.
- If STA+AP is required on this hardware, a USB WiFi dongle (dedicated 2.4GHz) is the
  reliable solution.

---

## systemd ExecStart — no shell syntax

**What happened:**
Service file used `ExecStartPost=/sbin/ip addr add 192.168.4.1/24 dev wlan0_ap 2>/dev/null || true`.
systemd passed `2>/dev/null` as a literal argument to `ip`, which failed with:
`Error: either "local" is duplicate, or "2>/dev/null" is garbage.`

**Rule:**
Shell redirection (`2>/dev/null`), pipes (`|`), and logical operators (`||`, `&&`) do NOT
work in `ExecStart`/`ExecStartPost` lines. Wrap in `/bin/bash -c '...'` when shell
syntax is needed.

---

## hostapd masked by apt-get install

**What happened:**
`apt-get install hostapd` on Debian/Ubuntu creates a symlink
`/etc/systemd/system/hostapd.service → /dev/null` (masked) by default.
`systemctl enable hostapd` fails with `Unit is masked`.

**Fix:**
Always run `sudo systemctl unmask hostapd` immediately after installing.

---

## adb vs SSH for Linux SBCs

**What happened:**
Assumed the Arduino Uno Q used adb (Android Debug Bridge) for remote access.
`adb connect <ip>:5555` failed — port refused.

**Root cause:**
The Uno Q runs standard Linux (Debian/Ubuntu), not Android. adb is not available.
Use `ssh` + `scp` for all remote access.

**Rule:**
adb is Android-only. For any Linux SBC (Raspberry Pi, Uno Q, etc.) use ssh/scp.
Check `uname -a` first if unsure.

---

## sudo -S requires explicit -p '' to suppress prompt

**What happened:**
`rssh "echo 'password' | sudo -S command"` failed with
`sudo: a terminal is required to read the password`.

**Fix:**
Use `sudo -S -p ''` — the `-p ''` suppresses the password prompt string that sudo
tries to write to the terminal, which confuses non-TTY sessions.
Full pattern: `rssh "echo 'PASSWORD' | sudo -S -p '' command"`

**Better long-term fix:**
Configure `/etc/sudoers.d/arduino-nopasswd` with `NOPASSWD: ALL` during setup
so sudo never prompts. Eliminates password-in-command-line entirely.

---

## NM band=bg does not guarantee 2.4GHz connection

**What happened:**
`nmcli connection modify 'fairbanks-2.4' 802-11-wireless.band bg` then reconnected.
NetworkManager connected to a different SSID (`Hunter`) on 5GHz instead.

**Why:**
Setting `band=bg` on a connection profile constrains that profile, but NM may activate
a different auto-connect profile that matches better. The `fairbanks-2.4` SSID was not
present on the 2.4GHz band at that moment.

**Fix:**
Specify both `band=bg` and `channel=<n>` AND use a BSSID if you need a specific AP.
Or: use `nmcli device wifi connect <SSID> bssid <XX:XX:XX:XX:XX:XX>` for a one-shot
connection to a specific radio.
