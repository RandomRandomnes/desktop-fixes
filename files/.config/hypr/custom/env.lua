-- features-start
-- Custom-feature switches (2026-10-03). ~/.local/bin/setup-features writes features.lua from the shell's
-- config.json "extras" (Settings › Extras or a setup profile). A missing file or key means the feature is on.
do
    local ok, f = pcall(dofile, HOME .. "/.config/hypr/custom/features.lua")
    FEATURES = (ok and type(f) == "table") and f or {}
end
function feature(name) return FEATURES[name] ~= false end
-- features-end
-- Phoenix runs its own Quickshell config. Set here (custom/ loads after illogical-impulse's defaults), so swapping
-- the custom folder (phoenix activate / deactivate) also switches the shell.
hl.env("qsConfig", "end4-pC")
