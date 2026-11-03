Write-Host "Removing Windows bloatware..." -ForegroundColor Yellow

# List of bloatware packages to remove
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

# Remove bloatware for the current user
foreach ($app in $bloatware) {
    Write-Host "Removing $app..."
    Get-AppxPackage -AllUsers -Name $app | Remove-AppxPackage -ErrorAction SilentlyContinue
    Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like "*$app*" | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
}
Write-Host "Windows bloatware removal complete!" -ForegroundColor Green


Write-Host "Removing third-party bloatware using Winget..." -ForegroundColor Yellow

$thirdPartyBloatware = @(
    "Spotify.Spotify",
    "AdobeReader",
    "DisneyPlus.DisneyPlus",
    "Tiktok.Tiktok",
    "FacebookMessenger",
    "Instagram",
    "Twitter"
)

foreach ($app in $thirdPartyBloatware) {
    Write-Host "Uninstalling $app..."
    Start-Process -NoNewWindow -Wait -FilePath "winget" -ArgumentList "uninstall --id=$app --silent --accept-source-agreements --accept-package-agreements" -ErrorAction SilentlyContinue
}

Write-Host "Third-party bloatware removal complete!" -ForegroundColor Green



Write-Host "Disabling unnecessary Windows features..." -ForegroundColor Yellow

# Disable Cortana
Write-Host "Disabling Cortana..."
Get-AppxPackage -allusers Microsoft.549981C3F5F10 | Remove-AppxPackage -ErrorAction SilentlyContinue

# Disable Telemetry
Write-Host "Turning off Windows telemetry..."
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0

Write-Host "Unnecessary Windows features disabled!" -ForegroundColor Green