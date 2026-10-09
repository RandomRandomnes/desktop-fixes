pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.settingsW11

// Desktop right-click menu, Windows 11 style (Phoenix, 2026-10-09). Replaces illogical-impulse's card menu (wallpaper
// carousel + Material submenus): a compact list that opens at the cursor, a "View" submenu with check marks for the
// desktop widgets, and links into the Windows-style Settings instead of the big inline panels.
Scope {
    id: root

    function openCentered(shouldOpen) {
        if (!shouldOpen) {
            GlobalStates.desktopMenuOpen = false
            return
        }
        const focusedName = Hyprland.focusedMonitor?.name
        const screen = Quickshell.screens.find(s => s.name === focusedName) ?? Quickshell.screens[0]
        GlobalStates.desktopMenuScreen = screen
        GlobalStates.desktopMenuX = screen.width / 2
        GlobalStates.desktopMenuY = screen.height / 2
        GlobalStates.desktopMenuOpen = true
    }

    // Wallpaper Engine runs in the tray (no single-instance lock: starting it again would run a second copy), so
    // its window is opened through the tray item; it's only started when it isn't running.
    function openWallpaperEngine() {
        root.close()
        const item = SystemTray.items.values.find(i => `${i.tooltipTitle ?? ""} ${i.title ?? ""}`.includes("Wallpaper Engine"))
        if (item) item.activate()
        else Quickshell.execDetached([`${Quickshell.env("HOME")}/.local/bin/linux-wallpaper-engine-ux`])
        bringEngineTimer.tries = 0
        bringEngineTimer.restart()
    }

    // Like Windows: the app's window comes to the workspace you're on (it may already be open on another one)
    Timer {
        id: bringEngineTimer
        property int tries: 0
        interval: 400
        onTriggered: {
            const win = HyprlandData.windowList.find(w => w.class === "Linux Wallpaper Engine")
            const ws = Hyprland.focusedMonitor?.activeWorkspace?.id
            if (win && ws !== undefined) {
                if (win.workspace.id !== ws)
                    Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${ws}, follow = false, window = "address:${win.address}" })`)
                Hyprland.dispatch(`hl.dsp.focus({ window = "address:${win.address}" })`)
            } else if (++tries < 15) {
                restart()   // the app can take a few seconds to start
            }
        }
    }

    function close() {
        GlobalStates.desktopMenuOpen = false
    }

    function openSettings(page, sub) {
        root.close()
        WState.go(page, sub ?? "")
        GlobalStates.settingsOpen = true
    }

    // Other pictures in the current wallpaper's folder, for "Next desktop background"
    FolderListModel {
        id: wallpaperFolder
        folder: {
            const wallPath = Config.options.background.wallpaperPath
            if (!wallPath || wallPath.length === 0) return ""
            return "file://" + wallPath.substring(0, wallPath.lastIndexOf("/"))
        }
        showDirs: false
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp"]
    }

    function nextWallpaper() {
        const current = FileUtils.trimFileProtocol(Config.options.background.wallpaperPath)
        const all = []
        for (let i = 0; i < wallpaperFolder.count; i++) {
            const fp = FileUtils.trimFileProtocol(wallpaperFolder.get(i, "filePath").toString())
            if (fp !== current) all.push(fp)
        }
        if (all.length === 0) return
        Wallpapers.select(all[Math.floor(Math.random() * all.length)], Appearance.m3colors.darkmode)
    }

    Loader {
        active: GlobalStates.desktopMenuOpen
        sourceComponent: PanelWindow {
            id: menuWindow

            screen: GlobalStates.desktopMenuScreen ?? Quickshell.screens[0]
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:desktopMenu"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            anchors { top: true; bottom: true; left: true; right: true }

            property bool viewOpen: false
            property real viewAnchorY: 0

            Timer {
                id: viewCloseTimer
                interval: 300
                // stays open while the pointer is on "View" or on the submenu itself
                onTriggered: menuWindow.viewOpen = (viewLoader.item?.hovered ?? false) || viewRow.hovered
            }

            // A click anywhere outside the menu closes it
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: root.close()
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: root.close()
            }

            // Main menu: top-left corner at the cursor, flipped when it would leave the screen
            DeskMenuFrame {
                id: mainMenu
                x: GlobalStates.desktopMenuX + width + 4 > menuWindow.width
                    ? Math.max(4, GlobalStates.desktopMenuX - width) : GlobalStates.desktopMenuX
                y: GlobalStates.desktopMenuY + implicitHeight + 4 > menuWindow.height
                    ? Math.max(4, GlobalStates.desktopMenuY - implicitHeight) : GlobalStates.desktopMenuY

                DeskMenuRow {
                    id: viewRow
                    icon: "view_module"
                    text: Translation.tr("View")
                    submenu: true
                    active: menuWindow.viewOpen
                    onHoverChanged: hovered => {
                        if (hovered) {
                            viewCloseTimer.stop()
                            menuWindow.viewAnchorY = mainMenu.y + viewRow.mapToItem(mainMenu, 0, 0).y - 4
                            menuWindow.viewOpen = true
                        } else {
                            viewCloseTimer.restart()
                        }
                    }
                    onTriggered: menuWindow.viewOpen = true
                }
                DeskMenuRow {
                    visible: wallpaperFolder.count > 1 && !GlobalStates.wallpaperEngineRunning
                    icon: "wallpaper_slideshow"
                    text: Translation.tr("Next desktop background")
                    onTriggered: { root.nextWallpaper(); root.close() }
                }
                // Wallpaper Engine when that feature is on, otherwise a picture file picker
                DeskMenuRow {
                    readonly property bool engine: Config.options.extras.wallpaperEngine
                    icon: engine ? "animated_images" : "image"
                    text: engine ? Translation.tr("Wallpaper Engine") : Translation.tr("Choose wallpaper…")
                    onTriggered: {
                        if (engine) {
                            root.openWallpaperEngine()
                        } else {
                            root.close()
                            Wallpapers.openFallbackPicker(Appearance.m3colors.darkmode)
                        }
                    }
                }

                DeskMenuSeparator {}

                DeskMenuRow {
                    icon: "stacks"
                    text: Translation.tr("DropShelf")
                    hint: DropShelf.items.length > 0 ? `${DropShelf.items.length}` : ""
                    onTriggered: {
                        root.close()
                        GlobalStates.dropShelfX = GlobalStates.desktopMenuX
                        GlobalStates.dropShelfY = GlobalStates.desktopMenuY
                        GlobalStates.dropShelfOpen = true
                    }
                }
                DeskMenuRow {
                    icon: "terminal"
                    text: Translation.tr("Open in Terminal")
                    onTriggered: {
                        root.close()
                        Quickshell.execDetached(["kitty", "--directory", Quickshell.env("HOME")])
                    }
                }

                DeskMenuSeparator {}

                DeskMenuRow {
                    icon: "desktop_windows"
                    text: Translation.tr("Display settings")
                    onTriggered: root.openSettings("system", "display")
                }
                DeskMenuRow {
                    icon: "brush"
                    text: Translation.tr("Personalize")
                    onTriggered: root.openSettings("personalization")
                }
                DeskMenuRow {
                    icon: "settings"
                    text: Translation.tr("Settings")
                    onTriggered: root.openSettings("home")
                }
            }

            // "View" submenu: desktop widgets with check marks, like Windows' View menu
            Loader {
                id: viewLoader
                active: menuWindow.viewOpen
                sourceComponent: DeskMenuFrame {
                    id: viewMenu
                    x: mainMenu.x + mainMenu.width + width - 2 > menuWindow.width
                        ? mainMenu.x - width + 2 : mainMenu.x + mainMenu.width - 2
                    y: Math.max(4, Math.min(menuWindow.viewAnchorY, menuWindow.height - implicitHeight - 4))

                    onHoveredChanged: hovered ? viewCloseTimer.stop() : viewCloseTimer.restart()

                    Repeater {
                        model: DesktopWidgets.menuItems
                        delegate: DeskMenuRow {
                            required property var modelData
                            checkable: true
                            text: modelData.name
                            checked: Config.options.background.widgets[modelData.key].enable
                            onTriggered: DesktopWidgets.setEnabled(modelData.key, !checked)
                        }
                    }

                    DeskMenuSeparator {}

                    DeskMenuRow {
                        checkable: true
                        text: Translation.tr("Lock widget positions")
                        checked: Config.options.background.widgetsLocked
                        onTriggered: Config.options.background.widgetsLocked = !checked
                    }
                    DeskMenuRow {
                        checkable: true
                        text: Translation.tr("Widget shadows")
                        checked: Config.options.background.widgets.shadow
                        onTriggered: Config.options.background.widgets.shadow = !checked
                    }
                    DeskMenuRow {
                        checkable: true
                        text: Translation.tr("Blur behind widgets")
                        checked: Config.options.background.widgets.blurWidgets
                        onTriggered: Config.options.background.widgets.blurWidgets = !checked
                    }

                    DeskMenuSeparator {}

                    DeskMenuRow {
                        icon: "widgets"
                        text: Translation.tr("Widget settings")
                        onTriggered: root.openSettings("personalization", "widgets")
                    }
                }
            }
        }
    }
}
