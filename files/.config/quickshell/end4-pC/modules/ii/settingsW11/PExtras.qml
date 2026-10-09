import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Extras (2026-10-03, ours): every custom feature of this setup with an on/off switch. Off falls back to the stock
// illogical-impulse behaviour. The switches are Config.options.extras (+ a few sidebar ones); services/Extras.qml
// applies the Hyprland side through ~/.local/bin/setup-features. Setup profiles set the same switches.
WPage {
    id: page
    readonly property var ex: Config.options.extras

    component Switch: WToggle {
        required property string key
        property var group: Config.options.extras
        checked: group[key]
        onToggled: v => group[key] = v
    }

    // ── Setup profiles (~/.local/bin/setup-profile) ──
    property string confirmId: ""       // profile waiting for a second click
    property string status: ""
    property string importPath: ""
    property var importApps: []         // apps the applied profile file lists (offered for install)

    function runProfile(args, doneText) {
        page.status = "Working…"
        profileProc.doneText = doneText
        profileProc.command = [`${Quickshell.env("HOME")}/.local/bin/setup-profile`].concat(args)
        profileProc.running = true
    }
    function askApply(id) {
        if (page.confirmId === id) {
            page.confirmId = ""
            page.runProfile(["apply", id, "--yes"], "Profile applied. Your previous settings were backed up.")
        } else {
            page.confirmId = id
            confirmTimer.restart()
        }
    }

    Timer { id: confirmTimer; interval: 4000; onTriggered: page.confirmId = "" }
    Process {
        id: profileProc
        property string doneText: ""
        stderr: StdioCollector { id: profileErr }
        onExited: (code, status) => {
            page.status = code === 0 ? doneText : `Something went wrong: ${profileErr.text.trim()}`
            if (code === 0 && command[1] === "apply") { appsOfProfile.command = [command[0], "apps", command[2]]; appsOfProfile.running = true }
        }
    }
    Process {
        id: appsOfProfile
        stdout: StdioCollector { onStreamFinished: page.importApps = text.split("\n").filter(l => l.trim() !== "") }
    }
    Process {
        id: importPicker
        command: [`${Quickshell.env("HOME")}/.local/bin/phoenix-file-picker`, "open", Quickshell.env("HOME"), "Setup profiles", "*.json"]
        stdout: StdioCollector { onStreamFinished: if (text.trim() !== "") page.importPath = text.trim() }
    }
    Process {
        id: exportPicker
        command: [`${Quickshell.env("HOME")}/.local/bin/phoenix-file-picker`, "save", `${Quickshell.env("HOME")}/my-setup.json`, "Setup profiles", "*.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                let f = text.trim()
                if (f === "") return
                if (!f.endsWith(".json")) f += ".json"
                page.runProfile(["export", f, "--name", `${SystemInfo.username}'s setup`], `Saved your setup to ${f}. Share that file; it can be applied here or chosen in the installer.`)
            }
        }
    }

    WSection {
        title: "Setup profiles"
        WCard {
            icon: "menu_book"
            title: "Quick Start"
            description: "A short guide to keyboard shortcuts, windows, updates, additional features and troubleshooting"
            WButton {
                buttonText: "Open"
                onClicked: Quickshell.execDetached(["qs", "-p", `${Quickshell.env("HOME")}/.config/quickshell/end4-pC/quick-start.qml`])
            }
        }
        WCard {
            icon: "assistant"
            title: "Run the first-time setup again"
            description: "Opens the setup assistant: network, Bluetooth, setup profile, applications and updates"
            WButton {
                buttonText: "Open"
                onClicked: Quickshell.execDetached(["bash", "-c", `mkdir -p ~/.local/state/setup-wizard && touch ~/.local/state/setup-wizard/pending && qs -p ${Quickshell.shellPath("setup-wizard.qml")}`])
            }
        }
        WCard {
            icon: "upload_file"
            title: page.importPath === "" ? "Use a profile file" : page.importPath.split("/").pop()
            description: page.importPath === "" ? "Apply a setup profile from a file (.json)" : page.importPath
            WButton {
                buttonText: "Choose file…"
                onClicked: importPicker.running = true
            }
            WButton {
                visible: page.importPath !== ""
                buttonText: page.confirmId === page.importPath ? "Click again to apply" : "Apply"
                accent: page.confirmId === page.importPath
                onClicked: page.askApply(page.importPath)
            }
        }
        WCard {
            icon: "ios_share"
            title: "Share my setup"
            description: "Save the current setup as a profile file. It can be applied during the first-time setup or on this page"
            WButton {
                buttonText: "Save as file…"
                onClicked: exportPicker.running = true
            }
        }
        WCard {
            visible: page.status !== ""
            icon: "check_circle"
            title: page.status
        }
        WCard {
            visible: page.importApps.length > 0
            icon: "download"
            title: "This profile includes applications"
            description: page.importApps.join(", ") + ". Applications that are already installed are skipped"
            WButton {
                accent: true
                buttonText: "Install"
                onClicked: Quickshell.execDetached(["kitty", "--title", "Installing apps", "--",
                    `${Quickshell.env("HOME")}/.local/bin/setup-apps`, "install", ...page.importApps])
            }
        }
    }

    WSection {
        title: "Windows"
        Switch {
            key: "windowsStyle"
            icon: "select_window"
            title: "Windows-style windows"
            description: "New windows float instead of tiling and have a title bar (close, maximize, minimize). When off: standard tiling without title bars"
        }
        Switch {
            key: "minimizeToDock"
            icon: "minimize"
            title: "Minimize to the dock"
            description: "The minimize button hides a window; clicking it in the dock restores it. Turning this off restores all minimized windows"
        }
        Switch {
            key: "workspaceGroups"
            icon: "view_carousel"
            title: "Own workspaces for each screen"
            description: "The first screen uses workspaces 1-10, the second 11-20, the third 21-30. Super+1…0 work on the screen you're on"
        }
    }

    WSection {
        title: "Desktop"
        Switch {
            key: "wallpaperEngine"
            icon: "animated_images"
            title: "Wallpaper Engine background"
            description: "Animated Wallpaper Engine wallpapers (requires Wallpaper Engine from Steam). When off: a static picture wallpaper"
        }
        Switch {
            key: "appGrid"
            icon: "apps"
            title: "App grid in the Super menu"
            description: "Shows all applications below the workspaces when Super is pressed"
        }
        WLink {
            visible: page.ex.appGrid
            icon: "grid_view"
            title: "Choose the applications in the grid"
            page: "personalization"; sub: "appgrid"
        }
    }

    WSection {
        title: "Taskbar and menus"
        Switch {
            key: "resourceGraphs"
            icon: "monitoring"
            title: "Live system graphs on the taskbar"
            description: "CPU, GPU and memory graphs with clock speeds, temperatures and power, plus a detailed popup. When off: the standard round gauges"
        }
        Switch {
            key: "powerMenuKde"
            icon: "swap_horiz"
            title: "\"Switch to KDE\" in the power menu"
            description: "Replaces Hibernate with a button that switches to the KDE Plasma desktop"
        }
        Switch {
            key: "updatesScript"
            icon: "deployed_code_update"
            title: "One-click full update"
            description: "The update button also updates the desktop shell while keeping these customizations. When off: standard system update only"
        }
    }

    WSection {
        title: "Right sidebar"
        Switch {
            key: "wallpaperEngineCard"; group: Config.options.sidebar
            visible: page.ex.wallpaperEngine
            icon: "wallpaper"
            title: "Wallpaper Engine picker"
            description: "Current wallpaper, mute, search and shuffle, and a grid of the installed Wallpaper Engine wallpapers"
        }
        Switch {
            key: "deviceBatteries"; group: Config.options.sidebar
            icon: "battery_full"
            title: "Device batteries"
            description: "Battery levels of wireless mice, headphones, controllers and other devices"
        }
        Switch {
            key: "desktopSwitch"; group: Config.options.sidebar
            icon: "swap_horiz"
            title: "Switch to KDE Plasma button"
            description: "A button in the sidebar header that switches to the KDE Plasma desktop"
        }
    }

    WSection {
        title: "Applications"
        Switch {
            key: "claudeCodeAi"
            icon: "smart_toy"
            title: "Claude Code in the AI sidebar"
            description: "Adds Claude Code as a model in the left sidebar (requires the Claude Code application and a Claude subscription)"
        }
        Switch {
            key: "steamTray"
            icon: "sports_esports"
            title: "Start Steam at login"
            description: "Steam starts minimized to the system tray after login"
        }
    }
}
