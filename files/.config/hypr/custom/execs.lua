-- minimize-start
-- Belongs to the minimizeToDock feature (features-start in env.lua).
if feature("minimizeToDock") then
-- Minimize: scripts/hb.sh min calls hb_minimize(), which fades the window to opacity 0 (opacity changes
-- animate) and then moves it to the hidden special:minimized workspace, where it stays invisible.
-- Restore: when the dock (or anything else) activates a minimized window, Hyprland opens that special
-- workspace. The handler below closes it again before the next frame with animations off (no slide/dim
-- flash), moves the window back to the workspace on screen, and fades it in.
local MIN = "special:minimized"
-- When a window closes or leaves a workspace, Hyprland refocuses the previously focused window, even a
-- minimized one, which opens special:minimized as well. For a short time after those events an opened
-- special:minimized is treated as that fallback, not as a restore.
local fallback_gen, fallback_live = 0, false
local function expect_fallback()
    fallback_gen = fallback_gen + 1
    local gen = fallback_gen
    fallback_live = true
    hl.timer(function() if gen == fallback_gen then fallback_live = false end end, { timeout = 400, type = "oneshot" })
end

local function set_opacity(sel, active, inactive)
    hl.dispatch(hl.dsp.window.set_prop({ window = sel, prop = "opacity", value = tostring(active) }))
    hl.dispatch(hl.dsp.window.set_prop({ window = sel, prop = "opacity_inactive", value = tostring(inactive) }))
end

local function without_animations(fn)
    local anims = hl.get_config("animations.enabled")
    hl.config({ animations = { enabled = false } })
    fn()
    hl.config({ animations = { enabled = anims } })
end

-- Move focus to the most recently used window on workspace ws_id. If it has none, Hyprland would keep
-- focus on a hidden window (and a later restore would then pull out that one too), so bounce to a
-- temporary workspace and back, which clears it. Invisible, animations are off.
local function refocus_on(ws_id)
    local best
    for _, w in ipairs(hl.get_workspace_windows(ws_id) or {}) do
        if not best or w.focus_history_id < best.focus_history_id then best = w end
    end
    if best then
        hl.dispatch(hl.dsp.focus({ window = "address:" .. best.address }))
    elseif ws_id > 0 then
        without_animations(function()
            hl.dispatch(hl.dsp.focus({ workspace = ws_id + 500 }))
            hl.dispatch(hl.dsp.focus({ workspace = ws_id }))
        end)
    end
end

-- Global so hyprctl can reach it: hyprctl dispatch "hb_minimize('0x...')"
function hb_minimize(addr)
    local sel = "address:" .. addr
    set_opacity(sel, 0, 0)
    hl.timer(function()
        local win = hl.get_window(sel)
        local ws_id = win and win.workspace and win.workspace.id
        expect_fallback()
        hl.dispatch(hl.dsp.window.move({ workspace = MIN, follow = false, window = sel }))
        if ws_id then refocus_on(ws_id) end
    end, { timeout = 180, type = "oneshot" })
    return hl.dsp.no_op()
end

hl.on("window.close", expect_fallback)
hl.on("window.destroy", expect_fallback)
hl.on("window.move_to_workspace", function(win, ws)
    if not (ws and ws.name == MIN) then expect_fallback() end
end)

local function close_minimized_special()
    local sp = hl.get_active_special_workspace()
    if sp and sp.name == MIN then
        without_animations(function() hl.dispatch(hl.dsp.workspace.toggle_special("minimized")) end)
    end
end

local function restore_active()
    local win = hl.get_active_window()
    close_minimized_special()
    if not (win and win.workspace and win.workspace.name == MIN) then return end
    local target = hl.get_active_workspace()
    if not target then return end
    if fallback_live then
        refocus_on(target.id)
        return
    end
    local sel = "address:" .. win.address
    without_animations(function() hl.dispatch(hl.dsp.window.move({ workspace = target.id, window = sel })) end)
    hl.dispatch(hl.dsp.focus({ window = sel }))
    set_opacity(sel, hl.get_config("decoration.active_opacity"), hl.get_config("decoration.inactive_opacity"))
end

-- Opening special:minimized first focuses whatever was used last in there, and only then the window
-- that was activated. So act a moment later (still before the next frame is drawn), once focus is final.
local function restore_soon()
    hl.timer(restore_active, { timeout = 1, type = "oneshot" })
end

hl.on("workspace.special_active", function(ws)
    if ws and ws.name == MIN then restore_soon() end
end)

hl.on("window.active", function(win)
    if win and win.workspace and win.workspace.name == MIN then restore_soon() end
end)
end
-- minimize-end


-- autostart-start
hl.on("hyprland.start", function()
    hl.exec_cmd("$HOME/.config/hypr/custom/scripts/autostart.sh")
end)
-- autostart-end

-- reapply-patches-start
hl.on("hyprland.start", function()
    hl.exec_cmd("python3 $HOME/.config/hypr/custom/scripts/reapply-shell-patches.py")
end)
-- reapply-patches-end

-- float-over-max-start
-- Belongs to the windowsStyle feature (features-start in env.lua).
if feature("windowsStyle") then
local MIN = "special:minimized"
-- Maximizing a window (fullscreen mode 1) clears Hyprland's "allowed over fullscreen" flag on every other
-- window on that workspace. Floating windows that were already open are still drawn on top, but clicks and
-- hover go to the maximized window behind them. Raising them sets the flag again; the stacking among them
-- is kept. True fullscreen (mode 2) is left alone.
-- Focusing the maximized window (clicking it, or hovering it) has the same effect even though the flag stays
-- set: the other floating windows are still drawn on top, but clicks and hover keep going to the maximized
-- window until a float is raised again (2026-10-08). So they are raised again (all = true) whenever it gets
-- the focus, a moment later so Hyprland's own raise of the clicked window comes first.
local function raise_floats_over_max(ws, except, all)
    if not (ws and ws.has_fullscreen and ws.fullscreen_mode == 1) then return end
    for _, w in ipairs(hl.get_workspace_windows(ws.id) or {}) do
        if w.floating and w.fullscreen == 0 and (all or not w.allowed_over_fullscreen)
            and not (except and w.address == except.address) then
            hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = "address:" .. w.address }))
        end
    end
end

hl.on("window.active", function(win)
    if not (win and win.fullscreen == 1 and win.workspace) then return end
    local addr = win.address
    hl.timer(function()
        local w = hl.get_window("address:" .. addr)
        if w and w.fullscreen == 1 and w.workspace then raise_floats_over_max(w.workspace, w, true) end
    end, { timeout = 1, type = "oneshot" })
end)

hl.on("window.fullscreen", function(win)
    if win and win.fullscreen == 1 and win.workspace then raise_floats_over_max(win.workspace, win) end
end)

hl.on("window.move_to_workspace", function(win, ws)
    if win and ws and ws.name ~= MIN then raise_floats_over_max(ws) end
end)
end
-- float-over-max-end

-- workspace-groups-start
-- Each screen gets its own 10 workspaces (2026-10-08, Phoenix; feature "workspaceGroups", Settings › Extras):
-- the first screen 1-10, the second 11-20, the third 21-30, … Screens are numbered in the order they were first seen
-- (by make/model/serial, kept in ~/.local/state/phoenix/screen-order), so a screen keeps its numbers across ports and
-- restarts. A screen that is plugged in starts on the first workspace of its group, and that group's workspaces always
-- open on it. ii's Super+1…0 already go to the workspace with that number in the current screen's group
-- (workspace_in_group), and each bar shows its own screen's group.
if feature("workspaceGroups") then
local ORDER_FILE = HOME .. "/.local/state/phoenix/screen-order"

local function read_order()
    local order = {}
    local f = io.open(ORDER_FILE, "r")
    if f then
        for line in f:lines() do if line ~= "" then table.insert(order, line) end end
        f:close()
    end
    return order
end

local function write_order(order)
    os.execute("mkdir -p \"" .. HOME .. "/.local/state/phoenix\"")
    local f = io.open(ORDER_FILE, "w")
    if f then f:write(table.concat(order, "\n") .. "\n"); f:close() end
end

local function index_of(list, value)
    for i, v in ipairs(list) do if v == value then return i end end
    return nil
end

local rules = {}   -- workspace number → its rule (replaced when its screen changes)

local function assign_groups()
    local mons = hl.get_monitors() or {}
    table.sort(mons, function(a, b) return a.id < b.id end)
    local order, changed = read_order(), false
    for _, m in ipairs(mons) do
        local key = (m.description and m.description ~= "") and m.description or m.name
        if not index_of(order, key) then table.insert(order, key); changed = true end
    end
    if changed then write_order(order) end
    local owner = {}   -- group number → the connected screen it belongs to
    for _, m in ipairs(mons) do
        local key = (m.description and m.description ~= "") and m.description or m.name
        local group = index_of(order, key) - 1
        owner[group] = m
        local first = group * workspaceGroupSize + 1
        for ws = first, first + workspaceGroupSize - 1 do
            if rules[ws] then pcall(function() rules[ws]:set_enabled(false) end) end
            local ok, rule = pcall(hl.workspace_rule, { workspace = tostring(ws), monitor = m.name, default = (ws == first) })
            rules[ws] = ok and rule or nil
        end
    end
    -- workspaces on the wrong screen (Hyprland parks a screen's workspaces elsewhere when it is unplugged) go home
    for _, w in ipairs(hl.get_workspaces() or {}) do
        if w.id and w.id > 0 and w.monitor then
            local home = owner[math.floor((w.id - 1) / workspaceGroupSize)]
            if home and home.name ~= w.monitor.name then
                pcall(hl.dispatch, hl.dsp.workspace.move({ workspace = w.id, monitor = home.name }))
            end
        end
    end
    -- a screen showing a workspace of another group switches to the first of its own; focus stays where it was
    local focused = hl.get_active_workspace()
    for group, m in pairs(owner) do
        local first = group * workspaceGroupSize + 1
        local now = hl.get_monitor(m.name)
        local active = now and now.active_workspace and now.active_workspace.id or 0
        if active < first or active > first + workspaceGroupSize - 1 then
            pcall(hl.dispatch, hl.dsp.focus({ workspace = first }))
        end
    end
    if focused and focused.id and focused.id > 0 then
        local f = hl.get_active_workspace()
        -- only back to a workspace that still exists (an empty one is removed when its screen switches away)
        if f and f.id ~= focused.id and hl.get_workspace(focused.id) then
            pcall(hl.dispatch, hl.dsp.focus({ workspace = focused.id }))
        end
    end
end

local function assign_soon()
    hl.timer(assign_groups, { timeout = 500, type = "oneshot" })
end
hl.on("hyprland.start", assign_soon)
hl.on("monitor.added", assign_soon)
assign_soon()   -- also after a config reload
end
-- workspace-groups-end
