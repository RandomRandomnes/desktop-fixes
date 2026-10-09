# Changelog

## custom 2.210 (2026-10-09, fix)
- Login screen: apps in ~/.local/bin (Claude Code, Phoenix tools) are found again in the terminal after signing in

## custom 2.200 (2026-10-09, fix)
- PCs installed from the ISO: three shell files no longer stay behind with a .fixes-new copy (the installer had put this PC's home folder into example text); the next update replaces them and removes the stray copies

## custom 2.190 (2026-10-09, fix)
- Restart / Shut down: an optional personal step can run first (~/.config/phoenix/before-power, if you create it; at most 2 minutes), e.g. a backup or sync

## custom 2.180 (2026-10-09, fix)
- Restart and Shut down from the power menu no longer freeze or silently do nothing: they now run outside the shell, close Wallpaper Engine cleanly, never close the shell itself, log each step (journalctl -t phoenix-power) and show a message if the system refuses

## custom 2.170 (2026-10-09, fix)
- Critical update check: updates that can break the desktop (a new Qt or Hyprland version, Quickshell, graphics drivers) are pointed out before installing, with a notification and a list in Settings › Update; on the PC that publishes Phoenix the update asks first so they can be tried in the test VM
- Desktop check after every login and update and in Settings › Update: title bars missing, Hyprland config errors, the shell not running or built for an older Qt

## custom 2.160 (2026-10-09, fix)
- Setup assistant and Settings: the Wi-Fi page says when the PC has no Wi-Fi adapter (it kept scanning) and shows the cable connection
- Texts updated for the Phoenix-owned shell: the setup assistant's updates question says it also covers the shell; system fixes are for Arch, Hyprland or Quickshell updates
- phoenix status shows the shell as Phoenix's own

## custom 2.150 (2026-10-09, fix)
- Updates finish the clean-up of files Phoenix no longer ships also on PCs installed from the ISO (hypr-guard stayed there), and replace shell files a PC still has from an older illogical-impulse version

## custom 2.140 (2026-10-09, fix)
- The desktop shell now comes only with Phoenix updates: Phoenix ships its own complete, tested copy of the illogical-impulse shell and no longer follows illogical-impulse's updates
- hypr-guard is removed (it re-applied Phoenix's changes after illogical-impulse updates, which no longer happen); Settings › Update shows the shell under Phoenix updates, and Restore points undo a bad update
- Report a problem includes a direct desktop check (config errors, title bar plugin, shell errors, login log)
- The shell includes illogical-impulse's last update (media lyrics and searchable combo boxes)

## custom 2.130 (2026-10-09, fix)
- Maximized windows no longer bounce back when an app asks to be maximized twice
- Display profiles: settings left behind for a screen's old port are removed
- Lockout message works in any system language
- Restoring a restore point sets aside settings folders made after it
- Window rules: a width or height alone now works
- File choosers work without kdialog (zenity)
- Accounts shows Standard user for non-admin accounts
- Turning minimize off keeps your window transparency
- Locking the screen tells the system the session is locked
- Files added by updates are removed by phoenix uninstall

## custom 2.120 (2026-10-09, fix)
- Settings fits small screens for real now (header and back arrow below the taskbar) and always opens at Home
- No more 'Unlock Login Keyring' prompt at every start with automatic sign-in; signing in at the Phoenix login screen unlocks the keyring; password prompts always open in front
- Window-rule corners and the setup assistant keep title bars below the taskbar on small screens; windows restored from the dock come to the front
- Smaller fixes: Wi-Fi row on PCs without Wi-Fi, power mode shown when the active one isn't in the list, window-rule status messages, setup assistant reminder animation, no Hyprland update/donation screen at login

## custom 2.110 (2026-10-08, fix)
- Virtual machines: Phoenix no longer lets a VM go to sleep when idle (waking up froze its graphics and the VM had to be reset)

## custom 2.100 (2026-10-08, fix)
- Security: a window title or display-profile name can no longer put code into the Hyprland config (window rules, display profiles)
- Maximize: windows can be restored after Settings changes; a newly maximized window comes to the front; minimized windows moved out another way come back visible
- Several screens: a lone screen always uses workspaces 1-10; windows of an unplugged screen move to the remaining one; identical monitors no longer share settings; the vertical taskbar honours per-screen items
- Login screen: uses your keyboard layout; KDE choice from 'Switch to KDE' is kept; each user's own picture; your 12/24-hour clock; safer install/remove (keeps another login manager, no second-install mixups); an Update button when a newer version is ready; removed with Phoenix
- Restore points: settings-only changes can be undone; same-second changes are restored; damaged points give a clear message
- Updates: a second Undo no longer resets to version 0; fixes keep coming after undoing a major version; restored files aren't treated as your edits; files are never installed world-writable
- Game Mode no longer mistakes Accessibility's 'animations off' for itself; Do Not Disturb no longer flickers from screenshots or ends early with two screen shares
- Smaller fixes: window-rule on/off switch works, unread badge counts banner-less apps, problem reports hide more personal data, Settings window size on rotated screens, services no longer run twice while the setup assistant is open

## custom 2.9 (2026-10-08, fix)
- No more false "Desktop check: 1 problem" alert at startup: half-read window lists are simply asked for again

## custom 2.8 (2026-10-08, fix)
- Housekeeping: linux-wallpaper-engine is now a small launcher instead of a second copy of the Wallpaper Engine tray-icon fix

## custom 2.7 (2026-10-08, fix)
- Wallpaper Engine backgrounds drawn by the shell are found in any Steam library (Flatpak Steam, a library on another drive), not only in ~/.local/share/Steam

## custom 2.6 (2026-10-08, fix)
- Log out (power menu) exits Hyprland cleanly; it used to also kill the session launcher and helpers, and could leave a crash report from Wallpaper Engine

## custom 2.5 (2026-10-08, fix)
- Maximize works like Windows: a maximized window is now a normal window filling the screen, so the window you see on top always gets your clicks (before, a window over a maximized one could stop responding after you clicked the maximized one); a window brought up from the dock, Alt+Tab or the Overview comes to the front

## custom 2.4 (2026-10-08, fix)
- Settings opens at Phoenix's own pages again after the advanced (original) pages were used; the Settings window fits smaller screens (its back arrow was hidden on 1280×800)

## custom 2.3 (2026-10-08, fix)
- Setup assistant: the Account step now offers the login screen (Login screen at startup); turning it on there waits for any other terminal window of the assistant

## custom 2.2 (2026-10-08, fix)
- Login screen (Settings › Accounts › Login screen at startup): a Phoenix-style login screen instead of signing in automatically, with several users, Hyprland or KDE Plasma, and a clear message after too many wrong passwords
- Restore points (Settings › Update): one is saved before every update; 'Go back to this' undoes it
- Lock screen: Enter on the empty password field no longer counts as a wrong password; a lockout says how long to wait
- Night light can follow sunset and sunrise (Settings › System › Display)
- Notifications: turn them off per app, keep an app out of pop-up banners, optional notification sound (Settings › System › Notifications)
- Display profiles: save a monitor setup and Phoenix switches to it by itself when those displays are plugged in
- Several screens: each screen gets its own workspaces (1-10, 11-20, …) and its own taskbar items
- Your own login commands in ~/.config/hypr/custom/scripts/autostart-user.sh

## custom 3 (2026-10-08, feature)
- Restore points (Settings › Update): one is saved before every update with your desktop settings and package versions; 'Go back to this' undoes the update (old package versions are reinstalled after you confirm with your password)
- Lock screen: pressing Enter on the empty password field no longer counts as a wrong password (three of those locked the account for 10 minutes, even for the right password); a lockout now says how long to wait
- Your own login commands: put them in ~/.config/hypr/custom/scripts/autostart-user.sh and they run at every login (never replaced by updates)

## custom 2.1 (2026-10-08, fix)
- Windows over a maximized window stay clickable: after clicking the maximized window, the window on top of it no longer loses the mouse (you had to click it in the dock before)

## custom 2 (2026-10-08, feature)
- Window rules (Settings › Apps › Window rules): choose how an app's windows open: floating, size, position, workspace, monitor, opacity, maximized or fullscreen, no title bar
- What's new: after an update a notification and Settings › Update show what changed
- Report a problem (Settings › System): builds a bug report with your system details, personal data removed, and opens it as a GitHub issue
- Game Mode (Settings › Gaming) can turn on by itself in fullscreen games, and also stops Wallpaper Engine and picks the Best performance power mode
- Do not disturb while playing a fullscreen game or sharing your screen (on by default, can be switched off in Settings › Gaming)

## custom 1.191 (2026-10-08, fix)
- Other hardware: CPU temperature also from the zenpower driver and thermal zones (laptops, VMs), shown as n/a instead of 0 °C when there is no sensor; correct core count on multi-CPU systems; tidy Intel CPU names; no '0.00 GHz' maximum where the clock isn't reported
- Laptops: the Default profile shows the battery on the taskbar; PCs without a laptop battery hide it

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
