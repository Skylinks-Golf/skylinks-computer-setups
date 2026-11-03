# Skylinks Admin Windows — Post-Install Checklist

Work through this with the laptop in hand after `setup.ps1` finishes.

## App sign-ins

- [ ] Chrome signed into Skylinks Google account
- [ ] Google Drive signed in and syncing
- [ ] Notion signed into Skylinks Golf workspace
- [ ] Slack signed into Skylinks workspace
- [ ] Claude signed in
- [ ] Zoom signed in

## Windows permissions

- [ ] Zoom Camera permission granted
- [ ] Zoom Microphone permission granted
- [ ] Slack notifications enabled
- [ ] Notion notifications enabled
- [ ] Chrome notifications configured as needed

## Browser setup

- [ ] Chrome set as default browser (Settings > Apps > Default apps)
- [ ] Skylinks Admin bookmark folder created manually if needed
- [ ] Google Workspace shortcuts added if needed
- [ ] Notion workspace bookmarked if needed
- [ ] Airtable bookmarked if needed
- [ ] Lightspeed bookmarked if needed
- [ ] Slack web fallback bookmarked if needed
- [ ] Zoom web portal bookmarked if needed

## Device settings

`setup.ps1` reports the status of the first three items but does not change
them. Anything it flagged as `[ ACTION ]` must be fixed here.

- [ ] BitLocker enabled, recovery key saved to the Skylinks account
- [ ] Automatic Windows Updates enabled
- [ ] Require sign-in on wakeup enabled
- [ ] Computer name set clearly
- [ ] Windows Update checked and applied
- [ ] Local user account confirmed
- [ ] Device added to inventory, if applicable

## Final validation

- [ ] Bloatware removal looks correct (no stray Xbox/Bing/OEM junk in Start)
- [ ] All installed apps launch
- [ ] User can access Google Workspace
- [ ] User can access Notion
- [ ] User can access Slack
- [ ] User can access Google Drive files
- [ ] User can join a Zoom test meeting
