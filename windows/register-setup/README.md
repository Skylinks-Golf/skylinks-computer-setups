# Skylinks Register Setup

Boring, stable setup workflow for location-level Skylinks **registers** (POS
terminals). The third flow alongside `../../mac/admin-macbook/` (admin MacBooks) and
`../admin-laptop/` (admin Windows laptops).

## Philosophy

Simple and solid.

A register is a fixed, always-on point-of-sale machine — not a personal
laptop. This flow removes bloatware, provisions store WiFi, installs the POS
browser and support apps, and keeps the machine awake. It is not a kiosk
lockdown (no auto-login or assigned-access); that can be a later phase.

## What it installs

- Google Chrome (the web POS — Lightspeed — runs here)
- Slack (staff comms)
- PowerShell 7 (management shell)

The **Star receipt printer** driver is not on winget and is a checklist item
with the vendor URL. See `post-install-checklist.md`.

## What it configures

- **Always-on power**: display never turns off, machine never sleeps. This is
  the opposite of the admin-laptop flow, and correct for a register.
- Minimum telemetry; Cortana removed.
- Aggressive, reversible bloatware removal (Microsoft consumer apps, OEM junk,
  OneDrive).

## What it does NOT change

Security settings are **reported only**, never changed — BitLocker, Windows
Update behaviour, and the register name. In particular the script flags setting
**Windows Update active hours** so the register never reboots mid-business, but
leaves that to a human. See `post-install-checklist.md`.

## WiFi

The script prompts the operator for the store SSID + password at runtime and
provisions the profile so the register reconnects on its own. **No credentials
are stored in this repo.** The password is read as a SecureString, used only to
write a temporary profile that is deleted immediately, and never logged. Leave
the SSID blank to skip (wired registers).

## Setup method

Normal path is a Flipper Zero BadUSB payload that opens the Run dialog and
types a single self-elevating line. The operator stays with the register for
the whole run.

Without a Flipper, open an **elevated** PowerShell (right-click > Run as
administrator) and run:

```powershell
$env:SKYLINKS_SETUP_REF = 'device-setup-v2'
iex (irm https://raw.githubusercontent.com/Skylinks-Golf/skylinks-computer-setups/device-setup-v2/windows/register-setup/bootstrap.ps1)
```

`bootstrap.ps1` creates `%USERPROFILE%\Skylinks-Setup`, downloads `setup.ps1`
and `packages.txt` into it, and runs `setup.ps1`.

## Elevation

The Flipper payload runs, via the Run dialog:

```
powershell -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoExit','-Command','iex (irm <bootstrap-url>)'"
```

A normal PowerShell launches and immediately re-launches itself elevated,
triggering a **UAC prompt**. The operator clicks **Yes**. Because the elevated
window runs the bootstrap on its own, there is no keystroke timing tied to the
UAC dialog.

## Re-running

Safe to re-run. winget skips anything already installed; bloatware removal and
power settings are idempotent. WiFi can be skipped on re-runs.

## Version pinning

The Flipper payload is pinned to the immutable tag **`device-setup-v2`**: it
fetches the bootstrap from that tag and sets `SKYLINKS_SETUP_REF` to it, so
`setup.ps1` and `packages.txt` come from the same frozen snapshot. `main` stays the bleeding
edge for ad-hoc runs.

To cut a new version, tag the reviewed commit and bump the payload:

1. `git tag -a device-setup-v2 -m '...'` and `git push origin device-setup-v2`.
2. In the Flipper payload, bump both the URL ref and `SKYLINKS_SETUP_REF` to
   the new tag, then re-push the payload to the device.

For branch or latest testing, override the ref inline:

```powershell
$env:SKYLINKS_SETUP_REF = 'main'
iex (irm https://raw.githubusercontent.com/Skylinks-Golf/skylinks-computer-setups/master/windows/register-setup/bootstrap.ps1)
```

## Legacy

`legacy/` holds the earlier standalone scripts (`new_pc_setup.ps1`,
`remove_bloatware.ps1`) this flow was consolidated from. Kept for reference.

## Files

| File | Purpose |
| --- | --- |
| `bootstrap.ps1` | Entry point; downloads and runs the installer |
| `setup.ps1` | Installer (debloat + WiFi + apps + power + report) |
| `packages.txt` | Baseline app list (winget IDs) |
| `post-install-checklist.md` | Human checklist after install |
| `flipper/skylinks_register_install.txt` | BadUSB payload |
