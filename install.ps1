# Installs Super TV on a Google TV or Android TV on the same Wi-Fi as this computer (Windows 10 and 11).
#   In PowerShell:  irm https://raw.githubusercontent.com/sarjeevan/Super-TV-releases/main/install.ps1 | iex
#   or double-click install.bat next to this file.
# It keeps what it downloads in %LOCALAPPDATA%\SuperTV: Android's adb from Google (only if this computer has none) and
# the latest SuperTV.apk. It changes nothing on the TV except installing Super TV (and, on TCL, letting it run in the
# background). Plain ASCII on purpose: Windows PowerShell 5.1 reads a file without a BOM in the local code page.
& {
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is very slow with its progress bar in PowerShell 5.1
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$ApkUrl = 'https://github.com/sarjeevan/Super-TV-releases/releases/latest/download/SuperTV.apk'
$Pkg = 'io.supertv'
$Dir = Join-Path $env:LOCALAPPDATA 'SuperTV'

function Say($text) { Write-Host ''; Write-Host $text -ForegroundColor Cyan }
function Fail($text) { throw $text }   # caught at the bottom, so the window stays open with the message

# A line of a native program's output; stderr lines come as error records, whose text is their message
function Text($line) { if ($line -is [Management.Automation.ErrorRecord]) { $line.Exception.Message } else { "$line" } }

# adb's output, stdout and stderr together, as one string (stderr lines aren't errors here). Not "Get-Command adb":
# that finds this function.
function Adb {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $lines = & $AdbExe @args 2>&1 | ForEach-Object { Text $_ } } finally { $ErrorActionPreference = $old }
    (($lines -join "`n") -replace "`r", '').Trim()
}

function Ask($prompt, $pattern) {
    do { $a = (Read-Host $prompt) -replace '\s', '' } until ($a -match $pattern)
    $a
}

function Reached($out) { ($out -match 'connected to') -or ($out -match 'failed to authenticate') }   # the TV answered

# Until the TV allows this computer, about 90 seconds at most
function WaitDevice($d) {
    $told = $false
    for ($i = 0; $i -lt 45; $i++) {
        $s = Adb -s $d get-state
        if ($s -eq 'device') { return $true }
        if (($s -match 'unauthorized') -and -not $told) {
            Say 'On the TV: "Allow USB debugging?" -> tick "Always allow from this computer" -> Allow'
            $told = $true
        }
        if ($s -match 'not found|offline') { Adb connect $d | Out-Null }
        Start-Sleep -Seconds 2
    }
    return $false
}

# Chromecast with Google TV and some newer TVs don't open port 5555 with USB debugging: pair with Wireless debugging,
# then open 5555 (Super TV uses it) with adb tcpip. It closes again when the TV restarts.
function Pair {
    Say "The TV didn't answer on port 5555."
    Write-Host 'Check that the TV is on, on the same Wi-Fi as this computer, and that USB debugging is on'
    Write-Host '(Settings -> System -> Developer options). A Chromecast with Google TV and some newer TVs need'
    Write-Host 'Wireless debugging instead: Developer options -> Wireless debugging -> on -> Pair device with pairing code.'
    if ((Read-Host 'Is the TV showing a pairing code now? (y/n)') -notmatch '^[yY]') { return $false }
    $paddr = Ask 'The IP address & port under the code (like 192.168.1.20:37123)' '^\d{1,3}(\.\d{1,3}){3}:\d+$'
    $code = Ask 'The Wi-Fi pairing code (6 digits)' '^\d{6}$'
    $out = Adb pair $paddr $code
    Write-Host $out
    if ($out -notmatch 'Successfully paired') { return $false }
    $waddr = Ask 'Now the IP address & port on the Wireless debugging screen itself (not the pairing one)' '^\d{1,3}(\.\d{1,3}){3}:\d+$'
    Adb connect $waddr | Out-Null
    if (-not (WaitDevice $waddr)) { return $false }
    Adb -s $waddr tcpip 5555 | Out-Null
    Start-Sleep -Seconds 3
    Adb disconnect $waddr | Out-Null
    $out = Adb connect $dev
    Write-Host $out
    return (Reached $out)
}

try {
    New-Item -ItemType Directory -Force -Path $Dir | Out-Null

    # adb: this computer's own if it's recent (platform-tools 30 or newer: older ones can't pair with a Chromecast),
    # else Google's in %LOCALAPPDATA%\SuperTV
    $found = Get-Command adb.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $own = Join-Path $Dir 'platform-tools\adb.exe'
    $AdbExe = $null
    if ($found) {
        $AdbExe = $found.Path
        $v = Adb version
        if ($v -match 'Version (\d+)\.') {
            if ([int]$Matches[1] -lt 30) { $AdbExe = $null }
        } else { $AdbExe = $null }
    }
    if (-not $AdbExe) {
        if (-not (Test-Path $own)) {
            Say "Downloading Android's adb from Google..."
            $zip = Join-Path $Dir 'platform-tools.zip'
            try {
                Invoke-WebRequest -UseBasicParsing -Uri 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip' -OutFile $zip
                Expand-Archive -Path $zip -DestinationPath $Dir -Force
                Remove-Item $zip -Force
            } catch {
                if (-not $found) { Fail "Couldn't download adb. Check the internet connection and run this again." }
            }
        }
        if (Test-Path $own) { $AdbExe = $own } else { $AdbExe = $found.Path }   # an older adb still installs
    }
    if ((Adb version) -notmatch 'Android Debug Bridge') { Fail "adb doesn't run on this computer." }

    Say 'Downloading the latest Super TV...'
    $apk = Join-Path $Dir 'SuperTV.apk'
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $ApkUrl -OutFile "$apk.part"
        Move-Item -Force "$apk.part" $apk
    } catch { Fail "Couldn't download Super TV. Check the internet connection and run this again." }
    $f = [IO.File]::OpenRead($apk)
    try { $isZip = ($f.ReadByte() -eq 0x50) -and ($f.ReadByte() -eq 0x4B) } finally { $f.Close() }
    if (-not $isZip) { Fail "The download isn't an app. Run this again in a minute." }

    $ip = Ask "The TV's IP address (on the TV: Settings -> Network & Internet -> your Wi-Fi), like 192.168.1.20" '^\d{1,3}(\.\d{1,3}){3}(:\d+)?$'
    $ip = ($ip -split ':')[0]
    $dev = "${ip}:5555"

    Say "Connecting to the TV at $ip..."
    $out = Adb connect $dev
    Write-Host $out
    if (-not (Reached $out)) {
        if (-not (Pair)) { Fail "Couldn't reach the TV. Check the IP address and USB debugging, then run this again." }
    }
    if (-not (WaitDevice $dev)) { Fail "The TV didn't allow this computer. Run this again and choose Allow on the TV." }

    $brand = Adb -s $dev shell getprop ro.product.brand
    $maker = Adb -s $dev shell getprop ro.product.manufacturer
    $model = Adb -s $dev shell getprop ro.product.model
    $release = Adb -s $dev shell getprop ro.build.version.release
    $sdk = (Adb -s $dev shell getprop ro.build.version.sdk) -as [int]
    Say "Found the TV: $maker $model, Android $release."
    if (-not $sdk -or $sdk -lt 26) { Fail 'Super TV needs Android 8 or newer.' }

    Say 'Installing Super TV...'
    Write-Host 'If the TV shows Google Play Protect ("Risky app blocked" or "Unsafe app blocked"): choose More details -> Install anyway.'
    $out = Adb -s $dev install -r $apk
    Write-Host $out
    if ($out -match 'INSTALL_FAILED_VERSION_DOWNGRADE') {
        Say 'This TV already has a newer Super TV.'
    } elseif (($out -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE') -or ($out -match 'signatures do not match')) {
        Fail 'This TV has a Super TV from another build. On the TV: open Super TV -> About & reset -> Original home screen (if Super TV is on), then uninstall Super TV in Settings -> Apps, and run this again.'
    } elseif ($out -notmatch 'Success') {
        Fail "The install didn't go through (see above). Run this again; if Play Protect asks, choose More details -> Install anyway."
    }

    # TCL's TclAppBoot stops apps' background jobs by default, and Super TV's switch and safety net are background
    # jobs. Some firmware calls it APP_AUTO_START; some has neither, and both answer "Unknown operation string".
    if ("$brand $maker" -match 'tcl') {
        Adb -s $dev shell "appops set $Pkg AUTO_START allow || appops set $Pkg APP_AUTO_START allow" | Out-Null
    }

    Adb -s $dev shell am start -n "$Pkg/.SettingsActivity" | Out-Null
    # Disconnect before the switch: on Android 8 to 10 the TV can hand its "Allow USB debugging?" answer to a computer
    # that's still connected instead of to Super TV.
    Adb disconnect $dev | Out-Null

    Say 'Super TV is installed and open on the TV.'
    Write-Host 'To make it the TV''s home screen, on the TV:'
    Write-Host '  1. About & reset -> Super TV home screen -> Turn on.'
    Write-Host '  2. The TV asks "Allow USB debugging?" once more, for Super TV itself: tick "Always allow" -> Allow.'
    Write-Host '  3. First-time setup: your city, your favourite apps and the set-top box''s input.'
    Write-Host 'Keep USB debugging on: Super TV uses it to switch and to update itself.'
    Write-Host 'To go back any time: Super TV -> About & reset -> Original home screen.'
} catch {
    Write-Host ''
    Write-Host $_.Exception.Message -ForegroundColor Red
}
}
