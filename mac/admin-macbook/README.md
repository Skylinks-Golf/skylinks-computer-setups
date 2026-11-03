# Skylinks Admin MacBook Setup

Boring, stable setup workflow for location-level Skylinks admin/manager
MacBooks. The macOS counterpart to `../../windows/register-setup/` (register POS setup).

## Philosophy

Simple and solid.

This is not MDM. This is not account provisioning. This is not a developer
laptop bootstrap. It installs the baseline apps expected on a standard
Skylinks admin MacBook, then hands off to a human checklist.

## What it installs

- Google Chrome
- Google Drive
- Notion
- Slack
- Zoom
- Claude Desktop

## What it intentionally does not install

- Microsoft Office
- Quality-of-life apps
- Developer tools
- GitHub/GCP tooling
- Password managers
- Role-specific software

Microsoft Office is excluded because Office is only for select company-level
staff. Location-based admins and managers do not need it by default.

## Setup method

Normal path is a Flipper Zero BadUSB payload that opens Terminal and types a
single bootstrap line. The operator stays with the laptop for the whole run —
macOS will prompt for the admin password and for app permissions.

Without a Flipper, open Terminal and run the same line by hand:

```bash
SKYLINKS_SETUP_REF=device-setup-v2 bash -c "$(curl -fsSL https://raw.githubusercontent.com/Skylinks-Golf/skylinks-computer-setups/device-setup-v2/mac/admin-macbook/bootstrap.sh)"
```

`bootstrap.sh` creates `~/Skylinks-Setup`, downloads `setup.sh` and `Brewfile`
into it, and runs `setup.sh`.

The `$(...)` form matters — a plain `curl | bash` pipe steals stdin and the
admin password prompt fails.

## What setup.sh does

1. Checks network access.
2. Prompts for the admin password once, up front, and keeps it warm.
3. Installs Homebrew if missing (which also installs the Xcode Command Line
   Tools — there is no separate step for those).
4. Adds Homebrew to `PATH` for future Terminal sessions via `~/.zprofile`.
5. Runs `brew bundle` against the Brewfile.
6. Opens Chrome so Chrome can show its own "make default" prompt.
7. Reports FileVault, automatic updates, and screen lock status.
8. Prints the manual sign-in and permission steps.

Everything is logged to `~/Skylinks-Setup/setup-<timestamp>.log`.

A failed app install does not abort the run. The script warns, finishes, prints
the checklist, and exits non-zero.

## Security posture reporting

`setup.sh` reports on FileVault, automatic update checks, and password-after-
sleep, but deliberately changes none of them. These are the controls most
likely to get eyeballed during a rushed handoff, so the script makes skipping
them visible. The human still does the fixing.

## Manual steps still required

The script does not and should not automate:

- macOS admin password prompts
- macOS permission dialogs
- App sign-ins and workspace selection
- Setting the default browser (macOS blocks silent changes)
- Bookmark setup
- FileVault, updates, and lock screen changes

Use `post-install-checklist.md` to close these out.

## Re-running

Safe to re-run. Homebrew skips anything already installed.

```bash
cd ~/Skylinks-Setup
./setup.sh
```

## Version pinning

The Flipper payload is pinned to the immutable tag **`device-setup-v2`**: it
fetches the bootstrap from that tag and sets `SKYLINKS_SETUP_REF` to it, so
`setup.sh` and `Brewfile` come from the same frozen snapshot. `main` stays the bleeding
edge for ad-hoc runs.

To cut a new version, tag the reviewed commit and bump the payload:

1. `git tag -a device-setup-v2 -m '...'` and `git push origin device-setup-v2`.
2. In the Flipper payload, bump both the URL ref and `SKYLINKS_SETUP_REF` to
   the new tag, then re-push the payload to the device.

For branch or latest testing, override the ref inline:

```bash
SKYLINKS_SETUP_REF=main \
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/Skylinks-Golf/skylinks-computer-setups/master/mac/admin-macbook/bootstrap.sh)"
```

## Files

| File | Purpose |
| --- | --- |
| `bootstrap.sh` | One-line entry point; downloads and runs the installer |
| `setup.sh` | Installer |
| `Brewfile` | Baseline app list |
| `post-install-checklist.md` | Human checklist after install |
| `flipper/skylinks_admin_mac_install.txt` | BadUSB payload |
