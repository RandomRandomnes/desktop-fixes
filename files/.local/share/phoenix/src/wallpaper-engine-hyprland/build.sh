#!/bin/bash
# Builds ~/.local/bin/wallpaper-engine-hyprland, the web-wallpaper host that Phoenix's Wallpaper Engine support runs on
# Hyprland (2026-10-08). Phoenix ships this recipe instead of a compiled program: it is built here, against this PC's
# own Qt and ICU, so a Qt or ICU update can't leave a program built for other versions (F23), and the source is open.
#   Source: https://github.com/RainyPixel/wallpaper-engine-kde-plugin (GPL-2.0), folder hyprland/, at $COMMIT
#   plus phoenix.patch next to this file: background layer (shell surfaces stay above it), Wallpaper Engine's audio API,
#   an "audio" IPC command.
# Run again after a Qt update if web wallpapers stop working.
set -euo pipefail
COMMIT=b9fd9b3
REPO=https://github.com/RainyPixel/wallpaper-engine-kde-plugin.git
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${OUT:-$HOME/.local/bin/wallpaper-engine-hyprland}"
WORK="${XDG_CACHE_HOME:-$HOME/.cache}/phoenix-build/wallpaper-engine-kde-plugin"

missing=()
for c in git cmake g++ make; do command -v "$c" >/dev/null || missing+=("$c"); done
for p in qt6-webengine layer-shell-qt; do pacman -Q "$p" >/dev/null 2>&1 || missing+=("$p"); done
if [ ${#missing[@]} -gt 0 ]; then
    echo "Needed to build the web-wallpaper host: ${missing[*]}"
    echo "Install them with: sudo pacman -S --needed base-devel cmake qt6-webengine layer-shell-qt"
    exit 1
fi

if [ -d "$WORK/.git" ]; then
    git -C "$WORK" cat-file -e "$COMMIT^{commit}" 2>/dev/null || git -C "$WORK" fetch -q origin
else
    rm -rf "${WORK:?}"; git clone -q --filter=blob:none "$REPO" "$WORK"
fi
git -C "$WORK" checkout -q -f --detach "$COMMIT"
git -C "$WORK" clean -qfdx hyprland
git -C "$WORK" apply "$HERE/phoenix.patch"
cmake -S "$WORK/hyprland" -B "$WORK/build" -DCMAKE_BUILD_TYPE=Release -DWEHYPR_BUILD_TESTS=OFF >/dev/null
cmake --build "$WORK/build" -j"$(nproc)" >/dev/null
bin=$(find "$WORK/build" -maxdepth 2 -type f -name wallpaper-engine-hyprland -perm -u+x | head -1)
[ -n "$bin" ] || { echo "build finished but the program wasn't found"; exit 1; }
mkdir -p "$(dirname "$OUT")"
install -m 755 "$bin" "$OUT.new" && mv -f "$OUT.new" "$OUT"
echo "Built $OUT (source $COMMIT + phoenix.patch)"
