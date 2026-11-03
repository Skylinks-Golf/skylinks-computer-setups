# Register startup

At logon each register opens its Chrome windows and snaps them into place:
Lightspeed Retail left, Lightspeed Golf right, Tee Sheet TV Mode fullscreen on the second monitor.

## How updates reach the PCs

This repo is public, so each register fetches straight from it. Nothing is published or copied.
A tiny stub (`register-launcher.ps1`) runs at every logon, downloads `register-startup.ps1` and
`register-config.json` from `master`, checks they parse, and runs them. If GitHub is unreachable or
a bad copy slips through, it runs the last copy that worked.

**To fix or change anything: edit here, merge to `master`.** Registers pick it up at their next logon.
The `Validate register startup` check blocks a merge if a script has a syntax error or a window in
the config is missing a URL, so make it a required check on `master`.

- Change URLs, add windows, or give one register a different layout: `register-config.json`
  (`hosts` takes an entry keyed by lowercase computer name, e.g. `skylinks-buchanan-register-2`).
- Test on one PC first: push your change to a branch (e.g. `canary`), then set
  `C:\ProgramData\Skylinks\register\ref.txt` on that PC to the branch name. Delete the file to go back to `master`.
- Run it now without rebooting: `schtasks /run /tn "Skylinks Register Startup"`.
- Log: `C:\ProgramData\Skylinks\logs\register-startup.log`.

Only `register-launcher.ps1` itself is not self-updating. Re-run the installer to change it.

## Install on a register

Elevated PowerShell on the register:

```powershell
iex (irm https://raw.githubusercontent.com/Skylinks-Golf/skylinks-computer-setups/master/windows/register-startup/install-register-startup.ps1)
```

For auto-login too, from a saved copy: `.\install-register-startup.ps1 -User <account> -SetupAutologon`.
That opens Microsoft's Sysinternals Autologon; the operator types the password into it.
No password goes in this repo or these scripts.

## Notes

- Set Chrome's startup setting to "Open the New Tab page". "Continue where you left off" restores
  old windows and confuses placement.
- Lightspeed Hub is a desktop app, not a Chrome window. Add its exe path to `startApps` in the config.
- The task runs as the register user, not elevated. Anyone who can push to `master` controls
  what runs on every register, so protect `master` (required review, required check, 2FA). Never put
  passwords, tokens or personal data in this repo: it is public.
