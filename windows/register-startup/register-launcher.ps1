<#
Stable stub installed once on each register by install-register-startup.ps1 and run by the
"Skylinks Register Startup" scheduled task at logon. It stays tiny on purpose: it pulls the
real script and config from GitHub, validates them, and runs them. Falls back to the last
copy that worked if GitHub is unreachable or a bad push slips through.

Deploy channel: the master branch of Skylinks-Golf/skylinks-computer-setups (public). To test on one PC, put a branch name in
C:\ProgramData\Skylinks\register\ref.txt.
#>
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$root = Join-Path $env:ProgramData 'Skylinks\register'
$logDir = Join-Path $env:ProgramData 'Skylinks\logs'
$log = Join-Path $logDir 'register-startup.log'
$files = 'register-startup.ps1', 'register-config.json'
New-Item -ItemType Directory -Force -Path $root, $logDir, "$root\current", "$root\good" | Out-Null

function Write-Log([string]$Message) {
    Add-Content -Path $log -Value ('{0:yyyy-MM-dd HH:mm:ss} [launcher] {1}' -f (Get-Date), $Message)
}

# Keep the log from growing forever.
if ((Test-Path $log) -and (Get-Item $log).Length -gt 512KB) {
    Get-Content $log -Tail 500 | Set-Content "$log.tmp"; Move-Item "$log.tmp" $log -Force
}

$ref = 'master'
if (Test-Path "$root\ref.txt") { $ref = (Get-Content "$root\ref.txt" -Raw).Trim() }
$base = "https://raw.githubusercontent.com/Skylinks-Golf/skylinks-computer-setups/$ref/windows/register-startup"

# Download to a temp folder and validate before touching "current".
$tmp = Join-Path $env:TEMP ('sky-register-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    foreach ($f in $files) { Invoke-WebRequest -UseBasicParsing -Uri "$base/$f" -OutFile "$tmp\$f" -TimeoutSec 20 }
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile("$tmp\register-startup.ps1", [ref]$null, [ref]$parseErrors)
    if ($parseErrors) { throw "register-startup.ps1 has syntax errors: $($parseErrors[0].Message)" }
    [void](Get-Content -Raw "$tmp\register-config.json" | ConvertFrom-Json)
    Copy-Item "$tmp\*" "$root\current" -Force
    Write-Log "Updated from $ref"
} catch {
    Write-Log "Update skipped ($ref): $_"
} finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

function Invoke-Startup([string]$Dir) {
    & "$Dir\register-startup.ps1" -ConfigPath "$Dir\register-config.json" -LogPath $log
}

$ran = $false
if (Test-Path "$root\current\register-startup.ps1") {
    try {
        Invoke-Startup "$root\current"
        Copy-Item "$root\current\*" "$root\good" -Force
        $ran = $true
    } catch {
        Write-Log "Current version failed: $_"
    }
}
if (-not $ran -and (Test-Path "$root\good\register-startup.ps1")) {
    Write-Log 'Falling back to last good version'
    try { Invoke-Startup "$root\good" } catch { Write-Log "Last good version failed too: $_"; throw }
} elseif (-not $ran) {
    Write-Log 'Nothing to run: no download and no cached copy'
    throw 'No startup script available'
}
