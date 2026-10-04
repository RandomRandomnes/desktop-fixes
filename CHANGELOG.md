# Changelog

## v1.115 (2026-10-04, minor)
- Upgrading to a new version without a terminal or without confirmation now explains what to do instead of crashing; a failed version check shows a readable error.

## v1.114 (2026-10-04, fix)
- A damaged or incomplete update is now rejected as a whole before any file is changed, instead of being half installed.

## v1.104 (2026-10-04, fix)
- Updates no longer overwrite files you edited yourself, including files that came with the installation: your version is kept and the new one is saved next to it as .fixes-new.

## v1.94 (2026-10-04, fix)
- Undo last now sticks: the undone fix is not reinstalled by the next update or by the login check; newer releases are offered as usual.

## v1.84 (2026-10-04, fix)
- Release numbers no longer roll over into a new major version: after 1.94 the next fix is 1.104, and only a feature release starts version 2.

## v1.74 (2026-10-04, fix)
- Applying a setup profile keeps the bug-fix update choice, display name, location, language, AI settings, folders and autostart programs.

## v1.64 (2026-10-04, fix)
- Share my setup no longer writes personal settings (name, picture, location, AI settings, folders, language, autostart programs, the update choice) or the login name into the profile file, and applying a profile ignores such settings.

## v1.54 (2026-10-04, minor)
- Changing colors or light/dark mode no longer produces "Local System Message Service" notifications full of color codes.

## v1.53 (2026-10-04, fix)
- The GPU widget supports NVIDIA (through nvidia-smi) and Intel graphics in addition to AMD; a dedicated card is preferred over integrated graphics, and a powered-down laptop GPU is not woken up.
- Quick Start guide and app rewritten: shorter, more precise, and updated for starting without a boot menu, setup profiles and Secure Boot without a TPM.

## v1.43 (2026-10-04, minor)
- The GPU widget shows the correct name after the graphics card is replaced.

## v1.42 (2026-10-04, fix)
- The original illogical-impulse welcome window is replaced by the setup assistant: a first start no longer opens it (or resets the wallpaper), and Shift+Super+Alt+/ opens the setup assistant.

## v1.32 (2026-10-04, fix)
- A setup profile's accent color is kept when its wallpaper is applied.

## v1.31 (2026-10-04, fix)
- Setup profiles no longer change the apps in the dock or the app grid, and never switch on Wallpaper Engine; Wallpaper Engine is off until it is enabled in Settings › Extras. Custom_01 moved to the project page as a download.

## v1.3 (2026-10-04, fix)
- Boot menu choice in the setup assistant and the boot-loader command; Quick Start guide updated.

## v1.26 (2026-10-04, fix)
- A new installation no longer shows a desktop-check alert at first login; the first snapshot is taken automatically. Neutral alert wording.

## v1.16 (2026-10-03, minor)
- Release history restarted under RandomRandomnes/desktop-fixes
- Formal, neutral wording throughout the setup assistant, Quick Start, Settings and the installer
- Includes the setup assistant, setup profiles, application catalog, Quick Start and the update channel
