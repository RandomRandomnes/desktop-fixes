import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models.quickToggles

Item {
    id: root

    Loader {
        anchors.fill: parent
        sourceComponent: ({
            "background": background, "colors": colors, "taskbar": taskbar, "dock": dock,
            "start": start, "appgrid": appgrid, "lockscreen": lockscreen, "widgets": widgets, "sidebar": sidebar
        })[WState.sub] ?? overview
    }

    function regenColors() {
        Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --noswitch`]);
    }

    component RoundedImage: Item {
        id: ri
        property string path
        property real r: Appearance.rounding.small
        Image {
            id: img
            anchors.fill: parent
            source: ri.path ? "file://" + ri.path : ""
            sourceSize.width: Math.max(ri.width * 2, 200)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle { width: img.width; height: img.height; radius: ri.r }
            }
        }
    }

    // ── Overview ───────────────────────────────────────────────────
    Component {
        id: overview
        WPage {
            RowLayout {
                Layout.fillWidth: true
                spacing: 20
                RoundedImage {
                    implicitWidth: 300
                    implicitHeight: 170
                    path: Config.options.background.wallpaperPath
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    StyledText { text: "Select a theme to apply"; color: Appearance.colors.colOnLayer0; font.pixelSize: Appearance.font.pixelSize.small }
                    StyledText {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: "Your colors follow your wallpaper. Pick light or dark, or change the wallpaper to get a new palette."
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                    ModeButtons { Layout.topMargin: 6 }
                }
            }
            WSection {
                WLink { icon: "wallpaper"; title: "Background"; description: "Background image, shuffle, slideshow"; sub: "background" }
                WLink { icon: "palette"; title: "Colors"; description: "Light/dark mode, color style, transparency"; sub: "colors" }
                WLink { icon: "toast"; title: "Taskbar"; description: "Taskbar position, items, behaviors, system tray"; sub: "taskbar" }
                WLink { icon: "dock_to_bottom"; title: "Dock"; description: "Pinned apps, size, auto-hide"; sub: "dock" }
                WLink { icon: "apps"; title: "Start"; description: "Pinned apps in the launcher, search"; sub: "start" }
                WLink { icon: "grid_view"; title: "Super menu apps"; description: "Choose which apps show in the app grid when you press Super"; sub: "appgrid" }
                WLink { icon: "lock"; title: "Lock screen"; description: "Lock screen look and behavior"; sub: "lockscreen" }
                WLink { icon: "widgets"; title: "Desktop widgets"; description: "Clock, calendar, notes, to-do and more on your desktop"; sub: "widgets" }
                WLink { icon: "right_panel_open"; title: "Sidebar"; description: "Show or hide the extras in the right sidebar"; sub: "sidebar" }
            }
        }
    }

    component ModeButtons: RowLayout {
        spacing: 10
        DarkModeToggle { id: dm }
        Repeater {
            model: [false, true]
            RippleButton {
                id: mb
                required property bool modelData
                implicitWidth: 120
                implicitHeight: 70
                buttonRadius: Appearance.rounding.small
                toggled: Appearance.m3colors.darkmode === modelData
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colBackgroundToggled: Appearance.colors.colPrimaryContainer
                colBackgroundToggledHover: Appearance.colors.colPrimaryContainerHover
                onClicked: if (!toggled) dm.mainAction()
                contentItem: ColumnLayout {
                    spacing: 4
                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: mb.modelData ? "dark_mode" : "light_mode"
                        iconSize: 24
                        fill: mb.toggled ? 1 : 0
                        color: mb.toggled ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: mb.modelData ? "Dark" : "Light"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: mb.toggled ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                    }
                }
            }
        }
    }

    // ── Background ─────────────────────────────────────────────────
    Component {
        id: background
        WPage {
            id: bp
            // only image files directly in the wallpaper folder: the shared folder model also lists subfolders, and
            // lists another folder when ~/Pictures/Wallpapers doesn't exist (F17)
            readonly property var recent: Wallpapers.wallpapers.filter(p => {
                const ext = p.slice(p.lastIndexOf(".") + 1).toLowerCase()
                return Wallpapers.extensions.includes(ext) && p.substring(0, p.lastIndexOf("/")) === Wallpapers.effectiveDirectory
            }).slice(0, 12)
            Component.onCompleted: Wallpapers.load()

            RoundedImage {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(width * 9 / 16, 340)
                path: Config.options.background.wallpaperPath
            }

            WSection {
                WCard {
                    icon: "photo_library"
                    title: "Recent images"
                    description: Wallpapers.effectiveDirectory
                    WButton { buttonText: "Shuffle"; iconName: "shuffle"; onClicked: Wallpapers.randomFromCurrentFolder() }
                    WButton { buttonText: "Browse photos"; accent: true; onClicked: { GlobalStates.settingsOpen = false; GlobalStates.wallpaperSelectorOpen = true; } }
                }
                StyledText {
                    visible: bp.recent.length === 0
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    text: `No pictures in ${Wallpapers.effectiveDirectory} yet. Use "Browse photos" to pick one from another folder.`
                    wrapMode: Text.Wrap
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }
                GridLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    columns: 6
                    columnSpacing: 8
                    rowSpacing: 8
                    Repeater {
                        model: bp.recent
                        Item {
                            id: thumb
                            required property string modelData
                            readonly property bool current: Config.options.background.wallpaperPath === modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: width * 9 / 16
                            RoundedImage { anchors.fill: parent; anchors.margins: thumb.current ? 3 : 0; path: thumb.modelData; r: Appearance.rounding.verysmall }
                            Rectangle {
                                anchors.fill: parent
                                radius: Appearance.rounding.verysmall + 2
                                color: "transparent"
                                border.width: thumb.current ? 2 : (ma.containsMouse ? 1 : 0)
                                border.color: Appearance.colors.colPrimary
                            }
                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Wallpapers.select(thumb.modelData)
                            }
                        }
                    }
                }
            }

            WSection {
                title: "Slideshow"
                WCombo {
                    icon: "slideshow"
                    title: "Change picture every"
                    model: [0, 5, 10, 30, 60, 360, 1440].map(m => ({ displayName: m === 0 ? "Off" : m < 60 ? `${m} minutes` : m === 60 ? "1 hour" : m === 1440 ? "1 day" : `${m / 60} hours`, value: m * 60000 }))
                    currentValue: Config.options.wallpaperSelector.changeInterval
                    onSelected: v => Config.options.wallpaperSelector.changeInterval = v
                }
            }

            WSection {
                title: "Effects"
                WToggle {
                    icon: "blur_on"
                    title: "Blur the background"
                    checked: Config.options.background.showBlur
                    onToggled: v => Config.options.background.showBlur = v
                }
                WToggle {
                    icon: "3d_rotation"
                    title: "Parallax when switching workspaces"
                    checked: Config.options.background.parallax.enableWorkspace
                    onToggled: v => Config.options.background.parallax.enableWorkspace = v
                }
                WToggle {
                    icon: "fullscreen"
                    title: "Hide wallpaper behind fullscreen apps"
                    description: "Saves GPU while gaming or watching video"
                    checked: Config.options.background.hideWhenFullscreen
                    onToggled: v => Config.options.background.hideWhenFullscreen = v
                }
            }
        }
    }

    // ── Colors ─────────────────────────────────────────────────────
    Component {
        id: colors
        WPage {
            WSection {
                WCard {
                    icon: "contrast"
                    title: "Choose your mode"
                    description: "Change the colors that appear in the shell and your apps"
                    ModeButtons {}
                }
                WCombo {
                    icon: "palette"
                    title: "Color style"
                    description: "How colors are picked from your wallpaper"
                    model: [
                        { displayName: "Auto", value: "auto" },
                        { displayName: "Tonal spot (default)", value: "scheme-tonal-spot" },
                        { displayName: "Content", value: "scheme-content" },
                        { displayName: "Expressive", value: "scheme-expressive" },
                        { displayName: "Fidelity", value: "scheme-fidelity" },
                        { displayName: "Fruit salad", value: "scheme-fruit-salad" },
                        { displayName: "Monochrome", value: "scheme-monochrome" },
                        { displayName: "Neutral", value: "scheme-neutral" },
                        { displayName: "Rainbow", value: "scheme-rainbow" },
                    ]
                    currentValue: Config.options.appearance.palette.type
                    onSelected: v => { Config.options.appearance.palette.type = v; root.regenColors(); }
                }
                WCard {
                    icon: "colors"
                    title: "Current accent colors"
                    Repeater {
                        model: [Appearance.colors.colPrimary, Appearance.colors.colSecondary, Appearance.colors.colTertiary, Appearance.colors.colPrimaryContainer]
                        Rectangle {
                            required property color modelData
                            implicitWidth: 30; implicitHeight: 30; radius: 15
                            color: modelData
                            border.width: 1
                            border.color: Appearance.colors.colOutlineVariant
                        }
                    }
                }
            }
            WSection {
                title: "Transparency"
                WToggle {
                    icon: "opacity"
                    title: "Transparency effects"
                    description: "Windows and surfaces appear slightly see-through"
                    checked: Config.options.appearance.transparency.enable
                    onToggled: v => Config.options.appearance.transparency.enable = v
                }
                WToggle {
                    visible: Config.options.appearance.transparency.enable
                    icon: "auto_mode"
                    title: "Pick transparency automatically"
                    description: "Based on how busy your wallpaper is"
                    checked: Config.options.appearance.transparency.automatic
                    onToggled: v => Config.options.appearance.transparency.automatic = v
                }
                WSlider {
                    visible: Config.options.appearance.transparency.enable && !Config.options.appearance.transparency.automatic
                    icon: "layers"
                    title: "Panel transparency"
                    from: 0; to: 0.6; stepSize: 0.01
                    value: Config.options.appearance.transparency.backgroundTransparency
                    onMoved: v => Config.options.appearance.transparency.backgroundTransparency = Math.round(v * 100) / 100
                }
                WSlider {
                    visible: Config.options.appearance.transparency.enable && !Config.options.appearance.transparency.automatic
                    icon: "layers_clear"
                    title: "Content transparency"
                    from: 0; to: 0.9; stepSize: 0.01
                    value: Config.options.appearance.transparency.contentTransparency
                    onMoved: v => Config.options.appearance.transparency.contentTransparency = Math.round(v * 100) / 100
                }
            }
            WSection {
                title: "Apply colors to"
                WToggle {
                    icon: "apps"
                    title: "Apps (GTK & Qt)"
                    checked: Config.options.appearance.wallpaperTheming.enableQtApps
                    onToggled: v => { Config.options.appearance.wallpaperTheming.enableQtApps = v; root.regenColors(); }
                }
                WToggle {
                    icon: "terminal"
                    title: "Terminal"
                    checked: Config.options.appearance.wallpaperTheming.enableTerminal
                    onToggled: v => { Config.options.appearance.wallpaperTheming.enableTerminal = v; root.regenColors(); }
                }
                WToggle {
                    icon: "border_style"
                    title: "Show accent color on window borders"
                    checked: Config.options.hyprland.general.borderColor.enable
                    onToggled: v => {
                        Config.options.hyprland.general.borderColor.enable = v;
                        const e = HyprlandConfig.borderColorEntries();
                        if (Object.keys(e).length > 0) HyprlandConfig.setMany(e);
                        else HyprlandConfig.resetMany([HyprlandConfig.borderActiveKey, HyprlandConfig.borderInactiveKey]);
                    }
                }
            }
        }
    }

    // ── Taskbar ────────────────────────────────────────────────────
    Component {
        id: taskbar
        WPage {
            id: tp
            readonly property var layouts: Config.options.bar.layouts
            function shown(id) {
                return tp.layouts.leftLayout.includes(id) || tp.layouts.middleLayout.includes(id) || tp.layouts.rightLayout.includes(id);
            }
            function setShown(id, on, side) {
                const L = Config.options.bar.layouts;
                if (on) {
                    if (tp.shown(id)) return;
                    const key = side === "left" ? "leftLayout" : side === "middle" ? "middleLayout" : "rightLayout";
                    // keep the power button last on the right
                    const list = L[key].slice();
                    const pi = list.indexOf("powerButton");
                    if (key === "rightLayout" && pi !== -1) list.splice(pi, 0, id); else list.push(id);
                    L[key] = list;
                } else {
                    L.leftLayout = L.leftLayout.filter(w => w !== id);
                    L.middleLayout = L.middleLayout.filter(w => w !== id);
                    L.rightLayout = L.rightLayout.filter(w => w !== id);
                }
            }

            WSection {
                title: "Taskbar items"
                Repeater {
                    model: [
                        { id: "launcherButton", name: "Search", icon: "search", side: "left" },
                        { id: "workspaces", name: "Workspaces", icon: "steppers", side: "left" },
                        { id: "activeWindow", name: "Active window title", icon: "subtitles", side: "left" },
                        { id: "networkSpeed", name: "Network speed", icon: "network_check", side: "left" },
                        { id: "media", name: "Now playing", icon: "music_note", side: "left" },
                        { id: "visualizer", name: "Audio visualizer", icon: "graphic_eq", side: "left" },
                        { id: "clockWidget", name: "Clock", icon: "schedule", side: "middle" },
                        { id: "weatherBar", name: "Weather", icon: "partly_cloudy_day", side: "right" },
                        { id: "resources", name: "Resource monitor (CPU, RAM, GPU)", icon: "memory", side: "right" },
                        { id: "updatesCount", name: "Updates", icon: "deployed_code_update", side: "right" },
                        { id: "hyprlandXkbIndicator", name: "Keyboard layout", icon: "keyboard", side: "right" },
                        { id: "batteryIndicator", name: "Battery", icon: "battery_full", side: "right" },
                        { id: "powerButton", name: "Power button", icon: "power_settings_new", side: "right" },
                    ]
                    WToggle {
                        required property var modelData
                        icon: modelData.icon
                        title: modelData.name
                        checked: tp.shown(modelData.id)
                        onToggled: v => tp.setShown(modelData.id, v, modelData.side)
                    }
                }
                WLink { icon: "view_week"; title: "Rearrange taskbar items"; description: "Drag items between left, center and right"; action: () => { WState.go("advanced"); GlobalStates.openSettingsAt("bar"); } }
            }

            WSection {
                title: "System tray icons"
                WToggle {
                    icon: "inbox"
                    title: "System tray"
                    description: "Icons from background apps (Discord, Steam…)"
                    checked: tp.shown("sysTray")
                    onToggled: v => tp.setShown("sysTray", v, "right")
                }
                WToggle {
                    icon: "invert_colors"
                    title: "Monochrome tray icons"
                    checked: Config.options.tray.monochromeIcons
                    onToggled: v => Config.options.tray.monochromeIcons = v
                }
                WToggle {
                    icon: "toggle_on"
                    title: "Quick buttons"
                    description: "Screenshot, mic, dark mode and other shortcut buttons"
                    checked: tp.shown("utilButtons")
                    onToggled: v => tp.setShown("utilButtons", v, "right")
                }
                Repeater {
                    model: [
                        ["showScreenSnip", "Screenshot", "screenshot_region"],
                        ["showScreenRecord", "Screen recording", "screen_record"],
                        ["showColorPicker", "Color picker", "colorize"],
                        ["showMicToggle", "Microphone", "mic"],
                        ["showKeyboardToggle", "On-screen keyboard", "keyboard"],
                        ["showDarkModeToggle", "Dark mode", "dark_mode"],
                        ["showPerformanceProfileToggle", "Power mode", "bolt"],
                        ["showWallpaperToggle", "Wallpaper", "wallpaper"],
                    ]
                    WToggle {
                        required property var modelData
                        visible: tp.shown("utilButtons")
                        Layout.leftMargin: 28
                        minHeight: 52
                        icon: modelData[2]
                        title: modelData[1]
                        checked: Config.options.bar.utilButtons[modelData[0]]
                        onToggled: v => Config.options.bar.utilButtons[modelData[0]] = v
                    }
                }
                WToggle {
                    icon: "system_update"
                    title: "System icons"
                    description: "Network, Bluetooth, volume and notification status"
                    checked: tp.shown("systemIcons")
                    onToggled: v => tp.setShown("systemIcons", v, "right")
                }
            }

            WSection {
                title: "Taskbar behaviors"
                WCombo {
                    icon: "vertical_align_top"
                    title: "Taskbar position"
                    model: [
                        { displayName: "Top", value: "top" }, { displayName: "Bottom", value: "bottom" },
                        { displayName: "Left (vertical)", value: "left" }, { displayName: "Right (vertical)", value: "right" },
                    ]
                    currentValue: Config.options.bar.vertical ? (Config.options.bar.bottom ? "right" : "left") : (Config.options.bar.bottom ? "bottom" : "top")
                    onSelected: v => {
                        Config.options.bar.vertical = v === "left" || v === "right";
                        Config.options.bar.bottom = v === "bottom" || v === "right";
                    }
                }
                WToggle {
                    icon: "visibility_off"
                    title: "Automatically hide the taskbar"
                    checked: Config.options.bar.autoHide.enable
                    onToggled: v => Config.options.bar.autoHide.enable = v
                }
                WToggle {
                    visible: Config.options.bar.autoHide.enable
                    icon: "keyboard_command_key"
                    title: "Show the taskbar while holding Super"
                    checked: Config.options.bar.autoHide.showWhenPressingSuper.enable
                    onToggled: v => Config.options.bar.autoHide.showWhenPressingSuper.enable = v
                }
                WToggle {
                    icon: "rectangle"
                    title: "Taskbar background"
                    checked: Config.options.bar.showBackground
                    onToggled: v => Config.options.bar.showBackground = v
                }
                WToggle {
                    icon: "chat_bubble"
                    title: "Show tooltips"
                    checked: Config.options.bar.tooltips.enable
                    onToggled: v => Config.options.bar.tooltips.enable = v
                }
                WLink { icon: "style"; title: "Taskbar style"; description: "Corner style, grouping, frame, dynamic island"; action: () => { WState.go("advanced"); GlobalStates.openSettingsAt("bar"); } }
            }
        }
    }

    // ── Dock ───────────────────────────────────────────────────────
    Component {
        id: dock
        WPage {
            WSection {
                WToggle {
                    icon: "dock_to_bottom"
                    title: "Show the dock"
                    description: "App dock at the bottom of the screen"
                    checked: Config.options.dock.enable
                    onToggled: v => Config.options.dock.enable = v
                }
            }

            WSection {
                title: "Pinned apps"
                enabled: Config.options.dock.enable
                StyledText {
                    Layout.fillWidth: true
                    Layout.leftMargin: 2
                    Layout.bottomMargin: 2
                    text: "These appear on the dock in this order, left to right. Open apps that aren't pinned show after a separator."
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.Wrap
                }
                WAppListEditor {
                    apps: Config.options.dock.pinnedApps
                    addLabel: "Pin an app to the dock"
                    onEdited: l => Config.options.dock.pinnedApps = l
                }
            }

            WSection {
                title: "Dock behaviors"
                enabled: Config.options.dock.enable
                WToggle {
                    icon: "visibility_off"
                    title: "Automatically hide the dock"
                    description: "Hidden while a window is focused; reappears on the desktop or when you hover the bottom edge"
                    checked: !Config.options.dock.pinnedOnStartup
                    onToggled: v => Config.options.dock.pinnedOnStartup = !v
                }
                WToggle {
                    icon: "ads_click"
                    title: "Show the dock when the mouse touches the bottom edge"
                    checked: Config.options.dock.hoverToReveal
                    onToggled: v => Config.options.dock.hoverToReveal = v
                }
                WSlider {
                    icon: "photo_size_select_large"
                    title: "Dock size"
                    from: 44; to: 96; stepSize: 2
                    format: v => `${Math.round(v)} px`
                    value: Config.options.dock.height
                    onMoved: v => Config.options.dock.height = Math.round(v)
                }
                WToggle {
                    icon: "rectangle"
                    title: "Dock background"
                    checked: Config.options.dock.showBackground
                    onToggled: v => Config.options.dock.showBackground = v
                }
                WToggle {
                    icon: "invert_colors"
                    title: "Tint app icons to match colors"
                    checked: Config.options.dock.monochromeIcons
                    onToggled: v => Config.options.dock.monochromeIcons = v
                }
            }

            WSection {
                title: "Dock buttons"
                enabled: Config.options.dock.enable
                WToggle {
                    icon: "apps"
                    title: "All apps button"
                    checked: Config.options.dock.showAppsButton
                    onToggled: v => Config.options.dock.showAppsButton = v
                }
                WToggle {
                    icon: "push_pin"
                    title: "Pin button"
                    description: "Keeps the dock open until you unpin it"
                    checked: Config.options.dock.showPinButton
                    onToggled: v => Config.options.dock.showPinButton = v
                }
                WToggle {
                    icon: "music_note"
                    title: "Now playing"
                    description: "Media controls on the dock"
                    checked: Config.options.dock.showMedia
                    onToggled: v => Config.options.dock.showMedia = v
                }
            }

            WSection {
                title: "Hidden apps"
                enabled: Config.options.dock.enable
                StyledText {
                    Layout.fillWidth: true
                    Layout.leftMargin: 2
                    text: "Windows from these apps never appear on the dock. Matches the window class (regular expressions allowed)."
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.Wrap
                }
                Repeater {
                    model: Config.options.dock.ignoredAppRegexes
                    WCard {
                        required property string modelData
                        required property int index
                        minHeight: 52
                        icon: "visibility_off"
                        title: modelData
                        WButton {
                            buttonText: "Remove"
                            onClicked: Config.options.dock.ignoredAppRegexes = Config.options.dock.ignoredAppRegexes.filter((_, k) => k !== index)
                        }
                    }
                }
                WCard {
                    icon: "add"
                    title: "Hide an app"
                    Rectangle {
                        implicitWidth: 220; implicitHeight: 34
                        radius: Appearance.rounding.verysmall
                        color: Appearance.colors.colLayer3
                        border.width: hideInput.activeFocus ? 2 : 0
                        border.color: Appearance.colors.colPrimary
                        TextInput {
                            id: hideInput
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            verticalAlignment: Text.AlignVCenter
                            color: Appearance.colors.colOnLayer3
                            font.family: Appearance.font.family.main
                            font.pixelSize: Appearance.font.pixelSize.small
                            onAccepted: addHidden.clicked()
                        }
                    }
                    WButton {
                        id: addHidden
                        buttonText: "Add"
                        enabled: hideInput.text.trim().length > 0
                        onClicked: {
                            Config.options.dock.ignoredAppRegexes = Config.options.dock.ignoredAppRegexes.concat([hideInput.text.trim()]);
                            hideInput.text = "";
                        }
                    }
                }
            }
        }
    }

    // ── Start ──────────────────────────────────────────────────────
    Component {
        id: start
        WPage {
            WSection {
                title: "Pinned"
                StyledText {
                    Layout.fillWidth: true
                    Layout.leftMargin: 2
                    Layout.bottomMargin: 2
                    text: "Apps pinned to the top of the app launcher (Super)."
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.Wrap
                }
                WAppListEditor {
                    apps: Config.options.launcher.pinnedApps
                    addLabel: "Pin an app to Start"
                    onEdited: l => Config.options.launcher.pinnedApps = l
                }
            }
            WSection {
                title: "Search"
                WCombo {
                    icon: "travel_explore"
                    title: "Web search engine"
                    model: [
                        { displayName: "Google", value: "https://www.google.com/search?q=" },
                        { displayName: "Bing", value: "https://www.bing.com/search?q=" },
                        { displayName: "DuckDuckGo", value: "https://duckduckgo.com/?q=" },
                        { displayName: "Brave", value: "https://search.brave.com/search?q=" },
                        { displayName: "Startpage", value: "https://www.startpage.com/do/search?q=" },
                    ]
                    currentValue: Config.options.search.engineBaseUrl
                    onSelected: v => Config.options.search.engineBaseUrl = v
                }
                WToggle {
                    icon: "spellcheck"
                    title: "Forgiving search"
                    description: "Find apps even with typos (slower)"
                    checked: Config.options.search.sloppy
                    onToggled: v => Config.options.search.sloppy = v
                }
                WToggle {
                    icon: "bolt"
                    title: "Show actions without a prefix"
                    description: "Math, commands and web search appear as you type"
                    checked: Config.options.search.prefix.showDefaultActionsWithoutPrefix
                    onToggled: v => Config.options.search.prefix.showDefaultActionsWithoutPrefix = v
                }
            }
        }
    }

    // ── Super menu apps ────────────────────────────────────────────
    Component {
        id: appgrid
        WPage {
            WSection {
                WToggle {
                    icon: "apps"
                    title: "Show all installed apps"
                    description: Config.options.overview.appGridShowAll
                        ? "Every app shows, except the ones you hide below"
                        : "Only the apps you choose below show, in that order"
                    checked: Config.options.overview.appGridShowAll
                    onToggled: v => Config.options.overview.appGridShowAll = v
                }
            }

            WSection {
                visible: Config.options.overview.appGridShowAll
                title: "Hidden apps"
                StyledText {
                    Layout.fillWidth: true
                    Layout.leftMargin: 2
                    Layout.bottomMargin: 2
                    text: "These apps don't show in the Super menu app grid. You can still find them by typing in the search bar."
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.Wrap
                }
                WAppListEditor {
                    apps: Config.options.overview.appGridHidden
                    reorderable: false
                    addLabel: "Hide an app"
                    emptyText: "No hidden apps"
                    addedText: "Already hidden"
                    onEdited: l => Config.options.overview.appGridHidden = l
                }
            }

            WSection {
                visible: !Config.options.overview.appGridShowAll
                title: "Apps in the Super menu"
                StyledText {
                    Layout.fillWidth: true
                    Layout.leftMargin: 2
                    Layout.bottomMargin: 2
                    text: "Only these apps show in the app grid, in this order. Search still finds every app."
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.Wrap
                }
                WButton {
                    visible: Config.options.overview.appGridApps.length === 0
                    buttonText: "Start from all apps"
                    onClicked: Config.options.overview.appGridApps = AppSearch.list
                        .filter(e => !Config.options.overview.appGridHidden.some(h => h.toLowerCase() === e.id.toLowerCase() || h.toLowerCase() === (e.startupClass ?? "").toLowerCase()))
                        .map(e => e.startupClass && e.startupClass.length > 0 ? e.startupClass : e.id)
                }
                WAppListEditor {
                    apps: Config.options.overview.appGridApps
                    addLabel: "Add an app"
                    emptyText: "No apps chosen yet, so the app grid is empty"
                    addedText: "Already in the Super menu"
                    onEdited: l => Config.options.overview.appGridApps = l
                }
            }
        }
    }

    // ── Lock screen ────────────────────────────────────────────────
    Component {
        id: lockscreen
        WPage {
            WSection {
                title: "Appearance"
                WToggle {
                    icon: "blur_on"
                    title: "Blur the background"
                    checked: Config.options.lock.blur.enable
                    onToggled: v => Config.options.lock.blur.enable = v
                }
                WToggle {
                    icon: "schedule"
                    title: "Center the clock"
                    checked: Config.options.lock.centerClock
                    onToggled: v => Config.options.lock.centerClock = v
                }
                WToggle {
                    icon: "lock"
                    title: "Show \"Locked\" text"
                    checked: Config.options.lock.showLockedText
                    onToggled: v => Config.options.lock.showLockedText = v
                }
                WToggle {
                    icon: "music_note"
                    title: "Show media controls"
                    checked: Config.options.lock.showMedia
                    onToggled: v => Config.options.lock.showMedia = v
                }
                WToggle {
                    icon: "widgets"
                    title: "Show desktop widgets"
                    checked: Config.options.lock.showWidgets
                    onToggled: v => Config.options.lock.showWidgets = v
                }
                WToggle {
                    icon: "toolbar"
                    title: "Show toolbars"
                    description: "Power, keyboard layout and battery buttons"
                    checked: Config.options.lock.showToolbars
                    onToggled: v => Config.options.lock.showToolbars = v
                }
            }
            WSection {
                title: "Behavior"
                WToggle {
                    icon: "login"
                    title: "Lock at login"
                    checked: Config.options.lock.launchOnStartup
                    onToggled: v => Config.options.lock.launchOnStartup = v
                }
                WToggle {
                    icon: "key"
                    title: "Unlock the keyring when you sign in"
                    description: "Saved passwords (browser, Wi-Fi) become available after unlocking"
                    checked: Config.options.lock.security.unlockKeyring
                    onToggled: v => Config.options.lock.security.unlockKeyring = v
                }
                WToggle {
                    icon: "swap_horiz"
                    title: "Use hyprlock instead"
                    description: "Hyprland's own lock screen"
                    checked: Config.options.lock.useHyprlock
                    onToggled: v => Config.options.lock.useHyprlock = v
                }
                WLink { icon: "timer"; title: "Lock automatically after…"; description: "In Power › Screen and sleep"; page: "system"; sub: "power" }
            }
        }
    }

    // ── Desktop widgets ────────────────────────────────────────────
    Component {
        id: widgets
        WPage {
            WSection {
                WToggle {
                    icon: "lock"
                    title: "Lock widgets in place"
                    description: "Turn off to drag widgets around your desktop"
                    checked: Config.options.background.widgetsLocked
                    onToggled: v => Config.options.background.widgetsLocked = v
                }
            }
            WSection {
                title: "Widgets"
                Repeater {
                    model: [
                        ["clock", "Clock", "schedule"], ["calendar", "Calendar", "calendar_month"],
                        ["worldClock", "World clock", "public"], ["weather", "Weather", "partly_cloudy_day"],
                        ["notes", "Notes", "sticky_note_2"], ["todo", "To-do", "checklist"],
                        ["media", "Media player", "music_note"], ["resources", "System resources", "memory"],
                        ["timers", "Timers", "timer"], ["userCard", "User card", "account_box"],
                        ["visualizer", "Audio visualizer", "graphic_eq"], ["customText", "Custom text", "text_fields"],
                    ]
                    WToggle {
                        required property var modelData
                        icon: modelData[2]
                        title: modelData[1]
                        checked: Config.options.background.widgets[modelData[0]].enable
                        onToggled: v => Config.options.background.widgets[modelData[0]].enable = v
                    }
                }
                WLink { icon: "tune"; title: "Widget styles and placement"; action: () => { WState.go("advanced"); GlobalStates.openSettingsAt("desktop"); } }
            }
        }
    }

    // ── Sidebar (2026-10-03): on/off for the things we added to the right sidebar ──
    Component {
        id: sidebar
        WPage {
            WSection {
                title: "Right sidebar"
                WToggle {
                    icon: "wallpaper"
                    title: "Wallpaper Engine picker"
                    description: "Current wallpaper, mute, search and shuffle, and a grid of the installed Wallpaper Engine wallpapers"
                    checked: Config.options.sidebar.wallpaperEngineCard
                    onToggled: v => Config.options.sidebar.wallpaperEngineCard = v
                }
                WToggle {
                    icon: "battery_full"
                    title: "Device batteries"
                    description: "Battery levels of wireless mice, headphones, controllers and other devices, below the media controls"
                    checked: Config.options.sidebar.deviceBatteries
                    onToggled: v => Config.options.sidebar.deviceBatteries = v
                }
                WToggle {
                    icon: "swap_horiz"
                    title: "Switch to KDE Plasma button"
                    description: "A button in the sidebar header that switches to the KDE Plasma desktop"
                    checked: Config.options.sidebar.desktopSwitch
                    onToggled: v => Config.options.sidebar.desktopSwitch = v
                }
            }
        }
    }
}
