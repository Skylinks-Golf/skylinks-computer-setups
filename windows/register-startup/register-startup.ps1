<#
Skylinks register startup: opens the Chrome windows listed in register-config.json
and snaps each one to its spot. Fetched fresh at every logon by register-launcher.ps1,
so edit it in the repo and merge to master; nothing needs copying to the PCs.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ConfigPath,
    [string]$LogPath = (Join-Path $env:ProgramData 'Skylinks\logs\register-startup.log')
)

$ErrorActionPreference = 'Stop'

function Write-Log([string]$Message) {
    $line = '{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $Message
    Write-Host $line
    try { Add-Content -Path $LogPath -Value $line } catch { }
}

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class SkyWin {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc p, IntPtr l);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern int GetWindowTextLength(IntPtr h);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int ht, uint flags);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr h, int attr, out RECT r, int size);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();

    // Visible top-level Chrome windows as "handle:pid" (Slack and Edge share the class name, so callers filter by pid).
    public static List<string> ChromeWindows() {
        var found = new List<string>();
        EnumWindows((h, l) => {
            if (!IsWindowVisible(h) || GetWindowTextLength(h) == 0) return true;
            var cls = new StringBuilder(64);
            GetClassName(h, cls, cls.Capacity);
            if (cls.ToString() != "Chrome_WidgetWin_1") return true;
            uint pid; GetWindowThreadProcessId(h, out pid);
            found.Add(h.ToInt64() + ":" + pid);
            return true;
        }, IntPtr.Zero);
        return found;
    }

    // Moves a window so its visible edges (not the invisible resize border) land on the given rectangle.
    public static void Place(IntPtr h, int x, int y, int w, int ht) {
        const uint NOZORDER_SHOW = 0x0004 | 0x0040;
        ShowWindow(h, 9); // SW_RESTORE
        SetWindowPos(h, IntPtr.Zero, x, y, w, ht, NOZORDER_SHOW);
        RECT outer, frame;
        GetWindowRect(h, out outer);
        if (DwmGetWindowAttribute(h, 9, out frame, Marshal.SizeOf(typeof(RECT))) == 0) {
            int l = frame.Left - outer.Left, t = frame.Top - outer.Top;
            int r = outer.Right - frame.Right, b = outer.Bottom - frame.Bottom;
            SetWindowPos(h, IntPtr.Zero, x - l, y - t, w + l + r, ht + t + b, NOZORDER_SHOW);
        }
    }

    public static RECT Rect(IntPtr h) { RECT r; GetWindowRect(h, out r); return r; }
}
'@
Add-Type -AssemblyName System.Windows.Forms

# Must run before any screen geometry is read, or scaled displays report the wrong size.
[void][SkyWin]::SetProcessDPIAware()

$config = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json
$windows = @($config.windows)
$override = $config.hosts.PSObject.Properties[$env:COMPUTERNAME.ToLower()]
if ($override) {
    $windows = @($override.Value.windows)
    Write-Log "Using windows override for $env:COMPUTERNAME"
}

$chrome = $config.chromePath
if (-not $chrome) {
    $chrome = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LocalAppData\Google\Chrome\Application\chrome.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $chrome) { throw 'Chrome not found' }

# Wait for the network so Lightspeed does not load as an error page on cold boot.
$probeHost = ([uri]($windows | Where-Object { $_.url -match '^https?://' } | Select-Object -First 1).url).Host
$deadline = (Get-Date).AddSeconds([int]$config.waitForNetworkSeconds)
while ($true) {
    try { [void][System.Net.Dns]::GetHostAddresses($probeHost); break } catch { }
    if ((Get-Date) -gt $deadline) { Write-Log "Network not ready after $($config.waitForNetworkSeconds)s, continuing anyway"; break }
    Start-Sleep -Seconds 2
}

foreach ($app in @($config.startApps)) {
    if (-not $app) { continue }
    try { Start-Process -FilePath $app; Write-Log "Started $app" } catch { Write-Log "Could not start ${app}: $_" }
}

$screens = [System.Windows.Forms.Screen]::AllScreens
$primary = [System.Windows.Forms.Screen]::PrimaryScreen
$secondary = $screens | Where-Object { -not $_.Primary } | Sort-Object { $_.Bounds.X } | Select-Object -First 1
Write-Log ("Screens: {0} (primary {1}x{2}{3})" -f $screens.Count, $primary.Bounds.Width, $primary.Bounds.Height,
    $(if ($secondary) { ", second $($secondary.Bounds.Width)x$($secondary.Bounds.Height)" } else { '' }))

function Get-ChromeHandles {
    $pids = @(Get-Process -Name chrome -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
    [SkyWin]::ChromeWindows() | Where-Object { $pids -contains [int]($_ -split ':')[1] } | ForEach-Object { [int64]($_ -split ':')[0] }
}

$claimed = @(Get-ChromeHandles)   # anything already open is left alone
if ($claimed.Count) { Write-Log "$($claimed.Count) Chrome window(s) already open, ignoring them" }

foreach ($w in $windows) {
    if (-not $w.url -or $w.url -match 'CHANGE-ME') { Write-Log "Skipping '$($w.name)': no URL set in config"; continue }

    $screen = if ($w.monitor -eq 'secondary') { $secondary } else { $primary }
    if (-not $screen) { Write-Log "Skipping '$($w.name)': needs a second monitor and none is connected"; continue }

    $chromeArgs = @($config.chromeArgs) + '--new-window' + $w.url
    Start-Process -FilePath $chrome -ArgumentList $chromeArgs
    Write-Log "Opened '$($w.name)' ($($w.url))"

    $handle = $null
    $limit = (Get-Date).AddSeconds([int]$config.windowTimeoutSeconds)
    while (-not $handle -and (Get-Date) -lt $limit) {
        Start-Sleep -Milliseconds 500
        $handle = Get-ChromeHandles | Where-Object { $claimed -notcontains $_ } | Select-Object -First 1
    }
    if (-not $handle) { Write-Log "No window appeared for '$($w.name)'"; continue }
    $claimed += $handle
    $h = [IntPtr]$handle

    $area = if ($w.position -eq 'fullscreen') { $screen.Bounds } else { $screen.WorkingArea }
    $half = [int][math]::Floor($area.Width / 2)
    switch ($w.position) {
        'left'       { [SkyWin]::Place($h, $area.X, $area.Y, $half, $area.Height) }
        'right'      { [SkyWin]::Place($h, $area.X + $half, $area.Y, $area.Width - $half, $area.Height) }
        'fullscreen' {
            # Land on the right monitor first, then F11 so Chrome fills it with no tabs or taskbar.
            [SkyWin]::Place($h, $area.X, $area.Y, $area.Width, $area.Height)
            $pidOfWindow = [int](([SkyWin]::ChromeWindows() | Where-Object { $_ -like "$handle`:*" }) -split ':')[1]
            [void](New-Object -ComObject WScript.Shell).AppActivate($pidOfWindow)
            Start-Sleep -Milliseconds 500
            [System.Windows.Forms.SendKeys]::SendWait('{F11}')
            Start-Sleep -Seconds 1
            $r = [SkyWin]::Rect($h)
            if ($r.Left -ne $area.X -or $r.Top -ne $area.Y -or ($r.Right - $r.Left) -ne $area.Width -or ($r.Bottom - $r.Top) -ne $area.Height) {
                Write-Log "Warning: '$($w.name)' may not be fullscreen (rect $($r.Left),$($r.Top) $($r.Right - $r.Left)x$($r.Bottom - $r.Top))"
            }
        }
        default      { Write-Log "Unknown position '$($w.position)' for '$($w.name)'" }
    }
    Write-Log "Placed '$($w.name)' $($w.position) on $(if ($screen -eq $primary) { 'primary' } else { 'second' }) monitor"
}

Write-Log 'Done'
