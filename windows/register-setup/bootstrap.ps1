#Requires -Version 5.1
<#
    Skylinks Register Bootstrap

    Downloads setup.ps1 + packages.txt and hands off to setup.ps1. This exists
    so the Flipper payload is a single self-elevating line instead of a
    timing-sensitive keystroke sequence.

    Must run elevated. The Flipper payload launches an elevated PowerShell
    (the operator approves the UAC prompt), then runs:

        irm <raw-url-to-this-file> | iex

    Override the ref for branch testing:
        $env:SKYLINKS_SETUP_REF = 'feature/xyz'; irm <url> | iex
#>

$ErrorActionPreference = 'Stop'

# Ref the setup files are fetched from. Point this at an immutable release tag
# before rollout, and update the Flipper payload URL to the same tag.
$Ref = if ($env:SKYLINKS_SETUP_REF) { $env:SKYLINKS_SETUP_REF } else { 'master' }

$RepoRaw  = 'https://raw.githubusercontent.com/Skylinks-Golf/skylinks-computer-setups'
$BaseUrl  = "$RepoRaw/$Ref/windows/register-setup"
$SetupDir = Join-Path $env:USERPROFILE 'Skylinks-Setup'

Write-Host 'Skylinks Register bootstrap'
Write-Host "Source ref: $Ref"
Write-Host ''

New-Item -ItemType Directory -Force -Path $SetupDir | Out-Null

# TLS 1.2 for older Windows PowerShell defaults, so the download does not fail.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host 'Downloading setup files...'
Invoke-WebRequest -Uri "$BaseUrl/setup.ps1"     -OutFile (Join-Path $SetupDir 'setup.ps1')     -UseBasicParsing
Invoke-WebRequest -Uri "$BaseUrl/packages.txt"  -OutFile (Join-Path $SetupDir 'packages.txt')  -UseBasicParsing

Write-Host 'Downloaded:'
Get-ChildItem (Join-Path $SetupDir 'setup.ps1'), (Join-Path $SetupDir 'packages.txt') |
    Select-Object Name, Length | Format-Table -AutoSize | Out-String | Write-Host
Write-Host ''

Write-Host 'Starting setup...'
Write-Host ''
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $SetupDir 'setup.ps1')
exit $LASTEXITCODE
