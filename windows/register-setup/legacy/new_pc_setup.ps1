# basic_needs_script.ps1 - Configures a new PC by installing applications, setting up WiFi, adjusting power settings, and removing bloatware.

# Ensure script runs as Administrator
# If (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole("Administrator")) {
#     Start-Process PowerShell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
#     Exit
# }

# Set power settings: Never turn off display and never sleep
powercfg /change monitor-timeout-ac 0
powercfg /change monitor-timeout-dc 0
powercfg /change standby-timeout-ac 0
powercfg /change standby-timeout-dc 0

# Define WiFi credentials
$WiFiName = "YourWiFiSSID"
$WiFiPassword = "YourWiFiPassword"
netsh wlan add profile filename="C:\wifi-profile.xml" user=all
netsh wlan connect name="$WiFiName"

# Install applications for all users
$Apps = @(
    "Google.Chrome",
    "SlackTechnologies.Slack",
    "Git.Git",
    "Microsoft.PowerShell",
    "StarMicronics.StarPrinterUtility",
    "Epson.ScanSmart"
)

foreach ($App in $Apps) {
    Start-Process -NoNewWindow -Wait -FilePath "winget" -ArgumentList "install --id=$App --scope machine --silent --accept-source-agreements --accept-package-agreements" -ErrorAction SilentlyContinue
}

# Remove Windows Bloatware
$bloatware = @(
    "Microsoft.3DBuilder",
    "Microsoft.BingWeather",
    "Microsoft.GetHelp",
    "Microsoft.Getstarted",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.MixedReality.Portal",
    "Microsoft.OneConnect",
    "Microsoft.People",
    "Microsoft.Print3D",
    "Microsoft.SkypeApp",
    "Microsoft.StorePurchaseApp",
    "Microsoft.Todos",
    "Microsoft.WindowsAlarms",
    "Microsoft.WindowsCamera",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.WindowsMaps",
    "Microsoft.Xbox.TCUI",
    "Microsoft.XboxApp",
    "Microsoft.XboxGameOverlay",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.YourPhone",
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo"
)

foreach ($app in $bloatware) {
    Get-AppxPackage -AllUsers -Name $app | Remove-AppxPackage -ErrorAction SilentlyContinue
    Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like "*$app*" | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
}

# Download additional installation files
$Downloads = @(
    "https://starmicronics.com/support/products/tsp100iv-support-page/?srsltid=AfmBOoq3efraZZWdwC8H0bR5IU_Oou5l13YVuepVWSRvNcw2iuDjtpk6#"
)

$DownloadPath = "C:\Downloads"
If (!(Test-Path $DownloadPath)) { New-Item -ItemType Directory -Path $DownloadPath | Out-Null }

foreach ($URL in $Downloads) {
    $FileName = $URL.Split("/")[-1]
    $FilePath = "$DownloadPath\$FileName"
    Invoke-WebRequest -Uri $URL -OutFile $FilePath -ErrorAction SilentlyContinue
}

Write-Output "Setup complete!"