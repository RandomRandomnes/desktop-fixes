#!/usr/bin/env bash
# GPU power draw for illogical-impulse Resources widget
set -uo pipefail

card_path=""
best_vram_total=-1
for d in /sys/class/drm/card*/device; do
    [[ -r "$d/vendor" ]] || continue
    grep -qi "0x1002" "$d/vendor" || continue
    vtot=0
    [[ -r "$d/mem_info_vram_total" ]] && vtot=$(cat "$d/mem_info_vram_total")
    if (( vtot > best_vram_total )); then
        card_path="$d"
        best_vram_total=$vtot
    fi
done
if [[ -n "${AMD_GPU_CARD:-}" && -d "/sys/class/drm/${AMD_GPU_CARD}/device" ]]; then
    card_path="/sys/class/drm/${AMD_GPU_CARD}/device"
fi

if [[ -z "$card_path" ]]; then
    echo "No power data available."
    exit 1
fi

gpu_watts=""
gpu_cap_watts=""
for hm in "$card_path"/hwmon/hwmon*; do
    [[ -r "$hm/power1_average" ]] && gpu_watts=$(awk -v r="$(cat "$hm/power1_average")" 'BEGIN{printf "%.1f", r/1000000}')
    [[ -r "$hm/power1_cap" ]] && gpu_cap_watts=$(awk -v r="$(cat "$hm/power1_cap")" 'BEGIN{printf "%.1f", r/1000000}')
    [[ -n "$gpu_watts" ]] && break
done

if [[ -z "$gpu_watts" ]]; then
    echo "No power data available."
    exit 1
fi
[[ -z "$gpu_cap_watts" ]] && gpu_cap_watts="0.0"

echo "[GPU Power]"
echo "  Draw : ${gpu_watts} W"
echo "  Cap : ${gpu_cap_watts} W"
