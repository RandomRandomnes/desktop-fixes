-- Phoenix runs its own Quickshell config (end4-pC). illogical-impulse's hyprland/variables.lua sets qsConfig "ii" and
-- loads after custom/env.lua, so it is set again here: this file loads right after illogical-impulse's variables.
-- Swapping the custom folder (phoenix activate / deactivate) switches the shell with it.
hl.env("qsConfig", "end4-pC")
