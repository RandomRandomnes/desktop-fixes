import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models.hyprland
import qs.modules.common.models.quickToggles

Item {
    id: root

    Loader {
        anchors.fill: parent
        sourceComponent: ({
            "display": display, "sound": sound, "notifications": notifications, "power": power,
            "storage": storage, "multitasking": multitasking, "clipboard": clipboard, "about": about
        })[WState.sub] ?? overview
    }

    // Shared: seconds → "5 minutes" style labels for idle timeouts
    readonly property var idleChoices: [
        { displayName: "1 minute", value: 60 }, { displayName: "2 minutes", value: 120 },
        { displayName: "3 minutes", value: 180 }, { displayName: "5 minutes", value: 300 },
        { displayName: "10 minutes", value: 600 }, { displayName: "15 minutes", value: 900 },
        { displayName: "20 minutes", value: 1200 }, { displayName: "30 minutes", value: 1800 },
        { displayName: "45 minutes", value: 2700 }, { displayName: "1 hour", value: 3600 },
        { displayName: "2 hours", value: 7200 }, { displayName: "3 hours", value: 10800 },
        { displayName: "5 hours", value: 18000 }, { displayName: "Never", value: 0 },
    ]
    function idleModel(current) {
        // keep a custom value selectable if it isn't one of the presets
        if (root.idleChoices.some(c => c.value === current)) return root.idleChoices;
        return root.idleChoices.concat([{ displayName: `${Math.round(current / 60)} minutes`, value: current }]);
    }

    // ── Overview ───────────────────────────────────────────────────
    Component {
        id: overview
        WPage {
            WSection {
                WLink { icon: "desktop_windows"; title: "Display"; description: "Brightness, night light, scale, resolution"; sub: "display" }
                WLink { icon: "volume_up"; title: "Sound"; description: "Volume levels, output, input, sound devices"; sub: "sound" }
                WLink { icon: "notifications"; title: "Notifications"; description: "Alerts from apps and system, do not disturb"; sub: "notifications" }
                WLink { icon: "power_settings_new"; title: "Power"; description: "Power mode, screen and sleep" + (Battery.available ? ", battery" : ""); sub: "power" }
                WLink { icon: "hard_drive"; title: "Storage"; description: "Storage space, drives, cleanup"; sub: "storage" }
                WLink { icon: "view_quilt"; title: "Multitasking"; description: "Window layout, gaps, workspaces, title bars"; sub: "multitasking" }
                WLink { icon: "content_paste"; title: "Clipboard"; description: "Clipboard history"; sub: "clipboard" }
                WLink { icon: "info"; title: "About"; description: "Device specifications, rename this PC"; sub: "about" }
            }
        }
    }

    // ── Display ────────────────────────────────────────────────────
    Component {
        id: display
        WPage {
            id: dp
            MonitorConfigOption { id: mc }
            NightLightToggle { id: nightLight }
            property int sel: 0
            readonly property var mon: mc.monitors[sel] ?? null
            readonly property var bright: Brightness.monitors.find(b => b.screen.name === (mon?.name ?? "")) ?? null
            function apply(changes) {
                mc.updateMonitor(dp.sel, changes);
                mc.applyAndSave(dp.sel);
            }

            WSection {
                visible: mc.monitors.length > 1
                title: "Select a display"
                WCombo {
                    icon: "monitor"
                    title: "Display"
                    model: mc.monitors.map((m, i) => ({ displayName: `${i + 1}  ·  ${m.description || m.name}`, value: i }))
                    currentValue: dp.sel
                    onSelected: v => dp.sel = v
                }
            }

            WSection {
                title: "Brightness & color"
                WSlider {
                    visible: (dp.bright?.ready ?? false) && (dp.bright.isDdc || Battery.available)
                    icon: "brightness_6"
                    title: "Brightness"
                    description: "Adjust the brightness of the built-in or DDC display"
                    value: dp.bright?.brightness ?? 0
                    onMoved: v => dp.bright.setBrightness(v)
                }
                WToggle {
                    icon: "nightlight"
                    title: "Night light"
                    description: "Use warmer colors to help block blue light"
                    checked: nightLight.toggled
                    onToggled: nightLight.mainAction()
                }
                WSlider {
                    icon: "thermostat"
                    title: "Night light strength"
                    description: "Lower is warmer"
                    from: 2500; to: 6500; stepSize: 100
                    format: v => `${Math.round(v)}K`
                    value: Config.options.light.night.colorTemperature
                    onMoved: v => Config.options.light.night.colorTemperature = Math.round(v)
                }
                WToggle {
                    icon: "schedule"
                    title: "Schedule night light"
                    description: Config.options.light.night.automatic ? `On from ${Config.options.light.night.from} to ${Config.options.light.night.to}` : "Turn on automatically at set hours"
                    checked: Config.options.light.night.automatic
                    onToggled: v => Config.options.light.night.automatic = v
                }
                WCard {
                    visible: Config.options.light.night.automatic
                    icon: "bedtime"
                    title: "Schedule hours"
                    description: "24-hour time, HH:MM"
                    TimeField { value: Config.options.light.night.from; onCommitted: v => Config.options.light.night.from = v }
                    StyledText { text: "to"; color: Appearance.colors.colSubtext }
                    TimeField { value: Config.options.light.night.to; onCommitted: v => Config.options.light.night.to = v }
                }
                WToggle {
                    icon: "flare"
                    title: "Anti-flashbang"
                    description: "Dim the screen briefly when a very bright window appears"
                    checked: Config.options.light.antiFlashbang.enable
                    onToggled: v => Config.options.light.antiFlashbang.enable = v
                }
            }

            WSection {
                title: "Scale & layout"
                visible: dp.mon !== null
                WCombo {
                    icon: "zoom_in"
                    title: "Scale"
                    description: "Change the size of text, apps, and other items"
                    model: [1, 1.25, 1.5, 1.6, 1.75, 2, 2.5, 3].map(s => ({ displayName: `${Math.round(s * 100)}%` + (s === 1.5 ? " (Recommended)" : ""), value: s }))
                    currentValue: dp.mon?.scale ?? 1
                    onSelected: v => dp.apply({ scale: v })
                }
                WCombo {
                    icon: "aspect_ratio"
                    title: "Display resolution & refresh rate"
                    description: "Adjust the resolution to fit your connected display"
                    fieldWidth: 280
                    model: (dp.mon?.availableModes ?? []).map(m => ({ displayName: m, value: m }))
                    currentValue: dp.mon?.currentMode ?? ""
                    onSelected: v => {
                        const p = v.match(/(\d+)x(\d+)@([\d.]+)Hz/);
                        if (p) dp.apply({ currentMode: v, width: parseInt(p[1]), height: parseInt(p[2]), refreshRate: parseFloat(p[3]) });
                    }
                }
                WCombo {
                    icon: "screen_rotation"
                    title: "Display orientation"
                    model: [
                        { displayName: "Landscape", value: 0 }, { displayName: "Portrait", value: 1 },
                        { displayName: "Landscape (flipped)", value: 2 }, { displayName: "Portrait (flipped)", value: 3 },
                    ]
                    currentValue: dp.mon?.transform ?? 0
                    onSelected: v => dp.apply({ transform: v })
                }
                WToggle {
                    icon: "speed"
                    title: "Variable refresh rate"
                    description: "Adaptive sync (FreeSync / G-Sync) for smoother games and video"
                    checked: dp.mon?.vrr ?? false
                    onToggled: v => dp.apply({ vrr: v })
                }
            }

            WSection {
                title: "Related settings"
                WLink { icon: "hdr_on"; title: "Advanced display"; description: "Arrange displays, position, HDR, color management"; action: () => { WState.go("advanced"); GlobalStates.openSettingsAt("hyprland"); } }
            }
        }
    }

    component TimeField: Rectangle {
        id: tf
        property string value
        signal committed(string v)
        implicitWidth: 72
        implicitHeight: 34
        radius: Appearance.rounding.verysmall
        color: Appearance.colors.colLayer3
        border.width: input.activeFocus ? 2 : 0
        border.color: Appearance.colors.colPrimary
        TextInput {
            id: input
            anchors.centerIn: parent
            text: tf.value
            color: Appearance.colors.colOnLayer3
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.small
            validator: RegularExpressionValidator { regularExpression: /^([01]?\d|2[0-3]):[0-5]\d$/ }
            onEditingFinished: if (acceptableInput && text !== tf.value) tf.committed(text.padStart(5, "0"))
        }
    }

    // ── Sound ──────────────────────────────────────────────────────
    Component {
        id: sound
        WPage {
            PwObjectTracker { objects: Audio.outputAppNodes.concat(Audio.inputAppNodes).concat(Audio.outputDevices).concat(Audio.inputDevices) }

            WSection {
                title: "Output"
                WCombo {
                    icon: "speaker"
                    title: "Choose where to play sound"
                    fieldWidth: 320
                    model: Audio.outputDevices.map(n => ({ displayName: Audio.friendlyDeviceName(n), value: n.id }))
                    currentValue: Audio.sink?.id ?? -1
                    onSelected: v => Audio.setDefaultSink(Audio.outputDevices.find(n => n.id === v))
                }
                WSlider {
                    icon: Audio.sink?.audio?.muted ? "volume_off" : "volume_up"
                    title: "Volume"
                    to: 1
                    value: Audio.sink?.audio?.volume ?? 0
                    onMoved: v => { if (Audio.sink?.audio) Audio.sink.audio.volume = v }
                }
                WToggle {
                    icon: "volume_off"
                    title: "Mute"
                    checked: Audio.sink?.audio?.muted ?? false
                    onToggled: Audio.toggleMute()
                }
            }

            WSection {
                title: "Input"
                WCombo {
                    icon: "mic"
                    title: "Choose a device for speaking or recording"
                    fieldWidth: 320
                    model: Audio.inputDevices.map(n => ({ displayName: Audio.friendlyDeviceName(n), value: n.id }))
                    currentValue: Audio.source?.id ?? -1
                    onSelected: v => Audio.setDefaultSource(Audio.inputDevices.find(n => n.id === v))
                }
                WSlider {
                    icon: Audio.source?.audio?.muted ? "mic_off" : "mic"
                    title: "Input volume"
                    to: 1
                    value: Audio.source?.audio?.volume ?? 0
                    onMoved: v => { if (Audio.source?.audio) Audio.source.audio.volume = v }
                }
                WToggle {
                    icon: "mic_off"
                    title: "Mute microphone"
                    checked: Audio.source?.audio?.muted ?? false
                    onToggled: Audio.toggleMicMute()
                }
            }

            WSection {
                title: "Volume mixer"
                Repeater {
                    model: Audio.outputAppNodes
                    WSlider {
                        required property var modelData
                        icon: "graphic_eq"
                        title: Audio.appNodeDisplayName(modelData)
                        description: modelData.properties["media.name"] ?? ""
                        to: 1
                        value: modelData.audio?.volume ?? 0
                        onMoved: v => { if (modelData.audio) modelData.audio.volume = v }
                    }
                }
                WCard {
                    visible: Audio.outputAppNodes.length === 0
                    icon: "music_off"
                    title: "No apps are playing sound right now"
                }
            }

            WSection {
                title: "Advanced"
                WToggle {
                    icon: "hearing"
                    title: "Volume protection"
                    description: "Prevent sudden loud volume jumps"
                    checked: Config.options.audio.protection.enable
                    onToggled: v => Config.options.audio.protection.enable = v
                }
                WCombo {
                    icon: "music_note"
                    title: "Sound theme"
                    model: [{ displayName: "Freedesktop", value: "freedesktop" }, { displayName: "None", value: "" }]
                    currentValue: Config.options.sounds.theme
                    onSelected: v => Config.options.sounds.theme = v
                }
                WLink { icon: "tune"; title: "More sound settings"; description: "Open the full volume control app"; action: () => Quickshell.execDetached(["bash", "-c", Config.options.apps.volumeMixer]) ; chevronIcon: "open_in_new" }
            }
        }
    }

    // ── Notifications ──────────────────────────────────────────────
    Component {
        id: notifications
        WPage {
            WSection {
                WToggle {
                    icon: "notifications"
                    title: "Notifications"
                    description: "Get notifications from apps and other senders"
                    checked: !Notifications.silent
                    onToggled: v => Notifications.silent = !v
                }
                WToggle {
                    icon: "do_not_disturb_on"
                    title: "Do not disturb"
                    description: "Notifications will go straight to the notification center"
                    checked: Notifications.silent
                    onToggled: v => Notifications.silent = v
                }
            }
            WSection {
                title: "Banners"
                WCombo {
                    icon: "open_with"
                    title: "Notification position"
                    model: [
                        { displayName: "Top right", value: "top_right" }, { displayName: "Top left", value: "top_left" },
                        { displayName: "Bottom right", value: "bottom_right" }, { displayName: "Bottom left", value: "bottom_left" },
                    ]
                    currentValue: Config.options.notifications.position
                    onSelected: v => Config.options.notifications.position = v
                }
                WCombo {
                    icon: "timer"
                    title: "Show notifications for"
                    model: [3000, 5000, 7000, 10000, 15000, 30000].map(ms => ({ displayName: `${ms / 1000} seconds`, value: ms }))
                    currentValue: Config.options.notifications.timeout
                    onSelected: v => Config.options.notifications.timeout = v
                }
                WToggle {
                    icon: "counter_1"
                    title: "Show unread count on the taskbar"
                    checked: Config.options.bar.indicators.notifications.showUnreadCount
                    onToggled: v => Config.options.bar.indicators.notifications.showUnreadCount = v
                }
            }
            WSection {
                title: "Notification center"
                WCard {
                    icon: "inbox"
                    title: `${Notifications.list.length} notification${Notifications.list.length === 1 ? "" : "s"}`
                    WButton { buttonText: "Clear all"; enabled: Notifications.list.length > 0; onClicked: Notifications.discardAllNotifications() }
                }
            }
        }
    }

    // ── Power ──────────────────────────────────────────────────────
    Component {
        id: power
        WPage {
            id: pp
            function setIdle(key, v) {
                Config.options.hyprland.idle[key] = v;
                const i = Config.options.hyprland.idle;
                HyprlandConfig.setIdle(i.lock, i.screenOff, i.suspend);
            }

            WSection {
                visible: Battery.available
                title: "Battery"
                WCard {
                    icon: Battery.isCharging ? "battery_charging_full" : "battery_full"
                    title: `${Math.round(Battery.percentage * 100)}%`
                    description: Battery.isCharging ? "Charging" : Battery.isPluggedIn ? "Plugged in" : "On battery"
                }
                WToggle {
                    icon: "bedtime"
                    title: "Suspend when battery is very low"
                    checked: Config.options.battery.automaticSuspend
                    onToggled: v => Config.options.battery.automaticSuspend = v
                }
            }

            WSection {
                title: "Power"
                WCombo {
                    icon: "bolt"
                    title: "Power mode"
                    description: "Optimize for energy use or performance"
                    model: [
                        { displayName: "Best power efficiency", value: PowerProfile.PowerSaver },
                        { displayName: "Balanced", value: PowerProfile.Balanced },
                    ].concat(PowerProfiles.hasPerformanceProfile ? [{ displayName: "Best performance", value: PowerProfile.Performance }] : [])
                    currentValue: PowerProfiles.profile
                    onSelected: v => PowerProfiles.profile = v
                }
                WToggle {
                    icon: "coffee"
                    title: "Keep awake"
                    description: "Don't lock, turn off the screen, or sleep while this is on"
                    checked: Idle.inhibit
                    onToggled: v => Idle.inhibit = v
                }
            }

            WSection {
                title: "Screen and sleep"
                WCombo {
                    icon: "lock_clock"
                    title: "Lock the screen after"
                    model: root.idleModel(Config.options.hyprland.idle.lock)
                    currentValue: Config.options.hyprland.idle.lock
                    onSelected: v => pp.setIdle("lock", v)
                }
                WCombo {
                    icon: "desktop_access_disabled"
                    title: "Turn off my screen after"
                    model: root.idleModel(Config.options.hyprland.idle.screenOff)
                    currentValue: Config.options.hyprland.idle.screenOff
                    onSelected: v => pp.setIdle("screenOff", v)
                }
                WCombo {
                    icon: "bedtime"
                    title: "Put my device to sleep after"
                    model: root.idleModel(Config.options.hyprland.idle.suspend)
                    currentValue: Config.options.hyprland.idle.suspend
                    onSelected: v => pp.setIdle("suspend", v)
                }
            }

            WSection {
                title: "Power button & lid"
                WToggle {
                    icon: "password"
                    title: "Require password to shut down or restart from the lock screen"
                    checked: Config.options.lock.security.requirePasswordToPower
                    onToggled: v => Config.options.lock.security.requirePasswordToPower = v
                }
            }
        }
    }

    // ── Storage ────────────────────────────────────────────────────
    Component {
        id: storage
        WPage {
            id: sp
            property var drives: []
            property string pkgCache: "…"
            property string trash: "…"
            property int orphans: -1
            function refresh() { dfProc.running = true; sizesProc.running = true; }
            Component.onCompleted: refresh()

            Process {
                id: dfProc
                command: ["df", "-B1", "--output=target,size,used,avail,source", "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs", "-x", "overlay"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        const lines = text.trim().split("\n").slice(1);
                        sp.drives = lines.map(l => l.trim().split(/\s+/)).filter(p => p.length >= 5 && !p[0].startsWith("/boot") && !p[0].startsWith("/run"))
                            .map(p => ({ mount: p[0], size: Number(p[1]), used: Number(p[2]), avail: Number(p[3]), source: p[4] }));
                    }
                }
            }
            Process {
                id: sizesProc
                command: ["bash", "-c", "du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1; du -sh ~/.local/share/Trash 2>/dev/null | cut -f1 || echo 0; pacman -Qtdq 2>/dev/null | wc -l"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        const l = text.trim().split("\n");
                        sp.pkgCache = l[0] || "0";
                        sp.trash = l[1] || "0";
                        sp.orphans = parseInt(l[2] || "0");
                    }
                }
            }
            function fmt(b) {
                const u = ["B", "KB", "MB", "GB", "TB"];
                let i = 0;
                while (b >= 1024 && i < u.length - 1) { b /= 1024; i++; }
                return `${b.toFixed(i >= 3 ? 1 : 0)} ${u[i]}`;
            }
            function runInTerminal(cmd) {
                Quickshell.execDetached(["kitty", "-1", "--hold", "bash", "-c", cmd]);
            }

            WSection {
                title: "Drives"
                Repeater {
                    model: sp.drives
                    WCard {
                        required property var modelData
                        icon: modelData.mount === "/" ? "hard_drive" : "hard_drive_2"
                        title: modelData.mount === "/" ? "System (/)" : modelData.mount
                        description: `${sp.fmt(modelData.used)} used of ${sp.fmt(modelData.size)} · ${sp.fmt(modelData.avail)} free · ${modelData.source}`
                        StyledProgressBar {
                            Layout.preferredWidth: 220
                            value: modelData.used / modelData.size
                            highlightColor: modelData.used / modelData.size > 0.9 ? Appearance.colors.colError : Appearance.colors.colPrimary
                        }
                    }
                }
            }

            WSection {
                title: "Cleanup recommendations"
                WCard {
                    icon: "inventory_2"
                    title: "Package cache"
                    description: `${sp.pkgCache} of downloaded packages. Keeps the last 2 versions of each.`
                    WButton { buttonText: "Clean up"; onClicked: sp.runInTerminal("sudo paccache -rk2 && echo && echo Done.") }
                }
                WCard {
                    icon: "delete_sweep"
                    title: "Unused packages"
                    description: sp.orphans < 0 ? "Checking…" : sp.orphans === 0 ? "No orphaned packages" : `${sp.orphans} packages nothing depends on anymore`
                    WButton { buttonText: "Review"; enabled: sp.orphans > 0; onClicked: sp.runInTerminal("sudo pacman -Rns $(pacman -Qtdq)") }
                }
                WCard {
                    icon: "delete"
                    title: "Recycle bin"
                    description: `${sp.trash} in the trash`
                    WButton { buttonText: "Empty"; onClicked: { Quickshell.execDetached(["gio", "trash", "--empty"]); refreshTimer.start(); } }
                }
                Timer { id: refreshTimer; interval: 1500; onTriggered: sp.refresh() }
            }

            WSection {
                title: "Related settings"
                WLink { icon: "folder_open"; title: "Open file manager"; chevronIcon: "open_in_new"; action: () => Quickshell.execDetached(["dolphin"]) }
                WLink { icon: "analytics"; title: "Disk usage analyzer"; description: "Opens Filelight if installed"; chevronIcon: "open_in_new"; action: () => Quickshell.execDetached(["bash", "-c", "command -v filelight >/dev/null && filelight / || dolphin /"]) }
            }
        }
    }

    // ── Multitasking ───────────────────────────────────────────────
    Component {
        id: multitasking
        WPage {
            WSection {
                title: "Windows"
                WCombo {
                    icon: "dashboard"
                    title: "Tiling layout"
                    description: "How tiled windows are arranged (new windows float by default in your setup)"
                    model: [{ displayName: "Dwindle (split)", value: "dwindle" }, { displayName: "Master & stack", value: "master" }]
                    currentValue: Config.options.hyprland.general.layout
                    onSelected: v => { Config.options.hyprland.general.layout = v; HyprlandConfig.set("general:layout", v); }
                }
                WToggle {
                    icon: "title"
                    title: "Show title bars on windows"
                    checked: Config.options.windows.showTitlebar
                    onToggled: v => Config.options.windows.showTitlebar = v
                }
                WCombo {
                    icon: "ads_click"
                    title: "Focus follows mouse"
                    description: "Focus the window under the pointer"
                    model: [{ displayName: "Off (click to focus)", value: 0 }, { displayName: "Always", value: 1 }, { displayName: "Loose", value: 2 }, { displayName: "Strict", value: 3 }]
                    currentValue: Config.options.hyprland.input.followMouse
                    onSelected: v => { Config.options.hyprland.input.followMouse = v; HyprlandConfig.set("input:follow_mouse", v); }
                }
                WSlider {
                    icon: "padding"
                    title: "Gaps between windows"
                    from: 0; to: 20; stepSize: 1
                    format: v => `${Math.round(v)} px`
                    value: Config.options.hyprland.general.gapsIn
                    onMoved: v => { Config.options.hyprland.general.gapsIn = Math.round(v); HyprlandConfig.set("general:gaps_in", Math.round(v)); }
                }
                WSlider {
                    icon: "fit_screen"
                    title: "Gaps around screen edges"
                    from: 0; to: 40; stepSize: 1
                    format: v => `${Math.round(v)} px`
                    value: Config.options.hyprland.general.gapsOut
                    onMoved: v => { Config.options.hyprland.general.gapsOut = Math.round(v); HyprlandConfig.set("general:gaps_out", Math.round(v)); }
                }
                WSlider {
                    icon: "rounded_corner"
                    title: "Window corner rounding"
                    from: 0; to: 30; stepSize: 1
                    format: v => `${Math.round(v)} px`
                    value: Config.options.hyprland.decoration.rounding
                    onMoved: v => { Config.options.hyprland.decoration.rounding = Math.round(v); HyprlandConfig.set("decoration:rounding", Math.round(v)); }
                }
                WSlider {
                    icon: "opacity"
                    title: "Inactive window opacity"
                    from: 0.5; to: 1; stepSize: 0.05
                    value: Config.options.hyprland.decoration.inactiveOpacity
                    onMoved: v => { const r = Math.round(v * 100) / 100; Config.options.hyprland.decoration.inactiveOpacity = r; HyprlandConfig.set("decoration:inactive_opacity", r); }
                }
            }
            WSection {
                title: "Workspaces (virtual desktops)"
                WCombo {
                    icon: "view_column"
                    title: "Workspaces shown on the taskbar"
                    model: [3, 4, 5, 6, 8, 10].map(n => ({ displayName: `${n}`, value: n }))
                    currentValue: Config.options.bar.workspaces.shown
                    onSelected: v => Config.options.bar.workspaces.shown = v
                }
                WToggle {
                    icon: "apps"
                    title: "Show app icons on workspaces"
                    checked: Config.options.bar.workspaces.showAppIcons
                    onToggled: v => Config.options.bar.workspaces.showAppIcons = v
                }
                WToggle {
                    icon: "pin"
                    title: "Always show workspace numbers"
                    checked: Config.options.bar.workspaces.alwaysShowNumbers
                    onToggled: v => Config.options.bar.workspaces.alwaysShowNumbers = v
                }
            }
        }
    }

    // ── Clipboard ──────────────────────────────────────────────────
    Component {
        id: clipboard
        WPage {
            Component.onCompleted: Cliphist.refresh()
            WSection {
                WCard {
                    icon: "history"
                    title: "Clipboard history"
                    description: `${Cliphist.entries.length} items saved. Open it with Super+V.`
                    WButton { buttonText: "Clear"; onClicked: Cliphist.wipe() }
                }
                WToggle {
                    icon: "visibility_off"
                    title: "Hide sensitive clipboard items on public networks"
                    description: "Work safety: hides matching clipboard content when on networks like cafés or campuses"
                    checked: Config.options.workSafety.enable.clipboard
                    onToggled: v => Config.options.workSafety.enable.clipboard = v
                }
            }
        }
    }

    // ── About ──────────────────────────────────────────────────────
    Component {
        id: about
        WPage {
            id: ap
            Component.onCompleted: { if (SystemInfo.cpu === "") SystemInfo.refresh(); }
            readonly property var specs: [
                ["Device name", SystemInfo.hostname],
                ["Processor", SystemInfo.cpu],
                ["Graphics", SystemInfo.gpu],
                ["Installed RAM", (SystemInfo.memory.split("/").pop() || "").trim().replace(/Gi$/, " GB")],
                ["Operating system", SystemInfo.distroName],
                ["Kernel", SystemInfo.kernelVersion],
                ["Desktop", `Hyprland + illogical-impulse (${SystemInfo.windowingSystem || "Wayland"})`],
                ["Packages", SystemInfo.packages],
                ["Shell", SystemInfo.shell],
                ["Installed", SystemInfo.installAge],
                ["Uptime", DateTime.uptime],
            ]

            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                MaterialSymbol { text: "computer"; iconSize: 44; color: Appearance.colors.colPrimary }
                ColumnLayout {
                    spacing: 0
                    StyledText { text: SystemInfo.hostname; font.pixelSize: Appearance.font.pixelSize.huge; font.weight: Font.DemiBold; color: Appearance.colors.colOnLayer0 }
                    StyledText { text: SystemInfo.distroName; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.small }
                }
                Item { Layout.fillWidth: true }
                WButton { buttonText: "Rename this PC"; onClicked: renameRow.visible = !renameRow.visible }
            }

            WCard {
                id: renameRow
                visible: false
                icon: "edit"
                title: "New device name"
                description: "Letters, numbers and hyphens. You'll be asked for your password."
                Rectangle {
                    implicitWidth: 220; implicitHeight: 34
                    radius: Appearance.rounding.verysmall
                    color: Appearance.colors.colLayer3
                    TextInput {
                        id: nameInput
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        verticalAlignment: Text.AlignVCenter
                        color: Appearance.colors.colOnLayer3
                        font.family: Appearance.font.family.main
                        font.pixelSize: Appearance.font.pixelSize.small
                        text: SystemInfo.hostname
                        validator: RegularExpressionValidator { regularExpression: /^[A-Za-z0-9][A-Za-z0-9-]{0,62}$/ }
                    }
                }
                WButton {
                    accent: true
                    buttonText: "Rename"
                    enabled: nameInput.acceptableInput && nameInput.text !== SystemInfo.hostname
                    onClicked: renameProc.running = true
                }
                Process {
                    id: renameProc
                    command: ["pkexec", "hostnamectl", "hostname", nameInput.text]
                    onExited: code => { if (code === 0) { renameRow.visible = false; SystemInfo.refreshHostname(); } }
                }
            }

            WSection {
                title: "Device specifications"
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: specCol.implicitHeight + 28
                    radius: Appearance.rounding.verysmall + 2
                    color: Appearance.colors.colLayer2
                    ColumnLayout {
                        id: specCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14; leftMargin: 18 }
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            StyledText { Layout.fillWidth: true; text: "Specifications"; font.weight: Font.DemiBold; color: Appearance.colors.colOnLayer2 }
                            WButton {
                                id: copyBtn
                                property bool copied: false
                                buttonText: copied ? "Copied" : "Copy"
                                iconName: copied ? "check" : "content_copy"
                                onClicked: {
                                    Quickshell.clipboardText = ap.specs.filter(s => s[1]).map(s => `${s[0]}: ${s[1]}`).join("\n");
                                    copied = true;
                                    copyTimer.restart();
                                }
                                Timer { id: copyTimer; interval: 1500; onTriggered: copyBtn.copied = false }
                            }
                        }
                        Repeater {
                            model: ap.specs.filter(s => s[1])
                            RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 12
                                StyledText {
                                    Layout.preferredWidth: 170
                                    text: modelData[0]
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colSubtext
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData[1]
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnLayer2
                                    wrapMode: Text.Wrap
                                }
                            }
                        }
                    }
                }
            }

            WSection {
                title: "Related"
                WLink { icon: "monitoring"; title: "Task manager"; chevronIcon: "open_in_new"; action: () => Quickshell.execDetached(["bash", "-c", Config.options.apps.taskManager]) }
                WLink { icon: "info"; title: "About illogical-impulse"; description: "Shell version, credits, links"; action: () => { WState.go("advanced"); GlobalStates.openSettingsAt("about"); } }
            }
        }
    }
}
