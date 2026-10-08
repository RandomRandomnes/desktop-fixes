#!/bin/sh
log="$HOME/hypr-guard/autostart.log"; mkdir -p "$HOME/hypr-guard"
echo "$(date +%T) autostart script started" > "$log"
# Your own login commands (not part of Phoenix, never shipped or overwritten): custom/scripts/autostart-user.sh
if [ -f "$HOME/.config/hypr/custom/scripts/autostart-user.sh" ]; then
  echo "$(date +%T) running autostart-user.sh" >> "$log"
  sh "$HOME/.config/hypr/custom/scripts/autostart-user.sh" >> "$log" 2>&1 &
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
# Setup profile steps that need a running desktop (wallpaper + colors after an install). No-op otherwise.
[ -x "$HOME/.local/bin/setup-profile" ] && "$HOME/.local/bin/setup-profile" first-login >> "$log" 2>&1
# (A fresh install's first hypr-guard snapshot is taken by the login check: hypr-guard check --login.)
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
