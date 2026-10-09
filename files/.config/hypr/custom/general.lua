

-- hyprbars-start
-- Title bars belong to the windowsStyle feature (features-start in env.lua); the minimize button to minimizeToDock.
local function setup_hyprbars()
    if not feature("windowsStyle") then return end
    if not (hl.plugin and hl.plugin.hyprbars) then return end
    local hb = HOME .. "/.config/hypr/custom/scripts/hb.sh"
    hl.config({
        plugin = {
            hyprbars = {
                bar_height = 26,
                on_double_click = hb .. " max",
            },
        },
    })
    hl.plugin.hyprbars.add_button({ bg_color = "rgb(ff5f57)", fg_color = "rgb(000000)", size = 14, icon = "x", action = hb .. " close" })
    hl.plugin.hyprbars.add_button({ bg_color = "rgb(28c840)", fg_color = "rgb(000000)", size = 14, icon = "+", action = hb .. " max" })
    if feature("minimizeToDock") then
        hl.plugin.hyprbars.add_button({ bg_color = "rgb(febc2e)", fg_color = "rgb(000000)", size = 14, icon = "-", action = hb .. " min" })
    end
end

setup_hyprbars()

hl.on("hyprland.start", function()
    if not feature("windowsStyle") then return end
    hl.dispatch(hl.dsp.exec_cmd("hyprctl plugin load /usr/lib/libhyprbars.so"))
    hl.timer(setup_hyprbars, { timeout = 1500, type = "oneshot" })
end)
-- hyprbars-end

-- Phoenix (2026-10-09): no "Hyprland updated" news / donation screen at session start (QA: it appeared on top of
-- the setup assistant and the keyring prompt after a login)
pcall(hl.config, { ecosystem = { no_update_news = true, no_donation_nag = true } })
