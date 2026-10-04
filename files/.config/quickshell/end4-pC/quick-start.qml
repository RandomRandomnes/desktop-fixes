//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

// Quick Start (2026-10-03, ours; not upstream): the "after installing" part of the quick start guide as a small app.
// Opens when the first-time setup wizard finishes, from the app menu (~/.local/share/applications/quick-start.desktop)
// and from Settings › Extras. The full guide with the USB/install steps is ~/.local/share/quick-start/index.html
// (also on the USB stick as clone/QUICK-START.html); keep the two in step.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.settingsW11

ApplicationWindow {
    id: root
    visible: true
    title: "Quick Start"
    width: 980
    height: 700
    minimumWidth: 720
    minimumHeight: 480
    color: Appearance.m3colors.m3background

    readonly property string home: Quickshell.env("HOME")
    Component.onCompleted: {
        MaterialThemeLoader.reapplyTheme()
        // QUICK_START_PAGE=<page id>: open at that page (testing)
        const start = root.pages.findIndex(pg => pg.id === Quickshell.env("QUICK_START_PAGE"))
        if (start > 0) root.page = start
    }

    // Pages: blocks are {p}, {h}, {keys: [..], what}, {row: title, text} (a card) and {open: label, cmd}.
    readonly property var pages: [
        { id: "welcome", title: "Welcome", icon: "waving_hand", heading: "Welcome", blocks: [
            { p: "Arch Linux with Hyprland and a custom version of illogical-impulse (not the official project), set up to work like Windows." },
            { row: "Super key", text: "The Windows key. Most shortcuts use it; Super+/ lists all of them" },
            { row: "Settings", text: "Super+I" },
            { row: "This guide", text: "Super, then type \"Quick Start\"; or Settings › Extras" },
        ]},
        { id: "keys", title: "Shortcuts", icon: "keyboard_command_key", heading: "Keyboard shortcuts", blocks: [
            { h: "Windows and workspaces" },
            { keys: ["Super"], what: "Application menu and search" },
            { keys: ["Super", "Tab"], what: "All workspaces and windows" },
            { keys: ["Super", "Q"], what: "Close window" },
            { keys: ["Super", "D"], what: "Maximize or restore window" },
            { keys: ["Super", "1…0"], what: "Switch workspace" },
            { keys: ["Super", "L"], what: "Lock" },
            { h: "Apps" },
            { keys: ["Super", "W"], what: "Browser" },
            { keys: ["Super", "E"], what: "Files" },
            { keys: ["Super", "Enter"], what: "Terminal" },
            { keys: ["Super", "I"], what: "Settings" },
            { h: "Shell" },
            { keys: ["Super", "A"], what: "Left sidebar: AI chat, translator" },
            { keys: ["Super", "N"], what: "Right sidebar: quick settings, notifications" },
            { keys: ["Super", "V"], what: "Clipboard history" },
            { keys: ["Super", "."], what: "Emoji" },
            { keys: ["Super", "Shift", "S"], what: "Screenshot of an area" },
            { keys: ["Ctrl", "Super", "T"], what: "Change wallpaper" },
            { keys: ["Shift", "Super", "Alt", "/"], what: "Setup assistant" },
            { keys: ["Super", "/"], what: "List every shortcut" },
        ]},
        { id: "windows", title: "Windows", icon: "select_window", heading: "Windows", blocks: [
            { row: "Red", text: "Close" },
            { row: "Green", text: "Maximize or restore (or double-click the title bar)" },
            { row: "Yellow", text: "Minimize to the dock; click the dock icon to restore" },
            { p: "For tiling instead of floating windows, turn off Windows-style windows in Settings › Extras." },
        ]},
        { id: "settings", title: "Settings and profiles", icon: "settings", heading: "Settings and profiles", blocks: [
            { p: "Extras has one switch per added feature; off restores the standard illogical-impulse behavior." },
            { row: "Live system graphs", text: "CPU, GPU and RAM on the taskbar, with a details popup. GPUs: AMD, NVIDIA (proprietary driver), Intel" },
            { row: "Wallpaper Engine background", text: "Off by default; see Extras" },
            { row: "Use a profile file", text: "Apply a setup profile (appearance + feature switches). Current settings are backed up first" },
            { row: "Share my setup", text: "Save the current setup as a profile file" },
            { p: "Profiles never change the dock or the app grid and never turn on Wallpaper Engine. More profiles: github.com/RandomRandomnes/desktop-fixes" },
            { open: "Open Settings", cmd: ["qs", "-c", "end4-pC", "ipc", "call", "settings", "open"] },
        ]},
        { id: "apps", title: "Applications", icon: "apps", heading: "Applications", blocks: [
            { p: "Firefox is preinstalled. Add more with the setup assistant (Shift+Super+Alt+/ › Apps), or in a terminal: sudo pacman -S <package>, or flatpak install flathub <app-id>." },
            { row: "Gaming pack", text: "Steam, MangoHud, GameMode, ProtonUp-Qt" },
            { row: "Productivity pack", text: "LibreOffice, Thunderbird, Obsidian, Code - OSS, KeePassXC" },
        ]},
        { id: "updates", title: "Updates", icon: "system_update_alt", heading: "Updates", blocks: [
            { p: "The taskbar's update button shows waiting updates. One click installs system updates and, if enabled, custom bug fixes. Settings › Update shows the installed version." },
            { row: "Bug fixes (1.3, 1.31, …)", text: "Install with regular updates. Revert the last one: Settings › Update › Undo last" },
            { row: "Major versions (2, 3, …)", text: "Never automatic. Settings › Update explains the changes and the risk; upgrades only on confirmation" },
            { row: "Desktop broken after an update", text: "Settings › Update › Run health check" },
        ]},
        { id: "startup", title: "Boot menu", icon: "restart_alt", heading: "Boot menu and Windows", blocks: [
            { p: "The system starts directly, without a menu. Windows starts from the firmware's one-time boot menu (F8, F11 or F12 at power-on, depending on the PC)." },
            { row: "Add a menu", text: "Setup assistant › Drivers and updates › Startup, or boot-loader use <option> in a terminal" },
            { row: "rEFInd", text: "Graphical; finds Windows on any disk" },
            { row: "systemd-boot", text: "Simple; lists Windows only on the same EFI partition" },
            { row: "GRUB", text: "Text menu; only with Secure Boot off" },
            { row: "No menu (direct)", text: "Back to starting without a menu. Switching deletes nothing" },
        ]},
        { id: "extras", title: "Extras", icon: "auto_awesome", heading: "Extras", blocks: [
            { row: "Wallpaper Engine", text: "Install Steam and Wallpaper Engine (bought on Steam), then turn on Settings › Extras › Wallpaper Engine background. A picker appears in the right sidebar" },
            { row: "KDE Plasma", text: "Installed alongside. Turn on the KDE switch in Settings › Extras; switch from the right sidebar or the power menu" },
            { row: "Encrypted disk", text: "~/WELCOME-clone.txt has the two commands that let the TPM unlock the disk at startup" },
        ]},
        { id: "help", title: "Troubleshooting", icon: "help", heading: "Troubleshooting", blocks: [
            { row: "Black screen (NVIDIA)", text: "Ctrl+Alt+F2, log in, sudo pacman -S nvidia-open-dkms nvidia-utils linux-headers, reboot" },
            { row: "Black screen after an update", text: "Ctrl+Alt+F2, log in, sudo pacman -Syu, reboot" },
            { row: "Desktop broken after an update", text: "Settings › Update › Run health check; for a bug fix, Undo last" },
            { row: "Text too small or too large", text: "Settings › System › Display › Scale" },
            { row: "No Wi-Fi", text: "Right sidebar (Super+N) › Wi-Fi" },
            { row: "No GPU graph", text: "Settings › Extras › Live system graphs" },
            { row: "Install on another PC", text: "The full guide (USB stick, installation) is clone/QUICK-START.html on the stick" },
            { open: "Open the full guide", cmd: ["xdg-open", Quickshell.env("HOME") + "/.local/share/quick-start/index.html"] },
        ]},
    ]
    property int page: 0
    readonly property var cur: pages[page]

    component KeyCap: Rectangle {
        required property string label
        implicitWidth: Math.max(34, keyText.implicitWidth + 18)
        implicitHeight: 30
        radius: 6
        color: Appearance.colors.colLayer2
        border.width: 1
        border.color: Appearance.colors.colOutlineVariant
        StyledText {
            id: keyText
            anchors.centerIn: parent
            text: parent.label
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer2
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {   // page list
            Layout.fillHeight: true
            Layout.preferredWidth: 230
            color: Appearance.colors.colLayer1
            ColumnLayout {
                anchors { fill: parent; margins: 20 }
                spacing: 4
                RowLayout {
                    Layout.bottomMargin: 12
                    spacing: 10
                    MaterialSymbol { text: "menu_book"; iconSize: 24; fill: 1; color: Appearance.colors.colPrimary }
                    StyledText {
                        text: "Quick Start"
                        font.pixelSize: Appearance.font.pixelSize.larger
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer1
                    }
                }
                Repeater {
                    model: root.pages
                    RippleButton {
                        id: navButton
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 36
                        buttonRadius: Appearance.rounding.small
                        colBackground: index === root.page ? Appearance.colors.colLayer2 : "transparent"
                        onClicked: root.page = index
                        contentItem: RowLayout {
                            spacing: 12
                            MaterialSymbol {
                                Layout.leftMargin: 6
                                text: navButton.modelData.icon
                                iconSize: 20
                                fill: navButton.index === root.page ? 1 : 0
                                color: navButton.index === root.page ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: navButton.modelData.title
                                font.weight: navButton.index === root.page ? Font.DemiBold : Font.Normal
                                color: Appearance.colors.colOnLayer1
                            }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }

        ColumnLayout {   // current page
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 28
            spacing: 14

            StyledText {
                text: root.cur.heading
                font.pixelSize: Appearance.font.pixelSize.hugeass + 6
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
            }

            WPage {
                id: body
                Layout.fillWidth: true
                Layout.fillHeight: true
                maxContentWidth: 760
                Repeater {
                    model: root.cur.blocks
                    Loader {
                        id: block
                        required property var modelData
                        Layout.fillWidth: true
                        sourceComponent: modelData.p !== undefined ? para : modelData.h !== undefined ? heading
                            : modelData.keys !== undefined ? keys : modelData.row !== undefined ? card : openButton
                        Component {
                            id: para
                            StyledText {
                                wrapMode: Text.WordWrap
                                text: block.modelData.p
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colOnLayer0
                            }
                        }
                        Component {
                            id: heading
                            StyledText {
                                topPadding: 8
                                text: block.modelData.h
                                font.pixelSize: Appearance.font.pixelSize.large
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnLayer0
                            }
                        }
                        Component {
                            id: keys
                            RowLayout {
                                spacing: 6
                                Item {   // keys column, fixed width so descriptions line up
                                    Layout.preferredWidth: 230
                                    implicitHeight: 30
                                    Row {
                                        spacing: 6
                                        Repeater {
                                            model: block.modelData.keys
                                            Row {
                                                required property var modelData
                                                required property int index
                                                spacing: 6
                                                StyledText {
                                                    visible: index > 0
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "+"
                                                    color: Appearance.colors.colSubtext
                                                }
                                                KeyCap { label: modelData }
                                            }
                                        }
                                    }
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    text: block.modelData.what
                                    color: Appearance.colors.colOnLayer0
                                }
                            }
                        }
                        Component {
                            id: card
                            WCard {
                                title: block.modelData.row
                                description: block.modelData.text
                            }
                        }
                        Component {
                            id: openButton
                            RowLayout {
                                WButton {
                                    accent: true
                                    buttonText: block.modelData.open
                                    onClicked: Quickshell.execDetached(block.modelData.cmd)
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                WButton {
                    visible: root.page > 0
                    buttonText: "Back"
                    onClicked: root.page--
                }
                Item { Layout.fillWidth: true }
                WButton {
                    accent: true
                    buttonText: root.page < root.pages.length - 1 ? "Next" : "Done"
                    onClicked: root.page < root.pages.length - 1 ? root.page++ : Qt.quit()
                }
            }
        }
    }
}
