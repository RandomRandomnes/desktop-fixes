#!/usr/bin/env bash
# GPU power draw for the classic Resources widget: AMD, NVIDIA or Intel Arc (gpustats.py)
exec python3 "$(dirname "$(readlink -f "$0")")/../gpu/gpustats.py" power
