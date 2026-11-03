#Requires -Version 5.1
<#
    Skylinks Register (POS) Setup

    Provisions a location-level Skylinks register: aggressive bloatware
    removal, optional WiFi provisioning, baseline app install via winget,
    always-on power settings, light optimization, and a read-only security
    posture report.

    Intended to be run with an operator physically present in-store: winget
    install and some removals surface UAC / app dialogs, and WiFi provisioning
    prompts for the store credentials.

    Safe to re-run. winget skips anything already installed.

    Unlike the admin-laptop flow, a register is a fixed, always-on machine, so
    this DOES keep the display on and disable sleep. It changes no security
    settings; it only reports them.
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

Write-Section 'Skylinks Register Setup'
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

# ---------------------------------------------------------------------------
# WiFi provisioning (operator-supplied; nothing stored in the repo)
#
# The password is read as a SecureString and only materialised long enough to
# write the temporary profile, which is deleted immediately. It is never
# written to the log. Leave the SSID blank to skip (e.g. wired registers).
# ---------------------------------------------------------------------------

Write-Section 'WiFi provisioning'
Write-Host 'Provision the store WiFi so the register reconnects on its own.'
Write-Host 'Leave the SSID blank to skip (wired register or already connected).'
Write-Host ''
$Ssid = Read-Host 'WiFi SSID (blank to skip)'
if ($Ssid) {
    $Secure = Read-Host "Password for '$Ssid'" -AsSecureString
    $Bstr   = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
    $PlainPw = [Runtime.InteropServices.Marshal]::PtrToStringAuto($Bstr)
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($Bstr)

    $SsidX = [Security.SecurityElement]::Escape($Ssid)
    $PwX   = [Security.SecurityElement]::Escape($PlainPw)
    $Profile = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
  <name>$SsidX</name>
  <SSIDConfig><SSID><name>$SsidX</name></SSID></SSIDConfig>
  <connectionType>ESS</connectionType>
  <connectionMode>auto</connectionMode>
  <MSM>
    <security>
      <authEncryption>
        <authentication>WPA2PSK</authentication>
        <encryption>AES</encryption>
        <useOneX>false</useOneX>
      </authEncryption>
      <sharedKey>
        <keyType>passPhrase</keyType>
        <protected>false</protected>
        <keyMaterial>$PwX</keyMaterial>
      </sharedKey>
    </security>
  </MSM>
</WLANProfile>
"@
    $ProfilePath = Join-Path $env:TEMP ("wifi-{0}.xml" -f ([guid]::NewGuid().ToString('N')))
    try {
        Set-Content -Path $ProfilePath -Value $Profile -Encoding UTF8
        netsh wlan add profile filename="$ProfilePath" user=all | Out-Null
        netsh wlan connect name="$Ssid" | Out-Null
        Write-Host "WiFi profile for '$Ssid' added and connection attempted."
    } finally {
        Remove-Item $ProfilePath -Force -ErrorAction SilentlyContinue
        $PlainPw = $null
    }
} else {
    Write-Host 'Skipped WiFi provisioning.'
}

# ---------------------------------------------------------------------------
# Aggressive bloatware removal
#
# Reversible from the Microsoft Store. Lists exclude system-critical packages
# (Store, winget/App Installer, Terminal, Defender, .NET/VCLibs, Calculator,
# Notepad, Snipping Tool, Camera).
# ---------------------------------------------------------------------------

Write-Section 'Removing bloatware (aggressive)'

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
    'Microsoft.windowscommunicationsapps'
    'MicrosoftTeams'
    'Microsoft.Xbox.TCUI'
    'Microsoft.XboxApp'
    'Microsoft.XboxGameOverlay'
    'Microsoft.XboxGamingOverlay'
    'Microsoft.XboxIdentityProvider'
    'Microsoft.XboxSpeechToTextOverlay'
    'Microsoft.GamingApp'
)

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

# OneDrive: not used on a register. Remove the per-user client.
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

Write-Section 'Installing Skylinks register apps'

$ids = Get-Content $PackagesFile |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and -not $_.StartsWith('#') }

$AlreadyInstalled = -1978335189

function Install-Package([string]$Id) {
    Write-Host "Installing $Id ..."
    & $WingetExe install --id $Id --exact --silent --scope machine `
        --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $AlreadyInstalled) { return $true }

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
    Write-Host 'All register apps installed.'
}

# ---------------------------------------------------------------------------
# Register configuration
#
# A register is a fixed, always-on machine: keep the display on and never
# sleep. This is the OPPOSITE of the admin-laptop flow, and intentional.
# ---------------------------------------------------------------------------

Write-Section 'Register configuration'

Write-Host 'Setting power to always-on (display never off, never sleep)...'
powercfg /change monitor-timeout-ac 0
powercfg /change monitor-timeout-dc 0
powercfg /change standby-timeout-ac 0
powercfg /change standby-timeout-dc 0

# Telemetry. Fully effective on Pro/Enterprise; limited on Home editions.
$dc = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
New-Item -Path $dc -Force | Out-Null
Set-ItemProperty -Path $dc -Name 'AllowTelemetry' -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host 'Telemetry policy set to minimum (Pro/Enterprise; limited on Home).'

# Cortana.
Get-AppxPackage -AllUsers Microsoft.549981C3F5F10 -ErrorAction SilentlyContinue |
    Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
Write-Host 'Cortana removed.'

# ---------------------------------------------------------------------------
# Security posture (report only - changes nothing)
# ---------------------------------------------------------------------------

Write-Section 'Security posture (report only)'

try {
    $bl = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
    if ($bl.ProtectionStatus -eq 'On') {
        Write-Host "[ OK    ] BitLocker is on for $env:SystemDrive."
    } else {
        Write-Host "[ ACTION] BitLocker is NOT on for $env:SystemDrive (status: $($bl.ProtectionStatus))."
        Write-Host '          If store policy requires it, enable it and save the recovery key.'
    }
} catch {
    Write-Host '[ CHECK ] Could not read BitLocker status. Verify manually in Settings > BitLocker.'
}

$au = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -ErrorAction SilentlyContinue
if ($au -and $au.NoAutoUpdate -eq 1) {
    Write-Host '[ ACTION] Automatic Windows Updates are DISABLED.'
    Write-Host '          Enable them: Settings > Windows Update > Advanced options.'
} else {
    Write-Host '[ OK    ] Automatic Windows Updates are not disabled by policy.'
}
Write-Host '[ ACTION] Set active hours so the register never reboots mid-business:'
Write-Host '          Settings > Windows Update > Advanced options > Active hours.'

Write-Host ''
Write-Host "Computer name: $env:COMPUTERNAME"
Write-Host '          Set a clear register name: Settings > System > About > Rename this PC.'

# ---------------------------------------------------------------------------
# Manual steps
# ---------------------------------------------------------------------------

Write-Section $(if ($script:InstallFailed -eq 1) { 'Setup finished WITH ERRORS' } else { 'Setup complete' })

Write-Host 'Manual next steps:'
Write-Host ''
Write-Host '1. Install the Star receipt printer driver (not available via winget):'
Write-Host '   https://www.starmicronics.com/support/'
Write-Host '   Pick the register model (e.g. TSP100 family), install, then print a'
Write-Host '   test receipt.'
Write-Host '2. Sign into Chrome and open the POS (Lightspeed). Bookmark it.'
Write-Host '3. Sign into Slack with the store account.'
Write-Host '4. Confirm WiFi is connected (or the register is wired).'
Write-Host '5. Set Chrome as the default browser (Settings > Apps > Default apps).'
Write-Host ''
Write-Host 'Resolve anything marked [ ACTION ] in the security section above.'
Write-Host ''
Write-Host 'Full checklist: post-install-checklist.md in the repo.'
Write-Host "Setup files and logs are saved in: $SetupDir"
Write-Host ''

Stop-Transcript | Out-Null

if ($script:InstallFailed -eq 1) { exit 1 } else { exit 0 }
