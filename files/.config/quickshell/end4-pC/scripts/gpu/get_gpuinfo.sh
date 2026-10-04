#!/usr/bin/env bash
# AMD GPU stats for illogical-impulse Resources widget
set -uo pipefail

if ! ls /sys/class/drm/card*/device 1>/dev/null 2>&1; then
    echo "No GPU available."
    exit 1
fi

card_path=""
best_vram_total=-1
best_boot_vga=1
for d in /sys/class/drm/card*/device; do
    [[ -r "$d/vendor" ]] || continue
    grep -qi "0x1002" "$d/vendor" || continue
    vtot=0
    [[ -r "$d/mem_info_vram_total" ]] && vtot=$(cat "$d/mem_info_vram_total")
    boot=1
    [[ -r "$d/boot_vga" ]] && boot=$(cat "$d/boot_vga")
    if (( vtot > best_vram_total )) || { (( vtot == best_vram_total )) && [[ "$boot" == "0" && "$best_boot_vga" != "0" ]]; }; then
        card_path="$d"
        best_vram_total=$vtot
        best_boot_vga=$boot
    fi
done
if [[ -n "${AMD_GPU_CARD:-}" && -d "/sys/class/drm/${AMD_GPU_CARD}/device" ]]; then
    card_path="/sys/class/drm/${AMD_GPU_CARD}/device"
fi
if [[ -z "$card_path" ]]; then
    echo "No GPU available."
    exit 1
fi

if [[ -r "$card_path/gpu_busy_percent" ]]; then
    gpu_usage=$(cat "$card_path/gpu_busy_percent")
else
    gpu_usage=0
fi

if [[ -r "$card_path/mem_info_vram_used" && -r "$card_path/mem_info_vram_total" ]]; then
    vram_used_b=$(cat "$card_path/mem_info_vram_used")
    vram_total_b=$(cat "$card_path/mem_info_vram_total")
    vram_used_gb=$(awk -v u="$vram_used_b" 'BEGIN{printf "%.1f", u/1024/1024/1024}')
    vram_total_gb=$(awk -v t="$vram_total_b" 'BEGIN{printf "%.1f", t/1024/1024/1024}')
else
    vram_used_gb=0.0
    vram_total_gb=0.0
fi

temperature=0
found=0
for hm in "$card_path"/hwmon/hwmon*; do
    [[ -d "$hm" ]] || continue
    for lbl in "$hm"/temp*_label; do
        [[ -r "$lbl" ]] || continue
        if grep -qi "edge" "$lbl"; then
            base="${lbl%_label}"
            if [[ -r "${base}_input" ]]; then
                temperature=$(awk '{printf "%.0f",$1/1000}' "${base}_input")
                found=1
                break
            fi
        fi
    done
    [[ $found -eq 1 ]] && break
done
if [[ $found -eq 0 ]]; then
    for hm in "$card_path"/hwmon/hwmon*; do
        [[ -d "$hm" ]] || continue
        for tin in "$hm"/temp1_input; do
            [[ -r "$tin" ]] || continue
            temperature=$(awk '{printf "%.0f",$1/1000}' "$tin")
            break 2
        done
    done
fi

echo "[AMD GPU]"
echo "  Usage : ${gpu_usage} %"
echo "  VRAM : ${vram_used_gb}/${vram_total_gb} GB"
echo "  Temp : ${temperature} °C"
