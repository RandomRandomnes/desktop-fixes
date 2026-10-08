# Changelog

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
