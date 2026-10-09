#!/bin/sh
log="$HOME/.local/state/phoenix/autostart.log"; mkdir -p "$HOME/.local/state/phoenix"
echo "$(date +%T) autostart script started" > "$log"
# Your own login commands (not part of Phoenix, never shipped or overwritten): custom/scripts/autostart-user.sh
if [ -f "$HOME/.config/hypr/custom/scripts/autostart-user.sh" ]; then
  echo "$(date +%T) running autostart-user.sh" >> "$log"
  sh "$HOME/.config/hypr/custom/scripts/autostart-user.sh" >> "$log" 2>&1 &
fi
# In a virtual machine, idle sleep (hypridle → systemctl suspend) freezes the virtual graphics card on wake-up and the VM
# can then only be reset (QA 2026-10-08): hold off sleep for this session there. Real PCs are not affected.
if command -v systemd-detect-virt >/dev/null && systemd-detect-virt -q --vm; then
  echo "$(date +%T) virtual machine: sleep is held off for this session" >> "$log"
  systemd-inhibit --what=sleep --who=Phoenix --why="Sleep freezes the graphics of virtual machines" sleep infinity >/dev/null 2>&1 &
fi
# The login screen (phoenix login-screen install) shows this desktop's wallpaper and colors: refresh its copy
[ -x "$HOME/.local/bin/phoenix-greeter-theme" ] && "$HOME/.local/bin/phoenix-greeter-theme" >> "$log" 2>&1 &
# Custom-feature switches (Settings › Extras, written by ~/.local/bin/setup-features). Missing = on.
feature() { ! grep -q "^ *$1 = false" "$HOME/.config/hypr/custom/features.lua" 2>/dev/null; }
# Wallpaper Engine is off unless switched on in Settings › Extras (missing = off)
feature_on() { grep -q "^ *$1 = true" "$HOME/.config/hypr/custom/features.lua" 2>/dev/null; }

i=0
while [ $i -lt 60 ]; do
  hyprctl layers | grep -q "quickshell:background" && break
  sleep 1
  i=$((i+1))
done
echo "$(date +%T) shell background ready after $i s" >> "$log"
# Desktop check once the login has settled (replaces hypr-guard's login check): a notification only when something is
# wrong, e.g. no title bars after a Hyprland update or a shell built for an older Qt (~/.local/bin/phoenix-check)
[ -x "$HOME/.local/bin/phoenix-check" ] && (sleep 30; "$HOME/.local/bin/phoenix-check" health --notify >> "$log" 2>&1) &
# Setup profile steps that need a running desktop (wallpaper + colors after an install). No-op otherwise.
[ -x "$HOME/.local/bin/setup-profile" ] && "$HOME/.local/bin/setup-profile" first-login >> "$log" 2>&1
# First-time setup wizard after a fresh install (the clone installer leaves this marker; the wizard removes it)
if [ -f "$HOME/.local/state/setup-wizard/pending" ]; then
  echo "$(date +%T) opening the first-time setup wizard" >> "$log"
  qs -p "$HOME/.config/quickshell/end4-pC/setup-wizard.qml" > /dev/null 2>&1 &
fi
sleep 2

if feature_on wallpaperEngine; then
  echo "$(date +%T) starting wallpaper app" >> "$log"
  linux-wallpaper-engine-ux > /dev/null 2>&1 &

  i=0
  while [ $i -lt 30 ]; do
    pgrep -f "[l]inux-wallpaperengine" > /dev/null && break
    sleep 1
    i=$((i+1))
  done
  echo "$(date +%T) wallpaper renderer up after $i s" >> "$log"
else
  echo "$(date +%T) Wallpaper Engine background is switched off" >> "$log"
fi
sleep 2

# No background reload needed (since 2026-10-03): every wallpaper renderer now sits at or below the shell's
# background surface. Videos are drawn inside it; scenes run in linux-wallpaperengine with --layer background; web
# wallpapers run in wallpaper-engine-hyprland, patched to the background layer. See ~/.local/lib/wallpaper-engine-shell/.

if feature steamTray; then
  echo "$(date +%T) starting steam" >> "$log"
  steam -silent > /dev/null 2>&1 &   # -silent: start in the tray, no window
fi
echo "$(date +%T) done" >> "$log"
