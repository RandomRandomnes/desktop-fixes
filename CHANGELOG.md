# Changelog

## custom 1.181 (2026-10-08, fix)
- Setup assistant without internet: steps that need it show a no-connection icon, their buttons are greyed out with a note, and Next on Apps moves on instead of starting an install that would fail (rechecked every 5 s, so connecting in the Wi-Fi step enables them)
- Terminals opened by the setup assistant come up centered in front of it (they used to open behind it when a maximized window was on the workspace) and close by themselves a few seconds after a successful run; after an error they stay open
- Account: Change your password opens its own window in front; the Account step says the password is the one chosen during installation

## custom 1.171 (2026-10-08, fix)
- Resources hover popup keeps one size: fixed card widths (long values are shortened with …), fixed widths for the big values and the bottom row, and the GPU rows no longer vanish for a second when a reading is missed

## custom 1.161 (2026-10-08, fix)
- Bar resource widget keeps one size: each cell's detail text has a fixed width (longer values are cut with …), and the GPU cell no longer disappears for a second when a reading is missed

## custom 1.151 (2026-10-08, fix)
- boot-loader use: shows what changes and asks before changing how the computer starts (--yes skips it; the setup assistant confirms in its own window)
- Setup assistant › Startup: no more '—' when the firmware starts something else first; it offers the default and explains how to restore it

## custom 1.141 (2026-10-08, fix)
- Wallpaper Engine web wallpapers: the host program is no longer shipped compiled; Phoenix ships its source recipe (upstream commit + patch, GPL-2.0) and builds it on the PC when it is missing or stops working after a Qt update (F23)

## custom 1.131 (2026-10-08, minor)
- Tidying: comments no longer point to files that don't ship; the hypr-guard report addresses the reader; an unused import removed (F27)

## custom 1.130 (2026-10-08, fix)
- CPU power without opening the energy counter to every program: the optional CPU power meter (a sandboxed root service publishing a 1-second reading rounded to 0.5 W), offered by the installer; phoenix power-meter install|remove|status; the system stats use it (F21)

## custom 1.120 (2026-10-08, fix)
- System stats: /home is listed once when it shares the system partition; a 0 or invalid interval no longer loops or crashes (F20)
- CPU power: shows why it is missing ('n/a (root only)') instead of 0 W on PCs that can't read the counter (F21)
- Wallpaper Engine: workshop wallpapers and assets are found in any Steam library (other drives, Flatpak Steam); no crash without Steam or before the app first ran; the KDE switch handles folder names with spaces or quotes (F26)

## custom 1.110 (2026-10-08, fix)
- Settings › Update: 'Restart required' only when the running kernel was really upgraded, also with linux-lts or linux-zen (F19)
- Setup assistant: apps picked while a terminal window is still open are confirmed and installed after it (F18)
- Settings › Background › Recent images: only pictures in the wallpaper folder, no folder tiles or other folders (F17)
- kitty no longer reports 'Errors parsing configuration' when terminal colors aren't generated yet, and open terminals get no junk text then (F30)

## custom 1.100 (2026-10-08, fix)
- hypr-guard: snapshots, their pointer and the autostart log moved from the home folder into ~/hypr-guard (moved automatically); two snapshots in the same second no longer crash; update without an upstream branch changes nothing (F22); reapply-shell-patches.py is tracked (F29)
- Terminal colors work without the ii folder: applycolor.sh uses its own shell folder (F24)
- switch-desktop logs out with Hyprland's own exit instead of killing every process with "hyprland" in its name (F25)

## custom 1.9 (2026-10-08, fix)
- Setup profiles: names with capitals apply; clear messages instead of Python errors for damaged settings or profiles, a missing helper (checked before anything is written) or an unwritable export path; exports no longer always contain apps.volumeMixer, and ~/ paths stay ~/ (F13, F14, F28)
- Custom_01 profile: invalid and unused values removed (F16)

## custom 1.8 (2026-10-08, fix)
- Graphics drivers: only the graphics card counts (NVIDIA HDMI audio, Intel Wi-Fi or CPU parts no longer install drivers); older NVIDIA cards get the 580xx driver instead of nvidia-open, which doesn't support them (F12)

## custom 1.7 (2026-10-08, fix)
- Windows-style windows switched off: no more 'title bar plugin isn't loaded' alert and no Hyprland config error at login (F11)

## custom 1.6 (2026-10-08, fix)
- phoenix activate/deactivate/uninstall: the shell being switched away from (and the setup assistant) is closed; before, both shells ran until the next login

## custom 1.5 (2026-10-08, fix)
- Phoenix shell starts on new installs: illogical-impulse's variables.lua reset the shell to the stock one; Phoenix now sets it in custom/variables.lua
- hypr-guard tracks custom/variables.lua

## custom 1.4 (2026-10-08, fix)
- Phoenix follows the illogical-impulse shell update of 2026-10-07: the right sidebar's Phoenix parts (device batteries, Wallpaper Engine picker, Switch to KDE button) are rebuilt on the new reorderable sidebar.
- Each custom release now records the illogical-impulse shell version it was made on; it installs once the shell is updated (the update button does that first), and install.sh sets up exactly that version.
- GPU widget: full Intel GPU names; a powered-down laptop NVIDIA GPU is never woken, and the integrated GPU is shown while it sleeps.

## custom 1.3 (2026-10-04, fix)
- KDE Plasma integration ships with Phoenix: the start-menu entry and launcher widget for switching back to Hyprland, and the Phoenix update button for the Plasma panel.
- The boot menu option in the setup assistant only appears on systems with the Phoenix image's boot layout; other systems keep their own boot setup.
- The device battery widget has a demo mode for screenshots (~/.local/state/phoenix/battery-demo).

## custom 1.2 (2026-10-04, fix)
- Phoenix can be installed on an existing Arch + illogical-impulse system with install.sh, and switched with the new phoenix command (status, activate, deactivate, uninstall); fixes are not installed while Phoenix is switched off.

## custom 1.1 (2026-10-04, fix)
- The project is now called Phoenix: the setup assistant, Quick Start, Settings › System › About and the boot entries use the new name, and updates come from github.com/RandomRandomnes/phoenix.

## custom 1 (2026-10-04, initial)
- Release history restarted with two release lines: system fixes (always installed, matched to Arch, Hyprland and illogical-impulse versions) and custom fixes (optional).
- Includes every custom file, the new updater and the Quick Start guide.

The release history restarted on 2026-10-04 with two release lines: system fixes and custom fixes.
