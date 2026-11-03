#Requires -Version 5.1
<#
    Skylinks Admin Windows Setup

    Provisions a location-level Skylinks admin/manager Windows laptop:
    aggressive bloatware removal, baseline app install via winget, light
    optimization, and a read-only security posture report.

    Intended to be run with an operator physically present: winget install and
    some removals surface UAC / app dialogs.

    Safe to re-run. winget skips anything already installed.

    Deliberately does NOT touch power settings - this is a laptop, not a
    register/kiosk. It also changes no security settings; it only reports them.
#>

# Never abort the whole run on a single failure - the manual checklist at the
# end is the most useful output.
$ErrorActionPreference = 'Continue'
$script:InstallFailed = 0

$SetupDir = Join-Path $env:USERPROFILE 'Skylinks-Setup'
New-Item -ItemType Directory -Force -Path $SetupDir | Out-Null
$Log = Join-Path $SetupDir ('setup-{0}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
Start-Transcript -Path $Log -Append | Out-Null

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Section($Title) {
    Write-Host ''
    Write-Host '======================================'
    Write-Host " $Title"
    Write-Host '======================================'
    Write-Host ''
}

Write-Section 'Skylinks Admin Windows Setup'
Write-Host "Setup directory: $SetupDir"
Write-Host "Log file:        $Log"
Write-Host ''

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------

$IsAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Write-Host 'ERROR: This script must run as Administrator.' -ForegroundColor Red
    Write-Host 'Re-launch an elevated PowerShell and run the bootstrap again.'
    Stop-Transcript | Out-Null
    exit 1
}

$PackagesFile = Join-Path $SetupDir 'packages.txt'
if (-not (Test-Path $PackagesFile)) {
    Write-Host "ERROR: packages.txt not found at $PackagesFile" -ForegroundColor Red
    Write-Host 'Make sure the bootstrap downloaded both setup.ps1 and packages.txt.'
    Stop-Transcript | Out-Null
    exit 1
}

# Resolve winget. It is the brew analogue and must be present.
$WingetExe = $null
$wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
if ($wingetCmd) {
    $WingetExe = $wingetCmd.Source
} else {
    $probe = Get-ChildItem "$env:ProgramFiles\WindowsApps" -Filter winget.exe -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($probe) { $WingetExe = $probe.FullName }
}
if (-not $WingetExe) {
    Write-Host 'ERROR: winget (App Installer) was not found.' -ForegroundColor Red
    Write-Host 'Install "App Installer" from the Microsoft Store, then re-run.'
    Stop-Transcript | Out-Null
    exit 1
}
Write-Host "winget: $WingetExe"
Write-Host ''

# ---------------------------------------------------------------------------
# Aggressive bloatware removal
#
# Reversible: anything removed here can be reinstalled from the Microsoft
# Store. The lists deliberately exclude system-critical packages (Store,
# winget/App Installer, Terminal, Defender, .NET/VCLibs, Calculator, Notepad,
# Snipping Tool, Camera) so the machine stays usable.
# ---------------------------------------------------------------------------

Write-Section 'Removing bloatware (aggressive)'

# Exact Microsoft consumer apps.
$AppxExact = @(
    'Microsoft.3DBuilder'
    'Microsoft.BingFinance'
    'Microsoft.BingNews'
    'Microsoft.BingSports'
    'Microsoft.BingWeather'
    'Microsoft.Clipchamp'
    'Microsoft.GetHelp'
    'Microsoft.Getstarted'
    'Microsoft.Messaging'
    'Microsoft.MicrosoftOfficeHub'
    'Microsoft.MicrosoftSolitaireCollection'
    'Microsoft.MixedReality.Portal'
    'Microsoft.OneConnect'
    'Microsoft.People'
    'Microsoft.PowerAutomateDesktop'
    'Microsoft.Print3D'
    'Microsoft.SkypeApp'
    'Microsoft.Todos'
    'Microsoft.Windows.DevHome'
    'Microsoft.WindowsAlarms'
    'Microsoft.WindowsFeedbackHub'
    'Microsoft.WindowsMaps'
    'Microsoft.WindowsSoundRecorder'
    'Microsoft.YourPhone'
    'Microsoft.ZuneMusic'
    'Microsoft.ZuneVideo'
    'Microsoft.windowscommunicationsapps'   # Mail & Calendar - Skylinks uses Google
    'MicrosoftTeams'                          # consumer/personal Teams
    'Microsoft.Xbox.TCUI'
    'Microsoft.XboxApp'
    'Microsoft.XboxGameOverlay'
    'Microsoft.XboxGamingOverlay'
    'Microsoft.XboxIdentityProvider'
    'Microsoft.XboxSpeechToTextOverlay'
    'Microsoft.GamingApp'
)

# Wildcard patterns for OEM-preloaded consumer junk (Spotify, TikTok, games,
# streaming, social). Scoped to known-bloat names to stay safe.
$AppxWildcards = @(
    '*CandyCrush*'
    '*king.com*'
    '*Spotify*'
    '*Disney*'
    '*BytedancePte.TikTok*'
    '*Facebook*'
    '*Instagram*'
    '*Twitter*'
    '*Netflix*'
    '*AmazonVideo*'
    '*PrimeVideo*'
    '*Duolingo*'
    '*Roblox*'
    '*WhatsApp*'
    '*LinkedInforWindows*'
    '*Microsoft.Copilot*'
)

function Remove-AppxByName([string]$Match) {
    Get-AppxPackage -AllUsers -Name $Match -ErrorAction SilentlyContinue |
        Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like $Match } |
        ForEach-Object {
            Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null
        }
}

foreach ($name in $AppxExact) {
    Write-Host "  removing $name"
    Remove-AppxByName $name
}
foreach ($pat in $AppxWildcards) {
    Write-Host "  removing $pat"
    Remove-AppxByName $pat
}

# OneDrive: Skylinks standardises on Google Drive. Remove the per-user client.
Write-Host '  removing OneDrive'
Get-Process OneDrive -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
$oneDriveSetup = @(
    "$env:SystemRoot\System32\OneDriveSetup.exe"
    "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($oneDriveSetup) {
    Start-Process -FilePath $oneDriveSetup -ArgumentList '/uninstall' -NoNewWindow -Wait -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host 'Bloatware pass complete.'

# ---------------------------------------------------------------------------
# Baseline apps
# ---------------------------------------------------------------------------

Write-Section 'Installing Skylinks baseline apps'

$ids = Get-Content $PackagesFile |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and -not $_.StartsWith('#') }

# winget "already installed / no upgrade" exit code - treat as success.
$AlreadyInstalled = -1978335189

function Install-Package([string]$Id) {
    Write-Host "Installing $Id ..."
    & $WingetExe install --id $Id --exact --silent --scope machine `
        --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $AlreadyInstalled) { return $true }

    # Some apps do not support machine scope; retry without it.
    & $WingetExe install --id $Id --exact --silent `
        --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $AlreadyInstalled) { return $true }

    Write-Host "WARNING: $Id failed (winget exit $LASTEXITCODE)." -ForegroundColor Yellow
    return $false
}

foreach ($id in $ids) {
    if (-not (Install-Package $id)) { $script:InstallFailed = 1 }
}

if ($script:InstallFailed -eq 1) {
    Write-Host ''
    Write-Host "WARNING: one or more apps failed. See the log: $Log" -ForegroundColor Yellow
    Write-Host 'Continuing so the manual checklist is still shown.'
} else {
    Write-Host ''
    Write-Host 'All baseline apps installed.'
}

# ---------------------------------------------------------------------------
# Optimization (ported from the register script; power settings deliberately
# NOT ported - this is a laptop).
# ---------------------------------------------------------------------------

Write-Section 'Applying optimizations'

# Telemetry. Fully effective on Pro/Enterprise; limited on Home editions.
$dc = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
New-Item -Path $dc -Force | Out-Null
Set-ItemProperty -Path $dc -Name 'AllowTelemetry' -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host 'Telemetry policy set to minimum (Pro/Enterprise; limited on Home).'

# Cortana.
Get-AppxPackage -AllUsers Microsoft.549981C3F5F10 -ErrorAction SilentlyContinue |
    Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
Write-Host 'Cortana removed.'

# Default browser: Windows blocks silent changes since Windows 10. Open Chrome
# so it can offer to make itself default.
$chrome = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($chrome) {
    Write-Host ''
    Write-Host 'Opening Chrome so it can offer to become the default browser.'
    Write-Host 'Accept its prompt, or set it in Settings > Apps > Default apps.'
    Start-Process -FilePath $chrome -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# Security posture (report only - changes nothing)
# ---------------------------------------------------------------------------

Write-Section 'Security posture (report only)'

# BitLocker on the system drive.
try {
    $bl = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
    if ($bl.ProtectionStatus -eq 'On') {
        Write-Host "[ OK    ] BitLocker is on for $env:SystemDrive."
    } else {
        Write-Host "[ ACTION] BitLocker is NOT on for $env:SystemDrive (status: $($bl.ProtectionStatus))."
        Write-Host '          Enable it: Settings > Privacy & security > Device encryption / BitLocker.'
        Write-Host '          Save the recovery key to the Skylinks account.'
    }
} catch {
    Write-Host '[ CHECK ] Could not read BitLocker status. Verify manually in Settings > BitLocker.'
}

# Windows Update automatic behaviour.
$au = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -ErrorAction SilentlyContinue
if ($au -and $au.NoAutoUpdate -eq 1) {
    Write-Host '[ ACTION] Automatic Windows Updates are DISABLED.'
    Write-Host '          Enable them: Settings > Windows Update > Advanced options.'
} else {
    Write-Host '[ OK    ] Automatic Windows Updates are not disabled by policy.'
}
Write-Host '          Run a manual check now: Settings > Windows Update > Check for updates.'

# Lock on wake - hard to read reliably; report and point at the setting.
Write-Host '[ CHECK ] Verify "require sign-in on wakeup":'
Write-Host '          Settings > Accounts > Sign-in options > If you have been away...'

Write-Host ''
Write-Host "Computer name: $env:COMPUTERNAME"
Write-Host '          Set a clear name: Settings > System > About > Rename this PC.'

# ---------------------------------------------------------------------------
# Manual steps
# ---------------------------------------------------------------------------

Write-Section $(if ($script:InstallFailed -eq 1) { 'Install finished WITH ERRORS' } else { 'Install complete' })

Write-Host 'Manual next steps:'
Write-Host ''
Write-Host '1. Sign into Chrome with the Skylinks Google account.'
Write-Host '2. Set Chrome as the default browser.'
Write-Host '3. Sign into Google Drive.'
Write-Host '4. Sign into Notion and select the Skylinks Golf workspace.'
Write-Host '5. Sign into Slack.'
Write-Host '6. Sign into Claude.'
Write-Host '7. Sign into Zoom.'
Write-Host ''
Write-Host 'Windows permissions to grant:'
Write-Host '- Zoom: Camera, Microphone'
Write-Host '- Slack / Notion / Chrome: Notifications, as needed'
Write-Host ''
Write-Host 'Resolve anything marked [ ACTION ] in the security section above.'
Write-Host ''
Write-Host 'Full checklist: post-install-checklist.md in the repo.'
Write-Host "Setup files and logs are saved in: $SetupDir"
Write-Host ''

Stop-Transcript | Out-Null

if ($script:InstallFailed -eq 1) { exit 1 } else { exit 0 }
