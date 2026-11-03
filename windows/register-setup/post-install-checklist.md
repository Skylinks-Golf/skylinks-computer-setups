# Skylinks Register — Post-Install Checklist

Work through this at the register after `setup.ps1` finishes.

## Peripherals

The Star receipt printer driver is **not** on winget and must be installed by
hand.

- [ ] Star receipt printer driver installed
      (https://www.starmicronics.com/support/ — pick the register model, e.g.
      the TSP100 family)
- [ ] Test receipt prints correctly
- [ ] Cash drawer opens on print (if wired to the printer)

## Apps and POS

- [ ] Chrome signed into the store Google account
- [ ] POS (Lightspeed) opens in Chrome and is bookmarked
- [ ] Chrome set as default browser (Settings > Apps > Default apps)
- [ ] Slack signed into the store workspace

## Network

- [ ] WiFi connected (or the register is wired)
- [ ] Connection survives a reboot

## Register configuration

Applied by `setup.ps1`:

- [ ] Display stays on / never sleeps (verify Settings > Power)

Report-only — `setup.ps1` flags these but does not change them:

- [ ] Windows Update active hours set to avoid mid-business reboots
- [ ] BitLocker matches store policy (recovery key saved if enabled)
- [ ] Register named clearly (Settings > System > About)
- [ ] Windows Update checked and applied

## Final validation

- [ ] Bloatware removal looks correct (no stray Xbox/Bing/OEM junk in Start)
- [ ] A full sale can be rung up end to end
- [ ] Receipt prints on a real transaction
- [ ] Register reconnects to network and POS after a reboot
