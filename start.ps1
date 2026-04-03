# ---------------------------------------------------------
#  RemoteApp Launcher
#  Run this from: remoteapp/
#  Usage: .\start.ps1
# ---------------------------------------------------------

$ErrorActionPreference = "Stop";

function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  ██████╗ ███████╗███╗   ███╗ ██████╗ ████████╗███████╗" -ForegroundColor DarkYellow
    Write-Host "  ██╔══██╗██╔════╝████╗ ████║██╔═══██╗╚══██╔══╝██╔════╝" -ForegroundColor DarkYellow
    Write-Host "  ██████╔╝█████╗  ██╔████╔██║██║   ██║   ██║   █████╗  " -ForegroundColor Yellow
    Write-Host "  ██╔══██╗██╔══╝  ██║╚██╔╝██║██║   ██║   ██║   ██╔══╝  " -ForegroundColor Yellow
    Write-Host "  ██║  ██║███████╗██║ ╚═╝ ██║╚██████╔╝   ██║   ███████╗" -ForegroundColor DarkYellow
    Write-Host "  ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝ ╚═════╝    ╚═╝   ╚══════╝" -ForegroundColor DarkYellow
    Write-Host ""
    Write-Host "  ---------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "   Connect. Control. Collaborate." -ForegroundColor Gray
    Write-Host "  ---------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
}

function Write-Step($msg) {
    Write-Host "  >> $msg" -ForegroundColor Cyan
}

function Write-Success($msg) {
    Write-Host "  OK $msg" -ForegroundColor Green
}

function Write-Warn($msg) {
    Write-Host "  !! $msg" -ForegroundColor Yellow
}

function Write-Err($msg) {
    Write-Host "  XX $msg" -ForegroundColor Red
}

function Write-Divider {
    Write-Host "  ---------------------------------------------------------" -ForegroundColor DarkGray
}

function Assert-Folder($path, $name) {
    if (-not (Test-Path $path)) {
        Write-Err "$name folder not found at: $path"
        Write-Host "  Make sure you are running this from the remoteapp/ root folder." -ForegroundColor DarkGray
        Write-Host ""
        pause
        exit 1
    }
}

# ---------------------------------------------------------
#  Main
# ---------------------------------------------------------

Write-Header

$root = $PSScriptRoot
$server = Join-Path $root "server"
$client = Join-Path $root "client"

Write-Step "Checking project structure..."
Assert-Folder $server "server"
Assert-Folder $client "client"
Write-Success "Project structure OK"
Write-Host ""

# ---------------------------------------------------------
#  Device Selection
# ---------------------------------------------------------

Write-Divider
Write-Host ""
Write-Host "  Where do you want to run the Flutter app?" -ForegroundColor White
Write-Host ""
Write-Host "   [1]  Chrome           (Web)"           -ForegroundColor Cyan
Write-Host "   [2]  Windows          (Desktop)"       -ForegroundColor Cyan
Write-Host "   [3]  Android Emulator"                 -ForegroundColor Cyan
Write-Host "   [4]  Android Device   (USB)"           -ForegroundColor Cyan
Write-Host "   [5]  iOS Simulator    (Mac only)"      -ForegroundColor DarkGray
Write-Host "   [6]  Linux            (Desktop)"       -ForegroundColor DarkGray
Write-Host "   [7]  Show all devices (pick manually)" -ForegroundColor Cyan
Write-Host "   [0]  Server only      (no Flutter)"    -ForegroundColor Gray
Write-Host ""
Write-Divider
Write-Host ""

$choice = Read-Host "  Enter your choice (0-7)"
Write-Host ""

$flutterTarget = ""
$runFlutter = $true

switch ($choice) {
    "1" {
        $flutterTarget = "chrome"
        Write-Success "Target: Chrome (Web)"
    }
    "2" {
        $flutterTarget = "windows"
        Write-Success "Target: Windows Desktop"
    }
    "3" {
        Write-Step "Looking for Android emulator..."
        $devices = flutter devices 2>&1 | Out-String
        if ($devices -match "(emulator-\d+)") {
            $flutterTarget = $Matches[1]
            Write-Success "Found emulator: $flutterTarget"
        }
        else {
            Write-Warn "No emulator detected. Start one in Android Studio first."
            $flutterTarget = "android"
        }
    }
    "4" {
        Write-Step "Looking for connected Android device..."
        $devices = flutter devices 2>&1 | Out-String
        if ($devices -match "([\w\d]+)\s+.*android") {
            $flutterTarget = $Matches[1]
            Write-Success "Found device: $flutterTarget"
        }
        else {
            Write-Warn "No Android device found. Enable USB Debugging and reconnect."
            $flutterTarget = "android"
        }
    }
    "5" {
        $flutterTarget = "ios"
        Write-Warn "iOS only works on macOS with Xcode installed."
    }
    "6" {
        $flutterTarget = "linux"
        Write-Warn "Linux desktop target selected."
    }
    "7" {
        Write-Step "Fetching connected devices..."
        Write-Host ""
        flutter devices
        Write-Host ""
        $flutterTarget = Read-Host "  Paste the device ID from the list above"
        Write-Success "Target: $flutterTarget"
    }
    "0" {
        $runFlutter = $false
        Write-Warn "Running server only. Flutter will not start."
    }
    default {
        Write-Warn "Invalid choice. Defaulting to Chrome."
        $flutterTarget = "chrome"
    }
}

Write-Host ""

# ---------------------------------------------------------
#  Flutter Mode
# ---------------------------------------------------------

$flutterMode = "--debug"

if ($runFlutter) {
    Write-Divider
    Write-Host ""
    Write-Host "  Flutter run mode?" -ForegroundColor White
    Write-Host ""
    Write-Host "   [1]  Debug   (hot reload, default)" -ForegroundColor Cyan
    Write-Host "   [2]  Profile (performance testing)" -ForegroundColor Cyan
    Write-Host "   [3]  Release (fastest, no debug)"   -ForegroundColor Cyan
    Write-Host ""

    $modeChoice = Read-Host "  Enter choice (default: 1)"

    switch ($modeChoice) {
        "2" { $flutterMode = "--profile"; Write-Success "Mode: Profile" }
        "3" { $flutterMode = "--release"; Write-Success "Mode: Release" }
        default { $flutterMode = "--debug"; Write-Success "Mode: Debug (hot reload enabled)" }
    }

    Write-Host ""
}

# ---------------------------------------------------------
#  Launch Server
# ---------------------------------------------------------

Write-Divider
Write-Host ""
Write-Step "Starting backend server..."

$serverCmd = "cd '$server'; Write-Host ''; Write-Host '  [RemoteApp Server]' -ForegroundColor Yellow; Write-Host ''; npm run dev; pause"
Start-Process powershell -ArgumentList "-NoExit", "-Command", $serverCmd -WindowStyle Normal

Write-Success "Server window opened"
Write-Host ""

Write-Step "Waiting for server to boot..."
Start-Sleep -Seconds 3
Write-Success "Server should be live at http://localhost:5000"
Write-Host ""

# ---------------------------------------------------------
#  Launch Flutter
# ---------------------------------------------------------

if ($runFlutter) {
    Write-Step "Starting Flutter on: $flutterTarget ..."

    $flutterCmd = "-NoExit", "-Command", "Set-Location '$client'; Write-Host '  [RemoteApp Flutter]' -ForegroundColor Cyan; flutter run -d $flutterTarget $flutterMode; pause"
    Start-Process powershell -ArgumentList $flutterCmd -WindowStyle Normal

    Write-Success "Flutter window opened"
    Write-Host ""
}

# ---------------------------------------------------------
#  Summary
# ---------------------------------------------------------

Write-Divider
Write-Host ""
Write-Host "  RemoteApp is starting up!" -ForegroundColor Green
Write-Host ""
Write-Host "   Server  ->  http://localhost:5000"  -ForegroundColor Yellow

if ($runFlutter) {
    Write-Host "   Client  ->  $flutterTarget  ($flutterMode)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  Two terminal windows have opened for logs." -ForegroundColor Gray
Write-Host ""
Write-Host "  Flutter shortcuts (in Flutter window):" -ForegroundColor DarkGray
Write-Host "   r  -> Hot reload"   -ForegroundColor DarkGray
Write-Host "   R  -> Hot restart"  -ForegroundColor DarkGray
Write-Host "   q  -> Quit"         -ForegroundColor DarkGray
Write-Host ""
Write-Divider
Write-Host ""