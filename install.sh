#!/usr/bin/env bash
# Installs Super TV on a Google TV or Android TV on the same Wi-Fi as this computer (macOS or Linux):
#   bash <(curl -fsSL https://raw.githubusercontent.com/sarjeevan/Super-TV-releases/main/install.sh)
# It keeps what it downloads in ~/SuperTV: Android's adb from Google (only if this computer has none) and the latest
# SuperTV.apk. It changes nothing on the TV except installing Super TV (and, on TCL, letting it run in the background).
set -uo pipefail   # bash 3.2 too (macOS)

APK_URL="https://github.com/sarjeevan/Super-TV-releases/releases/latest/download/SuperTV.apk"
PKG=io.supertv
DIR="$HOME/SuperTV"

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
fail() { printf '\n\033[31m%s\033[0m\n' "$*" >&2; exit 1; }
# Asks on the terminal; at its end (Ctrl+D) the whole installer stops, not just this question
ask() {
    local a
    read -r -p "$1 " a < /dev/tty || { echo >&2; kill -TERM $$; exit 1; }
    printf '%s' "${a// /}"
}
# Asks until the answer matches the pattern (an extended regex)
ask_for() { local a=""; until [[ "$a" =~ $2 ]]; do a=$(ask "$1"); done; printf '%s' "$a"; }
ADDR='^[0-9]{1,3}(\.[0-9]{1,3}){3}:[0-9]+$'   # an IP address and a port
adb_() { "$ADB" "$@" 2>&1 | tr -d '\r'; }
reached() { [[ "$1" == *"connected to"* || "$1" == *"failed to authenticate"* ]]; }   # the TV answered

# Until the TV allows this computer, about 90 seconds at most
wait_device() {
    local d=$1 told=false s
    for _ in $(seq 1 45); do
        s=$(adb_ -s "$d" get-state)
        case "$s" in
            device) return 0 ;;
            *unauthorized*)
                $told || say 'On the TV: "Allow USB debugging?" → tick "Always allow from this computer" → Allow'
                told=true ;;
            *"not found"*|*offline*) adb_ connect "$d" > /dev/null ;;
        esac
        sleep 2
    done
    return 1
}

# Chromecast with Google TV and some newer TVs don't open port 5555 with USB debugging: pair with Wireless debugging,
# then open 5555 (Super TV uses it) with adb tcpip. It closes again when the TV restarts.
pair() {
    say "The TV didn't answer on port 5555."
    echo "Check that the TV is on, on the same Wi-Fi as this computer, and that USB debugging is on"
    echo "(Settings → System → Developer options). A Chromecast with Google TV and some newer TVs need"
    echo "Wireless debugging instead: Developer options → Wireless debugging → on → Pair device with pairing code."
    [[ "$(ask "Is the TV showing a pairing code now? (y/n)")" == [yY]* ]] || return 1
    local paddr code waddr out
    paddr=$(ask_for "The IP address & port under the code (like 192.168.1.20:37123):" "$ADDR")
    code=$(ask_for "The Wi-Fi pairing code (6 digits):" '^[0-9]{6}$')
    out=$(adb_ pair "$paddr" "$code"); echo "$out"
    [[ "$out" == *"Successfully paired"* ]] || return 1
    waddr=$(ask_for "Now the IP address & port on the Wireless debugging screen itself (not the pairing one):" "$ADDR")
    adb_ connect "$waddr" > /dev/null
    wait_device "$waddr" || return 1
    adb_ -s "$waddr" tcpip 5555 > /dev/null
    sleep 3
    adb_ disconnect "$waddr" > /dev/null
    out=$(adb_ connect "$dev"); echo "$out"
    reached "$out"
}

mkdir -p "$DIR" && cd "$DIR" || fail "Couldn't open the folder $DIR."

# adb: this computer's own if it's recent (platform-tools 30 or newer: older ones can't pair with a Chromecast), else
# Google's in ~/SuperTV
recent() { local re='Version ([0-9]+)\.' v; v=$("$1" version 2> /dev/null) && [[ "$v" =~ $re ]] && [ "${BASH_REMATCH[1]}" -ge 30 ]; }
ADB=""
OWN="$DIR/platform-tools/adb"
if command -v adb > /dev/null 2>&1 && recent adb; then
    ADB=adb
else
    if [ ! -x "$OWN" ]; then
        case "$(uname -s)" in
            Darwin) os=darwin ;;
            Linux) os=linux ;;
            *) fail "This installer is for macOS and Linux. On Windows, use install.ps1 (see the README)." ;;
        esac
        command -v unzip > /dev/null 2>&1 || fail "Please install unzip first (for example: sudo apt install unzip), then run this again."
        say "Downloading Android's adb from Google…"
        if curl -fL --progress-bar -o platform-tools.zip "https://dl.google.com/android/repository/platform-tools-latest-$os.zip"; then
            unzip -q -o platform-tools.zip; rm -f platform-tools.zip
        fi
    fi
    if "$OWN" version > /dev/null 2>&1; then
        ADB="$OWN"
    elif command -v adb > /dev/null 2>&1; then
        ADB=adb   # an older adb still installs (Google's doesn't run on every Linux, ARM for one)
    fi
fi
[ -n "$ADB" ] || fail "Couldn't get adb. Check the internet connection and run this again, or install adb (for example: sudo apt install adb)."

say "Downloading the latest Super TV…"
curl -fL --progress-bar -o SuperTV.apk.part "$APK_URL" && mv -f SuperTV.apk.part SuperTV.apk \
    || fail "Couldn't download Super TV. Check the internet connection and run this again."
[ "$(head -c 2 SuperTV.apk)" = "PK" ] || fail "The download isn't an app. Run this again in a minute."

ip=$(ask_for "The TV's IP address (on the TV: Settings → Network & Internet → your Wi-Fi), like 192.168.1.20:" \
    '^[0-9]{1,3}(\.[0-9]{1,3}){3}(:[0-9]+)?$')
ip=${ip%%:*}
dev="$ip:5555"

say "Connecting to the TV at $ip…"
out=$(adb_ connect "$dev"); echo "$out"
if [[ "$out" == *"No route to host"* && "$(uname -s)" == Darwin ]]; then
    # macOS's Local Network privacy blocks the adb server that adb starts in the background: start it from here
    adb_ kill-server > /dev/null
    "$ADB" nodaemon server > /dev/null 2>&1 &
    sleep 2
    out=$(adb_ connect "$dev"); echo "$out"
fi
reached "$out" || pair || fail "Couldn't reach the TV. Check the IP address and USB debugging, then run this again."
wait_device "$dev" || fail "The TV didn't allow this computer. Run this again and choose Allow on the TV."

prop() { adb_ -s "$dev" shell getprop "$1"; }
brand=$(prop ro.product.brand)
maker=$(prop ro.product.manufacturer)
sdk=$(prop ro.build.version.sdk)
say "Found the TV: $maker $(prop ro.product.model), Android $(prop ro.build.version.release)."
[[ "$sdk" =~ ^[0-9]+$ && "$sdk" -ge 26 ]] || fail "Super TV needs Android 8 or newer."

say "Installing Super TV…"
echo 'If the TV shows Google Play Protect ("Risky app blocked" or "Unsafe app blocked"): choose More details → Install anyway.'
out=$(adb_ -s "$dev" install -r SuperTV.apk); echo "$out"
case "$out" in
    *Success*) ;;
    *INSTALL_FAILED_VERSION_DOWNGRADE*) say "This TV already has a newer Super TV." ;;
    *INSTALL_FAILED_UPDATE_INCOMPATIBLE*|*"signatures do not match"*)
        fail "This TV has a Super TV from another build. On the TV: open Super TV → About & reset → Original home screen (if Super TV is on), then uninstall Super TV in Settings → Apps, and run this again." ;;
    *) fail "The install didn't go through (see above). Run this again; if Play Protect asks, choose More details → Install anyway." ;;
esac

# TCL's TclAppBoot stops apps' background jobs by default, and Super TV's switch and safety net are background jobs.
# Some firmware calls it APP_AUTO_START; some has neither, and both answer "Unknown operation string".
if printf '%s %s' "$brand" "$maker" | grep -qi tcl; then
    adb_ -s "$dev" shell "appops set $PKG AUTO_START allow || appops set $PKG APP_AUTO_START allow" > /dev/null
fi

adb_ -s "$dev" shell am start -n "$PKG/.SettingsActivity" > /dev/null
# Disconnect before the switch: on Android 8 to 10 the TV can hand its "Allow USB debugging?" answer to a computer
# that's still connected instead of to Super TV.
adb_ disconnect "$dev" > /dev/null

say "Super TV is installed and open on the TV."
cat << 'EOF'
To make it the TV's home screen, on the TV:
  1. About & reset → Super TV home screen → Turn on.
  2. The TV asks "Allow USB debugging?" once more, for Super TV itself: tick "Always allow" → Allow.
  3. First-time setup: your city, your favourite apps and the set-top box's input.
Keep USB debugging on: Super TV uses it to switch and to update itself.
To go back any time: Super TV → About & reset → Original home screen.
EOF
