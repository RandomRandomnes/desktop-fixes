#!/bin/sh
# hyprbars button handler: hb.sh close|max|min (restore is handled in execs.lua, minimize-start block)
case "$1" in
  close)
    hyprctl dispatch "hl.dsp.window.close()"
    ;;
  max)
    hyprctl dispatch "hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"toggle\" })"
    ;;
  min)
    # Fade out + hide is done in execs.lua (minimize-start block).
    addr=$(hyprctl activewindow -j | grep -oP '"address":\s*"\K0x[0-9a-f]+')
    [ -n "$addr" ] && hyprctl dispatch "hb_minimize('$addr')" >/dev/null
    ;;
esac
