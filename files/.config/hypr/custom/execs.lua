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
local faded = {}   -- address → true while minimize has it at opacity 0
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
    local ok, err = pcall(fn)   -- animations come back even if fn fails (QA 2026-10-08)
    hl.config({ animations = { enabled = anims ~= false } })
    if not ok then print("minimize: " .. tostring(err)) end
end

-- Move focus to the most recently used window on workspace ws_id. If it has none, Hyprland would keep
-- focus on a hidden window (and a later restore would then pull out that one too), so bounce to a
-- temporary workspace and back, which clears it. Invisible, animations are off.
local function refocus_on(ws_id)
    local best
    for _, w in ipairs(hl.get_workspace_windows(ws_id) or {}) do
        -- -1 = never focused: not "the last one used" (QA 2026-10-08)
        if w.focus_history_id >= 0 and (not best or w.focus_history_id < best.focus_history_id) then best = w end
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
    faded[addr] = true
    hl.timer(function()
        local win = hl.get_window(sel)
        local ws_id = win and win.workspace and win.workspace.id
        expect_fallback()
        hl.dispatch(hl.dsp.window.move({ workspace = MIN, follow = false, window = sel }))
        if ws_id then refocus_on(ws_id) end
    end, { timeout = 180, type = "oneshot" })
    return hl.dsp.no_op()
end

-- Hyprland's refocus only follows the FOCUSED window closing or leaving; any other window doing so used to block a dock
-- restore for 400 ms (QA 2026-10-08)
local last_active = nil
hl.on("window.active", function(win) last_active = win and win.address or nil end)
local function fallback_if_focused(win) if win and win.address == last_active then expect_fallback() end end
hl.on("window.close", fallback_if_focused)
hl.on("window.destroy", fallback_if_focused)
hl.on("window.move_to_workspace", function(win, ws)
    if not (ws and ws.name == MIN) then
        fallback_if_focused(win)
        -- out of the minimized place some other way (Overview drag, "move to workspace"): fade it back in, it was
        -- left invisible (QA 2026-10-08)
        if win and faded[win.address] then
            faded[win.address] = nil
            set_opacity("address:" .. win.address, hl.get_config("decoration.active_opacity"), hl.get_config("decoration.inactive_opacity"))
        end
    end
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
    -- in front of the others (QA 2026-10-09: with the pointer over its old place it came back behind them)
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = sel }))
    set_opacity(sel, hl.get_config("decoration.active_opacity"), hl.get_config("decoration.inactive_opacity"))
    faded[win.address] = nil
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

-- Several times: a real click holds the button for a moment and Hyprland raises the clicked window again when it is
-- released, after a single early raise (quick test clicks passed, the user's clicks didn't; 2026-10-08).
hl.on("window.active", function(win)
    if not (win and win.fullscreen == 1 and win.workspace) then return end
    local addr = win.address
    for _, ms in ipairs({ 1, 200, 700 }) do
        hl.timer(function()
            local w = hl.get_window("address:" .. addr)
            local active = hl.get_active_window()
            -- only while it is still the maximized, focused window
            if w and w.fullscreen == 1 and w.workspace and active and active.address == addr then
                raise_floats_over_max(w.workspace, w, true)
            end
        end, { timeout = ms, type = "oneshot" })
    end
end)

hl.on("window.fullscreen", function(win)
    -- floating windows aren't kept maximized: windows-maximize turns them into normal full-size windows (2026-10-08)
    if win and win.fullscreen == 1 and win.workspace and not win.floating then raise_floats_over_max(win.workspace, win) end
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
    -- groups go to the connected screens in first-seen order: a lone screen always has 1-10, the next 11-20, …
    -- (it used to be the position among every screen ever seen, so a new desk monitor could get 21-30; QA 2026-10-08).
    -- A mirrored screen shows another one and gets no group.
    local ranked = {}
    for _, m in ipairs(mons) do
        if not m.is_mirror then
            local key = (m.description and m.description ~= "") and m.description or m.name
            table.insert(ranked, { m = m, i = index_of(order, key) })
        end
    end
    table.sort(ranked, function(a, b) return a.i < b.i end)
    local owner, group_of = {}, {}   -- group number → screen; screen name → group number
    for g, r in ipairs(ranked) do owner[g - 1] = r.m; group_of[r.m.name] = g - 1 end
    for ws, rule in pairs(rules) do   -- groups that no screen has now: their rules go
        if not owner[math.floor((ws - 1) / workspaceGroupSize)] then pcall(function() rule:set_enabled(false) end); rules[ws] = nil end
    end
    for group, m in pairs(owner) do
        local first = group * workspaceGroupSize + 1
        for ws = first, first + workspaceGroupSize - 1 do
            if rules[ws] then pcall(function() rules[ws]:set_enabled(false) end) end
            local ok, rule = pcall(hl.workspace_rule, { workspace = tostring(ws), monitor = m.name, default = (ws == first) })
            rules[ws] = ok and rule or nil
        end
    end
    -- workspaces on the wrong screen (Hyprland parks a screen's workspaces elsewhere when it is unplugged) go home;
    -- workspaces of a group no screen has now (its screen was unplugged): their windows move to the same place in the
    -- group of the screen they ended up on (12 → 2), so the bar and Super+1…0 reach them (QA 2026-10-08)
    for _, w in ipairs(hl.get_workspaces() or {}) do
        if w.id and w.id > 0 and w.monitor then
            local g = math.floor((w.id - 1) / workspaceGroupSize)
            local home = owner[g]
            if home and home.name ~= w.monitor.name then
                pcall(hl.dispatch, hl.dsp.workspace.move({ workspace = w.id, monitor = home.name }))
            elseif not home and group_of[w.monitor.name] then
                local target = group_of[w.monitor.name] * workspaceGroupSize + (w.id - 1) % workspaceGroupSize + 1
                for _, win in ipairs(hl.get_workspace_windows(w.id) or {}) do
                    pcall(hl.dispatch, hl.dsp.window.move({ workspace = target, follow = false, window = "address:" .. win.address }))
                end
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
hl.on("monitor.added", assign_soon)
hl.on("monitor.removed", assign_soon)
assign_soon()   -- at start and after every config reload
end
-- workspace-groups-end

-- windows-maximize-start
-- Maximize like Windows (2026-10-08, Phoenix; windowsStyle feature). Hyprland's maximized mode puts the window on its
-- own layer: other windows can be drawn above it while clicks still go to it (clicking inside an already focused
-- maximized window lifts it for input without any event). So every maximize (title bar button and double-click via
-- hb.sh, Super+D, apps that ask to be maximized) becomes a normal floating window with exactly the box Hyprland gives
-- a maximized one; the window you see on top then always gets the clicks. Maximizing it again restores the size and
-- place it had before; if it was moved or resized meanwhile, it is maximized again instead.
if feature("windowsStyle") then
-- address → { max = box, prev = box }; kept in a runtime file because a config reload (Settings changes, display
-- profiles, setup-features) starts this script afresh and used to forget them (QA 2026-10-08: no restore after a reload)
local MAXED_FILE = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/phoenix-maximized"
local maxed = {}
do
    local f = io.open(MAXED_FILE, "r")
    if f then
        for line in f:lines() do
            local a, n = line:match("^(%S+)%s+(.*)$")
            local v = {}
            for x in (n or ""):gmatch("%-?%d+") do table.insert(v, tonumber(x)) end
            if a and #v == 8 then
                maxed[a] = { max = { x = v[1], y = v[2], w = v[3], h = v[4] }, prev = { x = v[5], y = v[6], w = v[7], h = v[8] } }
            end
        end
        f:close()
    end
end
local function save_maxed()
    local f = io.open(MAXED_FILE, "w")
    if not f then return end
    for a, s in pairs(maxed) do
        f:write(string.format("%s %d %d %d %d %d %d %d %d\n", a, s.max.x, s.max.y, s.max.w, s.max.h, s.prev.x, s.prev.y, s.prev.w, s.prev.h))
    end
    f:close()
end

local function box_of(w) return { x = w.at.x or w.at[1], y = w.at.y or w.at[2], w = w.size.x or w.size[1], h = w.size.y or w.size[2] } end
local function same(a, b) return a and b and math.abs(a.x - b.x) <= 2 and math.abs(a.y - b.y) <= 2 and math.abs(a.w - b.w) <= 2 and math.abs(a.h - b.h) <= 2 end
local function place(sel, b)
    hl.dispatch(hl.dsp.window.resize({ x = b.w, y = b.h, window = sel }))
    hl.dispatch(hl.dsp.window.move({ x = b.x, y = b.y, window = sel }))
end

local function convert(win)
    if not (win and win.fullscreen == 1 and win.floating) then return end
    local addr = win.address
    local sel = "address:" .. addr
    local tries, last = 0, nil
    local function step()   -- wait until Hyprland's maximized box stops changing (layout/animation after a reload)
        local w = hl.get_window(sel)
        if not (w and w.fullscreen == 1) then return end
        local max_box = box_of(w)
        tries = tries + 1
        if not same(max_box, last) and tries < 8 then
            last = max_box
            hl.timer(step, { timeout = 60, type = "oneshot" })
            return
        end
        hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 0, window = sel }))
        hl.timer(function()   -- back to a normal window, at its previous floating place
            local n = hl.get_window(sel)
            if not n then return end
            local now = box_of(n)
            local s = maxed[addr]
            if s and same(now, s.max) then
                place(sel, s.prev)   -- maximized by Phoenix and untouched since: restore
                maxed[addr] = nil
            else
                maxed[addr] = { max = max_box, prev = now }
                place(sel, max_box)
            end
            save_maxed()
            -- the window you just maximized or restored belongs in front (the float-over-max raise could put others above it)
            hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = sel }))
        end, { timeout = 30, type = "oneshot" })
    end
    hl.timer(step, { timeout = 30, type = "oneshot" })
end
hl.on("window.fullscreen", convert)
-- windows maximized the old way (before this, or before a config reload) switch over too
hl.timer(function()
    for _, w in ipairs(hl.get_windows() or {}) do convert(w) end
end, { timeout = 1000, type = "oneshot" })

hl.on("window.close", function(win) if win and maxed[win.address] then maxed[win.address] = nil; save_maxed() end end)

-- Password prompts (login keyring, polkit) come to the front when they open; one appeared behind the setup assistant
-- while it had the keyboard, so the password went into a field nobody could see (QA 2026-10-09)
local PROMPTS = { ["gcr-prompter"] = true, ["polkit-gnome-authentication-agent-1"] = true, ["hyprpolkitagent"] = true,
                  ["org.kde.polkit-kde-authentication-agent-1"] = true, ["lxqt-policykit-agent"] = true }
hl.on("window.open", function(win)
    if not (win and PROMPTS[win.class or ""]) then return end
    local sel = "address:" .. win.address
    hl.timer(function()
        if hl.get_window(sel) then
            hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = sel }))
            hl.dispatch(hl.dsp.focus({ window = sel }))
        end
    end, { timeout = 150, type = "oneshot" })
end)

-- A window that gets the focus while the mouse isn't over it (dock, Alt+Tab, Overview, keyboard) comes to the front,
-- like on Windows. Focus from just hovering it (follow_mouse) doesn't raise, so moving the mouse doesn't shuffle windows.
hl.on("window.active", function(win)
    if not (win and win.floating and win.fullscreen == 0 and win.at and win.size) then return end
    local c = hl.get_cursor_pos()
    local b = box_of(win)
    local cx, cy = c and (c.x or c[1]), c and (c.y or c[2])
    local over = cx and cx >= b.x - 4 and cx <= b.x + b.w + 4 and cy >= b.y - 40 and cy <= b.y + b.h + 4   -- 40: its title bar
    if not over then
        hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = "address:" .. win.address }))
    end
end)
end
-- windows-maximize-end
