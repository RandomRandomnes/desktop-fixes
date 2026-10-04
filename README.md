# Desktop fixes

> **This is a custom version of illogical-impulse.** It is based on the
> [illogical-impulse](https://github.com/end-4/dots-hyprland) Hyprland configuration by end-4, with changes and
> additions of its own (Windows-style windows and taskbar, Settings app, setup assistant, setup profiles,
> Wallpaper Engine support, boot menu choice and more). It is not the official illogical-impulse project and is not
> affiliated with or supported by its authors; report problems with this version here, not upstream.

Bug fixes for the Hyprland + illogical-impulse desktop image. Installed systems receive them through `custom-update` (Settings › Update) when enabled during the first-time setup. Releases are signed; `files/` contains a readable copy of the latest release.

## Setup profiles

A setup profile is a JSON file that sets the appearance and the optional features of the desktop. Profiles do not
change the apps in the dock or the app grid, and they never switch on Wallpaper Engine (Settings › Extras).

| Profile | Download |
|---|---|
| Custom_01: live system graphs, the KDE switch, Claude Code, a customized taskbar and desktop widgets | [custom_01.json](https://github.com/RandomRandomnes/desktop-fixes/raw/main/profiles/custom_01.json) |

To use a profile: download it, then in the first-time setup choose **Your setup › Use a profile file…**, or run
`setup-profile apply ~/Downloads/custom_01.json` in a terminal (the current settings are backed up first).
