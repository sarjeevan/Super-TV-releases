# Installing Super TV: for AI assistants

Someone gave you this repo to put **Super TV** on their TV. Super TV (Android package `io.supertv`) is a home screen
for Google TV and Android TV; this repo holds its release APK and this guide, no code. You install it from the
computer with adb, and the person does the taps on the TV.

## Before you start

- You must run on a computer on the same Wi-Fi as the TV (a terminal on their own computer). A cloud sandbox can't
  reach the TV: if that's where you are, say so and stop.
- Don't run `install.sh`, `install.ps1` or `install.bat`: they're for people without an AI and ask their questions in
  a terminal you can't answer. Do the steps below yourself.
- The person may not be technical. Keep it short and friendly, one step at a time. Before each command that touches
  the TV, say what it will do. You can't see the TV: ask what it shows.

## Never

- Change anything on the TV except installing and opening Super TV: no picture, sound, network or account settings,
  no `pm disable-user`, `pm uninstall` or `pm clear` of other apps, no `cmd package set-home-activity`, no
  `settings put`. Turning Super TV's home screen on and off happens on the TV, in Super TV's settings: it turns
  things off and back on in a safe order and can undo it. (The only exception is *Uninstalled while its home screen
  was on?* below, with their OK.)
- Uninstall Super TV while its home screen is on: the apps it turned off would stay off. They switch to *Original*
  on the TV first.
- Install another APK than this repo's latest release: the TVs only take updates signed with the release key.

## Steps

1. **Ask** which TV it is (brand and model, or the streamer: Chromecast with Google TV, Google TV Streamer, onn 4K)
   and its IP address (on the TV: Settings → Network & Internet → their Wi-Fi network → IP address).
2. **USB debugging, on the TV:** Settings → System → About → move to *Android TV OS build* and press OK 7 times
   (older Android TVs: Settings → Device Preferences → About → Build). Then Settings → System → Developer options →
   *USB debugging* on.
3. **adb, on the computer:** `adb version` must say `Version 30` or newer (older ones can't `adb pair`). Otherwise
   install Google's platform-tools, only that: macOS `brew install --cask android-platform-tools`; Windows
   `winget install Google.PlatformTools` (then open a new terminal); anywhere, unzip
   `https://dl.google.com/android/repository/platform-tools-latest-<windows|darwin|linux>.zip` and use its `adb`.
4. **The APK:**
   `curl -fL -o SuperTV.apk https://github.com/sarjeevan/Super-TV-releases/releases/latest/download/SuperTV.apk`
   (in Windows PowerShell, `curl.exe`). What's in it: https://github.com/sarjeevan/Super-TV-releases/releases
5. **Connect.** Tell them first: the TV will ask *Allow USB debugging?*; tick *Always allow from this computer* →
   *Allow*. Then `adb connect <IP>:5555`, and repeat `adb -s <IP>:5555 get-state` every few seconds until it says
   `device` (`unauthorized`: still waiting for their *Allow*).
   - *Connection refused*: USB debugging is off, or it's a Chromecast with Google TV (or a TV) that doesn't open port
     5555 that way. Then: Developer options → *Wireless debugging* → on → *Pair device with pairing code*. They read
     you the address and the 6-digit code: `adb pair <address:port> <code>`. Then
     `adb connect <address:port shown on the Wireless debugging screen itself>` (another port), wait for `device`,
     `adb -s <that address:port> tcpip 5555`, wait 3 seconds, `adb connect <IP>:5555`. Tell them: Wireless debugging
     turns itself off at every restart of the TV, and until this runs again, Super TV can't switch or update.
   - macOS, *No route to host* while the TV answers (`nc -z <IP> 5555` connects): macOS's Local Network privacy
     blocks adb's background server. Run `adb kill-server; adb nodaemon server &` in the same terminal, or have them
     allow the terminal app in System Settings → Privacy & Security → Local Network.
6. **Look at the TV:** `adb -s <IP>:5555 shell getprop ro.product.manufacturer` (and `ro.product.model`,
   `ro.build.version.release`, `ro.build.version.sdk`). Super TV needs Android 8 (SDK 26) or newer.
   - Amazon Fire TV (Fire OS, including TVs with Fire OS built in) and the Kalley 43G200: Super TV installs, but its
     home screen can't be turned on there (the TV keeps its own). Tell them before installing.
7. **Install.** Tell them first: Google Play Protect may ask (*Risky app blocked*, "built for an older version of
   Android"): *More details* → *Install anyway*; updates don't ask again. Then
   `adb -s <IP>:5555 install -r SuperTV.apk`, which ends with `Success`. If it seems to hang, Play Protect is asking.
   - `INSTALL_FAILED_UPDATE_INCOMPATIBLE` (signatures don't match): a Super TV from another build is there. If its
     home screen is on, they switch to *Original* on the TV first (Super TV → About & reset → Original home screen);
     then, with their OK, `adb -s <IP>:5555 uninstall io.supertv` and install again.
   - `INSTALL_FAILED_VERSION_DOWNGRADE`: the TV already has a newer one. Nothing to do.
8. **TCL only:** TCL stops apps' background jobs by default, and Super TV's switch and safety net are background jobs:
   `adb -s <IP>:5555 shell "appops set io.supertv AUTO_START allow || appops set io.supertv APP_AUTO_START allow"`.
   Both answering *Unknown operation string* means this TV has nothing to allow.
9. **Say what the switch does,** before they make it: the home screen and the screensaver become Super TV's, and a
   short list of promo apps is turned off (never uninstalled); *Original* brings it all back. Picture, sound, network
   and accounts don't change. On Google TV, voice search results for films and shows come from Google's home screen,
   so they don't show while Super TV is on. On TCL, the remote's Netflix, YouTube and Prime buttons keep working
   through a small accessibility service that only reads those buttons. On Xiaomi TVs whose remote has no Home
   button, the Mi button opens Super TV.
10. **Open it and let go:** `adb -s <IP>:5555 shell am start -n io.supertv/.SettingsActivity`, then
    `adb disconnect <IP>:5555`. Disconnect before they switch: on Android 8 to 10 the TV can hand its next
    *Allow USB debugging?* answer to a computer that's still connected instead of to Super TV.
11. **They switch, on the TV:** *About & reset* → *Super TV home screen* → *Turn on*. The TV asks *Allow USB
    debugging?* once more, for Super TV itself: *Always allow* → *Allow*. Then first-time setup on the TV: their city
    (for the weather), their favourite apps and the set-top box's input. USB debugging must stay on: Super TV uses the
    TV's own adb to switch and to update itself.
    - If the switch stops and asks them to forget the Wi-Fi: that network was saved during the TV's first setup, and
      Android would delete it. They forget it and connect again in Settings → Network & Internet, then switch again.
      Networks saved then but out of range don't show there: `adb -s <IP>:5555 shell dumpsys wifi`, find the blocks
      with `cname=com.google.android.tungsten.setupwraith` (each starts with its `ID:`) and, with their OK,
      `adb -s <IP>:5555 shell cmd wifi forget-network <id>`.
12. **Check:** connect again; `adb -s <IP>:5555 logcat -d -s SuperTV` shows what the switch did (Hisense keeps only
    errors: `adb -s <IP>:5555 shell setprop log.tag.SuperTV I` first, then switch again). Then
    `adb disconnect <IP>:5555`.

## The test build (only when they ask for it)

Before a release, the person who makes Super TV tries it on their own TV as a test build: the `test` pre-release
here. Install it only when they ask for the test build, and only on the TV they name.

- The same steps, with the test APK in step 4:
  `curl -fL -o SuperTV.apk https://github.com/sarjeevan/Super-TV-releases/releases/download/test/SuperTV.apk`.
  If Super TV is already on, `adb install -r` replaces it in place, and it stays on: steps 9 to 11 are only for a
  TV that doesn't have it yet.
- Its version ends in `-test.<number>` (Super TV → Updates shows it). The TV never installs a test build by itself,
  and the next release replaces it overnight like on every other TV.
- To leave it before that release: an older version can't go over it. *Original* on the TV first, then
  `adb uninstall io.supertv` with their OK, and install the latest release (step 4's normal APK).

## Afterwards

- **Updates** come by themselves at night, with the TV in standby and nothing playing. Super TV → Updates →
  Check now checks at once.
- **Going back:** Super TV (in the TV's apps) → About & reset → Original home screen.
- **Removing:** *Original* first, then uninstall it in Settings → Apps (or `adb uninstall io.supertv`).
- **Uninstalled while its home screen was on?** The apps it turned off stay off. With their OK:
  `adb shell pm list packages -d` lists the disabled apps. `adb shell pm enable <package>` the TV's own home screen
  (`adb shell cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME`
  lists the candidates) and the apps they recognise, and Google's setup app (`com.google.android.tungsten.setupwraith`)
  last of all: with the home screen off and it on, its recovery screen takes Home. Then
  `adb shell cmd package set-home-activity <home activity>`, and if the screensaver doesn't come back,
  `adb shell settings put secure screensaver_components <the TV's screensaver>`.
