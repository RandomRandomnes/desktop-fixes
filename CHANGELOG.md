# Changelog

## custom 1.4 (2026-10-08, fix)
- GPU widget: Intel GPUs show their full name (e.g. Intel Iris Xe Graphics); a powered-down laptop NVIDIA GPU is never woken to read names, and the integrated GPU is shown while it sleeps.

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
