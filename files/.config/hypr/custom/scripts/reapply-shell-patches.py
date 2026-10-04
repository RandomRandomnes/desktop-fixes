#!/usr/bin/env python3
# Login hook (called from execs.lua). The real logic now lives in ~/.local/bin/hypr-guard,
# which holds the single list of tracked files. Kept as a shim so execs.lua doesn't need changing.
import os
os.execv(os.path.expanduser("~/.local/bin/hypr-guard"), ["hypr-guard", "check", "--login"])
