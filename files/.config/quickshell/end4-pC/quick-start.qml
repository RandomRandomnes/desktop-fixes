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
    Component.onCompleted: MaterialThemeLoader.reapplyTheme()

    // Pages: blocks are {p}, {h}, {keys: [..], what}, {row: title, text} (a card) and {open: label, cmd}.
    readonly property var pages: [
        { id: "welcome", title: "Welcome", icon: "waving_hand", heading: "Welcome", blocks: [
            { p: "This system runs Arch Linux with the Hyprland desktop and the illogical-impulse shell, configured to work similarly to Windows." },
            { p: "These pages describe the basics. The guide can be opened again at any time from the application menu (press Super and type \"Quick Start\") or from Settings › Extras." },
            { row: "The Super key", text: "Super is the Windows key. Most keyboard shortcuts use it." },
            { row: "Settings", text: "Super+I opens Settings, where most options can be changed." },
        ]},
        { id: "keys", title: "Shortcuts", icon: "keyboard_command_key", heading: "Keyboard shortcuts", blocks: [
            { h: "Everyday" },
            { keys: ["Super"], what: "Open the application menu and search" },
            { keys: ["Super", "Tab"], what: "Show all workspaces and windows" },
            { keys: ["Super", "Q"], what: "Close the active window" },
            { keys: ["Super", "D"], what: "Maximize or restore the active window" },
            { keys: ["Super", "L"], what: "Lock the screen" },
            { keys: ["Super", "I"], what: "Open Settings" },
            { h: "Apps" },
            { keys: ["Super", "W"], what: "Web browser" },
            { keys: ["Super", "E"], what: "Files" },
            { keys: ["Super", "Enter"], what: "Terminal" },
            { h: "Shell" },
            { keys: ["Super", "A"], what: "Left sidebar: AI chat, translator" },
            { keys: ["Super", "N"], what: "Right sidebar: quick settings, notifications" },
            { keys: ["Super", "V"], what: "Clipboard history" },
            { keys: ["Super", "."], what: "Emoji" },
            { keys: ["Super", "Shift", "S"], what: "Screenshot of an area" },
            { keys: ["Ctrl", "Super", "T"], what: "Change the wallpaper" },
            { keys: ["Super", "/"], what: "Show all shortcuts" },
        ]},
        { id: "windows", title: "Windows", icon: "select_window", heading: "Windows", blocks: [
            { p: "Windows float freely, as on Windows, and have a title bar with three buttons." },
            { row: "Red", text: "Close the window" },
            { row: "Green", text: "Maximize or restore. Double-clicking the title bar has the same effect" },
            { row: "Yellow", text: "Minimize to the dock. Click the application in the dock to restore it" },
            { p: "For tiling, where windows fill the screen side by side, turn off Windows-style windows in Settings › Extras." },
        ]},
        { id: "settings", title: "Settings and Extras", icon: "settings", heading: "Settings and Extras", blocks: [
            { p: "Settings (Super+I) is organized like Windows Settings: System, Bluetooth & devices, Network, Personalization, Apps and further categories." },
            { p: "Extras contains a switch for each additional feature of this system. Turning a feature off restores the standard illogical-impulse behavior." },
            { row: "Windows-style windows, Minimize to the dock", text: "Floating windows with title bars" },
            { row: "Wallpaper Engine background", text: "Animated wallpapers (see Extras in this guide)" },
            { row: "Live system graphs", text: "CPU, GPU and RAM graphs on the taskbar with a detailed popup" },
            { row: "Use a profile file, Share my setup", text: "Apply a setup profile from a file, or save the current setup as a file" },
            { row: "Run the first-time setup again", text: "Opens the setup wizard" },
            { open: "Open Settings", cmd: ["qs", "-c", "end4-pC", "ipc", "call", "settings", "open"] },
        ]},
        { id: "apps", title: "Applications", icon: "apps", heading: "Applications", blocks: [
            { p: "Press Super and type to find an application. Firefox is installed by default; other applications are installed during setup." },
            { p: "To install additional applications later, run the setup again (Settings › Extras) and open its Applications step, or use pacman or flatpak in a terminal." },
            { row: "Gaming", text: "The Gaming pack installs Steam, MangoHud (FPS overlay), GameMode and ProtonUp-Qt" },
            { row: "Productivity", text: "The Productivity pack installs LibreOffice, Thunderbird, Obsidian, Code - OSS and KeePassXC" },
        ]},
        { id: "updates", title: "Updates", icon: "system_update_alt", heading: "Updates", blocks: [
            { p: "The update button on the taskbar shows the number of pending updates. One click updates the system, the desktop and, if enabled, the custom bug fixes. The administrator password is requested once." },
            { row: "Bug fixes", text: "Versions such as 1.1 or 1.12 are installed with regular updates" },
            { row: "New major versions", text: "Versions 2, 3 and later are never installed automatically. Settings › Update describes the changes and warns that they may alter or break parts of the current setup. Upgrading requires confirmation" },
            { row: "Undo", text: "To revert the most recent bug fix, use Settings › Update › Undo last" },
        ]},
        { id: "extras", title: "Extras", icon: "auto_awesome", heading: "Extras", blocks: [
            { row: "Wallpaper Engine", text: "Requires Steam and Wallpaper Engine (purchased on Steam). Then enable Settings › Extras › Wallpaper Engine background; a wallpaper picker appears in the right sidebar" },
            { row: "KDE Plasma", text: "The KDE Plasma desktop is also installed. Enable the KDE switch in Settings › Extras to use it from the right sidebar or the power menu" },
            { row: "Encrypted disk", text: "WELCOME-clone.txt in the home folder lists the two commands that allow the TPM chip to unlock the disk at startup" },
            { row: "Share the setup", text: "Settings › Extras › Share my setup saves the appearance, features and application list to one file" },
        ]},
        { id: "help", title: "Troubleshooting", icon: "help", heading: "Troubleshooting", blocks: [
            { row: "Text and elements are too small or too large", text: "Settings › System › Display › Scale" },
            { row: "No Wi-Fi", text: "Right sidebar (Super+N) › Wi-Fi" },
            { row: "Black screen after an update", text: "Press Ctrl+Alt+F2, log in, run sudo pacman -Syu, then restart" },
            { row: "The desktop misbehaves after an update", text: "Settings › Update › Run health check, or Undo last for a bug fix" },
            { row: "Starting Windows or another system", text: "The firmware's one-time boot menu at power-on (often F8, F11 or F12), or add a boot menu: setup assistant › Drivers and updates › Startup" },
            { row: "Installing on another computer", text: "The full guide, including USB preparation and installation, is on the USB drive (clone/QUICK-START.html)" },
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
