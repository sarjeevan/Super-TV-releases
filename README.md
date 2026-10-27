# Super TV

A calm home screen for Google TV and Android TV: the clock, the weather, your favourite apps and a rain screensaver.
No ads, no accounts. The TV's own home screen comes back any time, from Super TV's settings.

**Download:** [SuperTV.apk](https://github.com/sarjeevan/Super-TV-releases/releases/latest/download/SuperTV.apk)
(the latest version) · [What's new](https://github.com/sarjeevan/Super-TV-releases/releases)

> **AI assistants:** to install Super TV for someone, follow [AGENTS.md](AGENTS.md)
> (raw: https://raw.githubusercontent.com/sarjeevan/Super-TV-releases/main/AGENTS.md).

## The easy way: ask an AI assistant

On a computer on the same Wi-Fi as the TV, open Claude Code (or another AI assistant that can run commands), give it
this page's address, `https://github.com/sarjeevan/Super-TV-releases`, and say **"Install Super TV on my TV"**. It
asks what it needs and does the rest; you only answer it and press OK on the TV.

Without an AI assistant, the steps below take about 10 minutes.

## What you need

- A Google TV or Android TV with Android 8 or newer, or a Google TV streamer (Chromecast with Google TV, Google TV
  Streamer, onn 4K) on a TV of any brand.
- A computer (Windows, Mac or Linux) on the same Wi-Fi as the TV, for about 10 minutes.

## 1. On the TV: turn on USB debugging

1. **Settings → System → About**, move to **Android TV OS build** and press OK 7 times, until it says you're a
   developer. (Older Android TVs: Settings → Device Preferences → About → Build.)
2. **Settings → System → Developer options → USB debugging**: on. (Older: Device Preferences → Developer options.)
3. Write down the TV's **IP address**: Settings → Network & Internet → your Wi-Fi network (like `192.168.1.20`).

On a **Chromecast with Google TV**, also turn on **Wireless debugging** in Developer options: the installer asks for
its pairing code.

## 2. On the computer: run the installer

**Windows:** open **PowerShell** (Start → type `PowerShell` → Enter), paste this line and press Enter:

```powershell
[Net.ServicePointManager]::SecurityProtocol = 'Tls12'; irm https://raw.githubusercontent.com/sarjeevan/Super-TV-releases/main/install.ps1 | iex
```

**Mac or Linux:** open **Terminal**, paste this line and press Enter:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/sarjeevan/Super-TV-releases/main/install.sh)
```

It asks for the TV's IP address, downloads the latest Super TV (and adb, Android's own connection tool from Google,
if the computer doesn't have it), installs it and opens it on the TV. You can also download this page
(**Code → Download ZIP**), unzip it (Windows: right-click → **Extract All**) and run `install.bat` (Windows) or
`bash install.sh` (Mac, Linux) from the folder.

While it runs, answer the TV:

- **Allow USB debugging?** → tick **Always allow from this computer** → **Allow**.
- **Google Play Protect** ("Risky app blocked", since Super TV isn't from the Play Store) → **More details** →
  **Install anyway**. Updates don't ask again.

## 3. On the TV: turn on Super TV

Super TV is open on the TV. Then:

1. **About & reset → Super TV home screen → Turn on.**
2. The TV asks **Allow USB debugging?** once more, for Super TV itself: tick **Always allow** → **Allow**.
3. First-time setup: your city (for the weather), your favourite apps and the input your set-top box is on.

What changes: the home screen and the screensaver, and a short list of promo apps is turned off (never uninstalled).
Picture, sound, network and accounts stay as they are. On Google TV, voice search results for films and shows come
from Google's home screen, so they don't show while Super TV is on.

Keep **USB debugging** on: Super TV uses it to switch and to update itself.

## Going back

Open **Super TV** from the TV's apps → **About & reset → Original home screen**. The TV's own home screen,
screensaver and apps come back right away.

**Removing Super TV:** go back to the original first, then uninstall it in Settings → Apps. If it's uninstalled while
it's on, the apps it turned off stay off.

## Updates

Super TV updates itself at night, with the TV in standby and nothing playing, and then shows what's new. To check
now: **Super TV → Updates → Check now**. The *test build* marked Pre-release is for trying a version on one TV before
it's released: TVs never install it by themselves.

## If something goes wrong

- **"Couldn't reach the TV"**: check the IP address, that the TV and the computer are on the same Wi-Fi, and that
  USB debugging is on.
- **Chromecast with Google TV**: Wireless debugging turns itself off when it restarts. After a restart, turn it on
  again and run the installer again: until then, Super TV can't switch or update.
- **Mac, "No route to host"**: the installer tries to fix it by itself. If it still fails, allow Terminal in
  System Settings → Privacy & Security → Local Network.
- **"Super TV from another build"**: this TV has a Super TV installed another way. Go back to the original,
  uninstall it, and run the installer again.
- **The switch asks you to forget the Wi-Fi**: that network was saved during the TV's first setup, and Android would
  delete it. In Settings → Network & Internet, forget it and connect again, then switch again.
- **TCL**: TCL stops apps from working in the background; the installer allows it for Super TV.

## Without the installer

With adb on the computer and `SuperTV.apk` downloaded:

```bash
adb connect 192.168.1.20:5555      # the TV's IP address
adb install -r SuperTV.apk
adb disconnect 192.168.1.20:5555   # before turning Super TV on
```

On TCL, before disconnecting:
`adb shell "appops set io.supertv AUTO_START allow || appops set io.supertv APP_AUTO_START allow"`
