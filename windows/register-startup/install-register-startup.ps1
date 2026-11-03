<#
One-time install on each register. Run from an elevated PowerShell:

  iex (irm https://raw.githubusercontent.com/Skylinks-Golf/skylinks-computer-setups/master/windows/register-startup/install-register-startup.ps1)

Or with options, from a saved copy:
  .\install-register-startup.ps1 -User register -SetupAutologon

Safe to re-run; it replaces the stub and the scheduled task.
#>
[CmdletBinding()]
param(
    # The Windows account the register logs in as. The task runs as this user, not elevated.
    [string]$User = $env:USERNAME,
    [string]$Ref = 'master',
    # Opens Sysinternals Autologon so the operator types the password into Microsoft's tool.
    # The password is stored as an encrypted LSA secret and never touches this script.
    [switch]$SetupAutologon
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this from an elevated PowerShell (right-click > Run as administrator).'
}

$root = Join-Path $env:ProgramData 'Skylinks\register'
New-Item -ItemType Directory -Force -Path $root, (Join-Path $env:ProgramData 'Skylinks\logs') | Out-Null

$stubUrl = "https://raw.githubusercontent.com/Skylinks-Golf/skylinks-computer-setups/$Ref/windows/register-startup/register-launcher.ps1"
Invoke-WebRequest -UseBasicParsing -Uri $stubUrl -OutFile "$root\register-launcher.ps1"
if ($Ref -ne 'master') { Set-Content -Path "$root\ref.txt" -Value $Ref }
Write-Host "Installed launcher to $root"

$taskName = 'Skylinks Register Startup'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$root\register-launcher.ps1`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $User
$taskPrincipal = New-ScheduledTaskPrincipal -UserId $User -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $taskPrincipal `
    -Settings $settings -Force | Out-Null
Write-Host "Scheduled task '$taskName' runs at logon for $User"

if ($SetupAutologon) {
    $exe = Join-Path $env:TEMP 'Autologon64.exe'
    Invoke-WebRequest -UseBasicParsing -Uri 'https://live.sysinternals.com/Autologon64.exe' -OutFile $exe
    $sig = Get-AuthenticodeSignature $exe
    if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'Microsoft') {
        throw "Autologon64.exe signature check failed ($($sig.Status)); not running it."
    }
    Write-Host "Enter the register account and password in the Autologon window, then click Enable."
    Start-Process -FilePath $exe -ArgumentList '/accepteula' -Wait
}

Write-Host "Done. Test now with: schtasks /run /tn `"$taskName`"   (log: $env:ProgramData\Skylinks\logs\register-startup.log)"
