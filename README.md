# Phoenix

**A Windows-style desktop for Arch Linux**, built on a customized version of the
[illogical-impulse](https://github.com/end-4/dots-hyprland) Hyprland shell.

> **Phoenix is a custom version of illogical-impulse.** It is based on the illogical-impulse Hyprland configuration by
> end-4 and the [end4-pC](https://github.com/pctrade/end4-pC) fork, with changes and additions of its own. It is not
> the official illogical-impulse project and is not affiliated with or supported by its authors: please report
> problems with Phoenix here, not upstream.

## Features

- **Windows-style windows**: windows float, with a title bar (close, maximize, minimize to the dock); double-click
  the title bar to maximize. Can be switched back to tiling.
- **Taskbar and dock** from illogical-impulse, plus live **CPU / GPU / RAM graphs** with a details popup
  (AMD, NVIDIA with the proprietary driver, and Intel graphics).
- **Settings app** (`Super` + `I`) laid out like Windows Settings: System, Bluetooth & devices, Network,
  Personalization, Apps, Update and Extras, where every Phoenix feature has its own switch.
- **Setup assistant** at the first start: network, Bluetooth, time and region, keyboard, display, setup profile,
  colors, wallpaper, account, applications (with Gaming and Productivity packs), drivers and updates.
- **Setup profiles**: one file with an appearance and a set of features, to apply or to share.
- **App grid** in the `Super` menu, **Quick Start** guide, and an optional **Wallpaper Engine** background.
- **Self-repair after updates**: when illogical-impulse updates, Phoenix's changes are re-applied and checked;
  Settings › Update › *Run health check* reports anything that needs attention.
- **Signed updates** in two kinds (see [Updates](#updates)).

## KDE Plasma

Phoenix works alongside KDE Plasma: you can keep both desktops and switch between them at any time. Phoenix does not
install Plasma; install it first if you want it (for example `sudo pacman -S plasma-desktop`).

**From Phoenix to Plasma:**

- Settings › Extras › **Switch to KDE Plasma button** adds a button to the right sidebar's header.
- Settings › Extras › **"Switch to KDE" in the power menu** puts the same switch in the power menu (in place of
  Hibernate).
- Or in a terminal: `switch-desktop plasma`.

**From Plasma back to Phoenix:**

- The **Switch to Hyprland** entry in the Plasma start menu.
- The Phoenix launcher widget **Application Launcher (with Hyprland switch)**, which you can add to the Plasma panel
  in place of the standard one.
- Or in a terminal: `switch-desktop hyprland`.

Switching saves your choice and logs you out. On a system installed from a Phoenix image, which logs in
automatically, the chosen desktop then starts by itself. With a login screen (SDDM or similar), pick the session
there.

**In Plasma**, the Phoenix **System Update** widget can be added to the panel: it runs the same update as the
Phoenix update button (packages, system fixes, custom fixes); the illogical-impulse shell part runs the next time
you are in Phoenix. With Wallpaper Engine switched on, Plasma uses the Wallpaper Engine plugin for Plasma
(`wallpaper-engine-kde-plugin-git` from the AUR) with the same wallpaper. Phoenix's own settings apply only in
Phoenix; Plasma keeps its own.

## Requirements

- Arch Linux with Hyprland 0.55 or newer (the Lua configuration).
- [illogical-impulse](https://github.com/end-4/dots-hyprland). If it is not installed, the Phoenix installer offers to
  run its official installer first.
- An internet connection during installation.
- Optional: an AUR helper (`yay` or `paru`) for title bars (`hyprland-plugin-hyprbars`); Steam and Wallpaper Engine
  for animated wallpapers.

## Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/RandomRandomnes/phoenix/main/install.sh)
```

or clone this repository and run `./install.sh`. Run it as your normal user; it asks for the password when needed.

The installer explains each step and asks before changing anything:

1. Checks the system, and installs illogical-impulse with its official installer if it is missing.
2. Installs the few packages Phoenix uses (shown first).
3. Clones the end4-pC shell at the version Phoenix is tested with.
4. Installs the Phoenix files from the newest **signed** release (the installer checks the signature with the key
   it contains) and backs up every file they replace.
5. Asks whether to **switch to Phoenix now**, or to install it only and switch later.

After logging in to Phoenix, the setup assistant opens.

### Switching and removing

```bash
phoenix status        # installed? active? versions
phoenix activate      # use Phoenix
phoenix deactivate    # back to your own illogical-impulse setup
phoenix uninstall     # remove Phoenix and restore what it replaced
phoenix power-meter   # status of the CPU power meter (install | remove)
```

**CPU power** in the system stats comes from a small background service, the *CPU power meter*, which the installer
offers. The CPU's energy counter can only be read by root, on purpose: fast, precise readings allow a power
side-channel attack. The service runs as root, sandboxed, and publishes only a 1-second average rounded to 0.5 W.
Without it, CPU power shows "n/a".

Phoenix and illogical-impulse share two things: the Hyprland folder `~/.config/hypr/custom` and the shell settings
`~/.config/illogical-impulse/config.json`. Switching swaps these between your copy and Phoenix's copy (kept in
`~/.local/state/phoenix`); nothing is deleted. While Phoenix is switched off, its updates are paused.

## Updates

The update button on the taskbar (or Settings › Update) installs, in this order: system packages, the
illogical-impulse shell, **system fixes** and **custom fixes**.

| Kind | Tags | What it fixes | Installed |
|---|---|---|---|
| System fixes | `system-1`, `system-1.1`, … | Problems caused by updates to Arch, Hyprland or illogical-impulse | Always, right after the update it belongs to, and only on systems whose versions match |
| Custom fixes | `custom-1`, `custom-1.1`, … | Problems in Phoenix's own features (Settings, the setup assistant, Wallpaper Engine support, …) | When enabled in the setup assistant. A new whole number (2, 3, …) is a major version: only offered, never installed automatically |

Every release is signed and checked before anything is installed; a damaged release is rejected as a whole. A file
you edited yourself is never overwritten: the new version is saved next to it as `<file>.fixes-new`. The last custom
fix can be undone in Settings › Update. A system fix that has to change a Phoenix file carries a version of the change
for each range of Phoenix versions and is tested against all of them before release.

## Setup profiles

A setup profile is a JSON file that sets the appearance and the optional features. Profiles never change the apps
in the dock or the app grid, never switch on Wallpaper Engine, and never carry personal settings (name, location,
language, folders, update choices).

| Profile | Download |
|---|---|
| Default (built in): Windows-style, monochrome | – |
| Custom_01: live system graphs, the KDE switch, Claude Code, a customized taskbar and desktop widgets | [custom_01.json](https://github.com/RandomRandomnes/phoenix/raw/main/profiles/custom_01.json) |

Apply one in the setup assistant (**Your setup › Use a profile file…**), in Settings › Extras, or with
`setup-profile apply ~/Downloads/custom_01.json` (your current settings are backed up first). Settings › Extras ›
*Share my setup* saves your own.

## Privacy

Phoenix has no telemetry and no accounts. It connects only to:

- GitHub (this repository), to check for and download updates;
- the Arch Linux mirrors, the AUR and Flathub, when you install updates or applications.

illogical-impulse's own optional features (such as weather or the AI chat) work as they do in illogical-impulse.
Releases and exported profiles never contain personal files or settings.

## Known limitations

- **Boot menu choice** (setup assistant › Drivers and updates › Startup) is only offered on systems installed from a
  Phoenix image; on other systems your boot setup is left alone.
- GRUB can't be chosen while Secure Boot is on (it can't start the signed system without shim).
- GPU statistics need the proprietary NVIDIA driver; Intel usage is estimated from the GPU's idle time.
- Animated wallpapers need Steam and Wallpaper Engine (bought on Steam), and are off until switched on.
- Phoenix is tested mainly on AMD hardware and in virtual machines.

## Reporting problems

Open an [issue](https://github.com/RandomRandomnes/phoenix/issues) and include the output of:

```bash
phoenix status; custom-update status; hypr-guard doctor
```

and, if the desktop misbehaves, `~/hypr-guard/report.md`.

## Credits

- [illogical-impulse](https://github.com/end-4/dots-hyprland) by end-4 and contributors
- [end4-pC](https://github.com/pctrade/end4-pC) by pctrade
- [Hyprland](https://hyprland.org), [Quickshell](https://quickshell.outfoxxed.me), [Arch Linux](https://archlinux.org)
- [linux-wallpaperengine](https://github.com/Almamu/linux-wallpaperengine) for Wallpaper Engine support

## License

Phoenix is free software under the [GNU General Public License v3.0](LICENSE), the same license as illogical-impulse
and end4-pC. It contains modified versions of their files: `files/` holds the complete current set of Phoenix files,
and `CHANGELOG.md` lists the changes of every release.
