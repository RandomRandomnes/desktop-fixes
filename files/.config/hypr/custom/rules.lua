-- The shell's Settings window draws its own header (back, title, close) and is dragged by it: no hyprbars title bar.
-- Only while the plugin is loaded (windowsStyle on): without it the field is unknown and Hyprland reports an error (F11).
if feature("windowsStyle") and hl.plugin and hl.plugin.hyprbars then
    hl.window_rule({
        name = "settings-no-titlebar",
        match = { class = "^(org.quickshell)$", title = "^(Settings)$" },
        ["hyprbars:no_bar"] = true,
    })
end

-- First-time setup wizard (end4-pC setup-wizard.qml): always a centered floating window, also with tiling.
hl.window_rule({
    name = "setup-wizard",
    match = { title = "^(Set up your PC|Quick Start)$" },
    float = true,
    center = true,
})

-- Terminals the setup assistant opens (app installs, drivers, updates, boot menu; kitty --class phoenix-setup):
-- a centered window in front of the assistant. Without this, a maximized window on the workspace made the new
-- terminal take over as maximized (illogical-impulse's on_focus_under_fullscreen = 2), and Phoenix's
-- float-over-maximized fix then lifted the assistant above it.
hl.window_rule({
    name = "setup-terminal",
    match = { class = "^(phoenix-setup)$" },
    float = true,
    center = true,
    size = {"(monitor_w*0.50)", "(monitor_h*0.55)"},
    fullscreen_state = "0 0",
})

-- All rules here belong to the windowsStyle feature (features-start in env.lua).
if feature("windowsStyle") then

hl.window_rule({
    name = "float-all-windows",
    match = { class = ".*" },
    float = true,
})

-- Firefox asks for a tiny 500x120 window when floating; give main browser windows a real size.
-- Matched on initial title so Picture-in-Picture and dialogs keep their own sizes.
hl.window_rule({
    name = "firefox-main-size",
    match = { initial_class = "^(firefox)$", initial_title = "^(Mozilla Firefox)$" },
    size = {"(monitor_w*0.70)", "(monitor_h*0.80)"},
    center = true,
})

-- Steam's main window opens at 1280x720 (logical px), centered, instead of the size it remembers (~full screen).
-- Matched on initial title so the friends list, game windows and dialogs keep their own sizes.
hl.window_rule({
    name = "steam-main-size",
    match = { initial_class = "^(steam)$", initial_title = "^(Steam)$" },
    size = {"1280", "720"},
    center = true,
})

end
