# RemoteApp Launcher
# Run from: remoteapp\
# Usage: .\start.ps1

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  ==========================================================" -ForegroundColor DarkYellow
    Write-Host "   REMOTEAPP LAUNCHER" -ForegroundColor Yellow
    Write-Host "   Connect. Control. Collaborate." -ForegroundColor DarkYellow
    Write-Host "  ==========================================================" -ForegroundColor DarkYellow
    Write-Host ""
}

function Write-Step   { param($m); Write-Host "  >> $m" -ForegroundColor Cyan }
function Write-Ok     { param($m); Write-Host "  OK $m" -ForegroundColor Green }
function Write-Warn   { param($m); Write-Host "  !! $m" -ForegroundColor Yellow }
function Write-Err    { param($m); Write-Host "  XX $m" -ForegroundColor Red }
function Write-Div    { Write-Host "  ----------------------------------------------------------" -ForegroundColor DarkGray }

function Assert-Dir {
    param($path, $name)
    if (-not (Test-Path $path)) {
        Write-Err "$name not found at: $path"
        Write-Host "  Run this script from the remoteapp root folder." -ForegroundColor DarkGray
        pause; exit 1
    }
}

# ── Paths ──────────────────────────────────────────────────────────────────────
Write-Header

$root   = $PSScriptRoot
$server = Join-Path $root "server"
$client = Join-Path $root "client"

Write-Step "Checking project folders..."
Assert-Dir $server "server"
Assert-Dir $client "client"
Write-Ok "Folders OK"
Write-Host ""

# ── List connected devices ────────────────────────────────────────────────────
Write-Step "Scanning Flutter devices..."
$rawDevices = flutter devices 2>&1 | Out-String
Write-Host ""

# ── Device selection (supports MULTIPLE targets) ──────────────────────────────
Write-Div
Write-Host ""
Write-Host "  Run on which platform(s)?" -ForegroundColor White
Write-Host "  You can run on MULTIPLE devices at the same time." -ForegroundColor DarkGray
Write-Host ""
Write-Host "   [1]  Chrome (Web)"                      -ForegroundColor Cyan
Write-Host "   [2]  Windows Desktop"                   -ForegroundColor Cyan
Write-Host "   [3]  Android Emulator"                  -ForegroundColor Cyan
Write-Host "   [4]  Android Device (USB)"              -ForegroundColor Cyan
Write-Host "   [5]  Chrome + Android Emulator"         -ForegroundColor Cyan
Write-Host "   [6]  Chrome + Android Device (USB)"     -ForegroundColor Cyan
Write-Host "   [7]  Windows + Android Emulator"        -ForegroundColor Cyan
Write-Host "   [8]  Windows + Android Device (USB)"    -ForegroundColor Cyan
Write-Host "   [9]  Show all devices and pick manually" -ForegroundColor Cyan
Write-Host "   [0]  Server only (no Flutter)"          -ForegroundColor Gray
Write-Host ""
Write-Div
Write-Host ""

$choice = Read-Host "  Choice (0-9)"
Write-Host ""

# List of [target, label] pairs to launch
$targets    = @()
$runFlutter = $true

function Get-EmulatorId {
    $d = flutter devices 2>&1 | Out-String
    if ($d -match "emulator-(\d+)") { return "emulator-$($Matches[1])" }
    return "android"
}

function Get-AndroidDeviceId {
    $lines = flutter devices 2>&1
    foreach ($line in $lines) {
        if ($line -match "android" -and $line -match "([A-Za-z0-9]+)\s+") {
            $id = $Matches[1]
            if ($id -ne "android") { return $id }
        }
    }
    return "android"
}

switch ($choice) {
    "1" { $targets += @{id="chrome";  label="Chrome"} }
    "2" { $targets += @{id="windows"; label="Windows"} }
    "3" {
        Write-Step "Finding emulator..."
        $eid = Get-EmulatorId
        $targets += @{id=$eid; label="Android Emulator"}
        Write-Ok "Emulator: $eid"
    }
    "4" {
        Write-Step "Finding Android device..."
        $did = Get-AndroidDeviceId
        $targets += @{id=$did; label="Android Device"}
        Write-Ok "Device: $did"
    }
    "5" {
        Write-Step "Finding emulator..."
        $eid = Get-EmulatorId
        $targets += @{id="chrome"; label="Chrome"}
        $targets += @{id=$eid;     label="Android Emulator"}
        Write-Ok "Chrome + $eid"
    }
    "6" {
        Write-Step "Finding Android device..."
        $did = Get-AndroidDeviceId
        $targets += @{id="chrome"; label="Chrome"}
        $targets += @{id=$did;     label="Android Device"}
        Write-Ok "Chrome + $did"
    }
    "7" {
        Write-Step "Finding emulator..."
        $eid = Get-EmulatorId
        $targets += @{id="windows"; label="Windows"}
        $targets += @{id=$eid;      label="Android Emulator"}
        Write-Ok "Windows + $eid"
    }
    "8" {
        Write-Step "Finding Android device..."
        $did = Get-AndroidDeviceId
        $targets += @{id="windows"; label="Windows"}
        $targets += @{id=$did;      label="Android Device"}
        Write-Ok "Windows + $did"
    }
    "9" {
        Write-Host ""
        flutter devices
        Write-Host ""
        $manual = Read-Host "  Paste device ID(s) separated by comma (e.g. chrome,RZ8M704NSMJ)"
        $ids = $manual -split "," | ForEach-Object { $_.Trim() }
        foreach ($id in $ids) {
            $targets += @{id=$id; label=$id}
        }
        Write-Ok "Targets: $($ids -join ', ')"
    }
    "0" {
        $runFlutter = $false
        Write-Warn "Server only mode."
    }
    default {
        Write-Warn "Invalid choice. Defaulting to Chrome."
        $targets += @{id="chrome"; label="Chrome"}
    }
}

Write-Host ""

# ── Flutter mode ──────────────────────────────────────────────────────────────
$flutterMode = "--debug"

if ($runFlutter) {
    Write-Div
    Write-Host ""
    Write-Host "  Flutter run mode?" -ForegroundColor White
    Write-Host ""
    Write-Host "   [1]  Debug   (hot reload, recommended)" -ForegroundColor Cyan
    Write-Host "   [2]  Profile (performance testing)"     -ForegroundColor Cyan
    Write-Host "   [3]  Release (fastest, no debug)"       -ForegroundColor Cyan
    Write-Host ""

    $modeChoice = Read-Host "  Choice (default 1)"
    switch ($modeChoice) {
        "2" { $flutterMode = "--profile"; Write-Ok "Mode: Profile" }
        "3" { $flutterMode = "--release"; Write-Ok "Mode: Release" }
        default { $flutterMode = "--debug"; Write-Ok "Mode: Debug (hot reload on)" }
    }
    Write-Host ""
}

# ── Android IP warning ────────────────────────────────────────────────────────
$hasAndroid = $targets | Where-Object { $_.id -like "android*" -or ($_.id -match "^[A-Z0-9]{8,}$") }
if ($hasAndroid) {
    Write-Div
    Write-Host ""
    Write-Warn "Android detected. Make sure api_service.dart uses your PC IP."
    Write-Warn "Android cannot use localhost:5000 -- use http://YOUR_PC_IP:5000"
    Write-Host ""
    $myIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" -and $_.IPAddress -notlike "169.*" } | Select-Object -First 1).IPAddress
    if ($myIP) {
        Write-Host "  Your PC IP is: $myIP" -ForegroundColor Green
        Write-Host "  Use http://${myIP}:5000/api in api_service.dart for Android" -ForegroundColor Green
    }
    Write-Host ""
}

# ── Launch server ─────────────────────────────────────────────────────────────
Write-Div
Write-Host ""
Write-Step "Starting backend server..."

$sCmd = "Set-Location '$server'; Write-Host ''; Write-Host '[RemoteApp Server]' -ForegroundColor Yellow; Write-Host ''; npm run dev; pause"
Start-Process powershell -ArgumentList "-NoExit", "-Command", $sCmd -WindowStyle Normal

Write-Ok "Server window launched"
Write-Host ""
Write-Step "Waiting for server to initialize..."
Start-Sleep -Seconds 3
Write-Ok "Server live at http://localhost:5000"
Write-Host ""

# ── Launch Flutter for each target ────────────────────────────────────────────
if ($runFlutter) {
    foreach ($t in $targets) {
        $tid   = $t.id
        $tlabel = $t.label

        Write-Step "Launching Flutter on: $tlabel ($tid)..."

        $fCmd = "Set-Location '$client'; Write-Host ''; Write-Host '[RemoteApp Flutter - $tlabel]' -ForegroundColor Cyan; Write-Host ''; flutter run -d $tid $flutterMode; pause"
        Start-Process powershell -ArgumentList "-NoExit", "-Command", $fCmd -WindowStyle Normal

        Write-Ok "$tlabel window launched"

        # Stagger launches so they don't conflict
        if ($targets.Count -gt 1) {
            Write-Step "Waiting 5s before next launch..."
            Start-Sleep -Seconds 5
        }
    }
    Write-Host ""
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Div
Write-Host ""
Write-Host "  RemoteApp is running!" -ForegroundColor Green
Write-Host ""
Write-Host "  Server  ->  http://localhost:5000" -ForegroundColor Yellow

if ($runFlutter) {
    foreach ($t in $targets) {
        Write-Host "  Client  ->  $($t.label) [$($t.id)]" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "  Each platform opened in its own terminal window." -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Flutter shortcuts (in each Flutter window):" -ForegroundColor DarkGray
Write-Host "   r   Hot reload" -ForegroundColor DarkGray
Write-Host "   R   Hot restart" -ForegroundColor DarkGray
Write-Host "   q   Quit" -ForegroundColor DarkGray
Write-Host ""
Write-Div
Write-Host ""