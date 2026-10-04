#!/usr/bin/env bash
# GPU stats for the classic Resources widget: AMD, NVIDIA or Intel (gpustats.py; prints "No GPU available." if none)
exec python3 "$(dirname "$(readlink -f "$0")")/gpustats.py" info
