# Phoenix

> **This is a custom version of illogical-impulse.** It is based on the
> [illogical-impulse](https://github.com/end-4/dots-hyprland) Hyprland configuration by end-4, with changes and
> additions of its own (Windows-style windows and taskbar, Settings app, setup assistant, setup profiles,
> Wallpaper Engine support, boot menu choice and more). It is not the official illogical-impulse project and is not
> affiliated with or supported by its authors; report problems with this version here, not upstream.

Fixes for the Hyprland + illogical-impulse desktop image, in two release lines. Installed systems receive them
through `custom-update` (the update button and Settings › Update). Every release is signed.

| Line | Tags | What it fixes | Installed |
|---|---|---|---|
| System fixes | `system-1`, `system-1.1`, … | Problems caused by updates to Arch, Hyprland or illogical-impulse | Always, with each update, right after the update it belongs to, and only on systems whose versions match |
| Custom fixes | `custom-1`, `custom-1.1`, … | Problems in the custom additions (hypr-guard, Wallpaper Engine, Settings, the setup assistant, …) | When enabled in the setup assistant; a new whole number (2, 3, …) is a major version that is only offered |

A system fix that has to change a custom file carries a version of the change for each range of custom versions, and
is checked against every published custom version before release; a system whose file doesn't fit any variant keeps
the file unchanged and is told to install the latest custom fixes. `files/` contains a readable copy of the latest
custom release.

## Setup profiles

A setup profile is a JSON file that sets the appearance and the optional features of the desktop. Profiles do not
change the apps in the dock or the app grid, and they never switch on Wallpaper Engine (Settings › Extras).

| Profile | Download |
|---|---|
| Custom_01: live system graphs, the KDE switch, Claude Code, a customized taskbar and desktop widgets | [custom_01.json](https://github.com/RandomRandomnes/phoenix/raw/main/profiles/custom_01.json) |

To use a profile: download it, then in the first-time setup choose **Your setup › Use a profile file…**, or run
`setup-profile apply ~/Downloads/custom_01.json` in a terminal (the current settings are backed up first).
