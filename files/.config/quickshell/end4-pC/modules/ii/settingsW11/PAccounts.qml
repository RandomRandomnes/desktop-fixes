import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

WPage {
    // the setup assistant passes its terminal(args, title) so jobs wait for its open terminal window (one at a time)
    property var terminalRunner: null
    id: page

    Process {
        id: pickProc
        command: ["kdialog", "--getopenfilename", `${Quickshell.env("HOME")}/Pictures`, "image/png image/jpeg image/webp image/gif"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim();
                if (!f) return;
                Config.options.profile.avatarPath = f.substring(0, f.lastIndexOf("/"));
                Config.options.profile.avatarPicture = f;
            }
        }
    }

    // Header
    RowLayout {
        Layout.fillWidth: true
        spacing: 20
        UserAvatar {
            implicitWidth: 104
            implicitHeight: 104
        }
        ColumnLayout {
            spacing: 2
            StyledText {
                text: Config.options.profile.displayName || SystemInfo.username
                font.pixelSize: Appearance.font.pixelSize.hugeass
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
            }
            StyledText { text: `${SystemInfo.username}@${SystemInfo.hostname}`; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.small }
            StyledText { text: "Local account · Administrator"; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.small }
        }
    }

    WSection {
        title: "Your info"
        WCard {
            icon: "photo_camera"
            title: "Choose a photo"
            description: "Shown on the lock screen, settings and sidebar"
            WButton { buttonText: "Browse files"; onClicked: pickProc.running = true }
            WButton {
                visible: Config.options.profile.avatarPicture !== ""
                buttonText: "Remove"
                onClicked: { Config.options.profile.avatarPicture = ""; Config.options.profile.avatarPath = ""; }
            }
        }
        WCard {
            icon: "badge"
            title: "Display name"
            description: `Leave empty to use your username (${SystemInfo.username})`
            Rectangle {
                implicitWidth: 240; implicitHeight: 34
                radius: Appearance.rounding.verysmall
                color: Appearance.colors.colLayer3
                border.width: nameField.activeFocus ? 2 : 0
                border.color: Appearance.colors.colPrimary
                TextField {
                    id: nameField
                    anchors.fill: parent
                    leftPadding: 10
                    background: null
                    text: Config.options.profile.displayName
                    placeholderText: SystemInfo.username
                    placeholderTextColor: Appearance.colors.colSubtext
                    color: Appearance.colors.colOnLayer3
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.small
                    onEditingFinished: Config.options.profile.displayName = text.trim()
                }
            }
        }
        WCombo {
            icon: "short_text"
            title: "Subtitle under your name"
            model: [{ displayName: "Distribution name", value: "::distro::" }, { displayName: "Uptime", value: "::uptime::" }]
            currentValue: Config.options.profile.descriptionText
            onSelected: v => Config.options.profile.descriptionText = v
        }
    }

    WSection {
        title: "Account settings"
        // its own centered terminal in front (class phoenix-setup, custom/rules.lua); the stock "kitty -1" could reuse
        // an open kitty window, and from the setup assistant it could open behind it
        WLink { icon: "password"; title: "Change your password"; description: "Opens a window that asks for the current password, then the new one twice"; chevronIcon: "open_in_new"
                action: () => Quickshell.execDetached(["kitty", "--class", "phoenix-setup", "--title", "Change password", "--hold", "passwd"]) }
        // Phoenix login screen (P5, 2026-10-08): `phoenix login-screen install|remove` in a terminal (asks for the password)
        WCard {
            id: loginScreen
            property string lsState: ""   // "on" | "off" | ""
            icon: "login"
            title: "Login screen at startup"
            description: lsState === "on" ? "On: the PC starts at the Phoenix login screen and asks for your password"
                : lsState === "off" ? "Off: the PC signs you in automatically when it starts" : "Checking…"
            function refresh() { lsStatus.running = true }
            Component.onCompleted: refresh()
            Connections { target: GlobalStates; function onSettingsOpenChanged() { if (GlobalStates.settingsOpen) loginScreen.refresh() } }
            Process {
                id: lsStatus
                command: ["bash", "-c", "~/.local/bin/phoenix login-screen status"]
                stdout: StdioCollector { onStreamFinished: loginScreen.lsState = /: on/.test(text) ? "on" : /: off/.test(text) ? "off" : "" }
            }
            Process {
                id: lsChange
                onExited: loginScreen.refresh()
            }
            Timer {   // through the assistant's terminal: look again every few seconds for a while
                id: lsRecheck
                interval: 3000; repeat: true
                property int left: 0
                onRunningChanged: if (running) left = 60
                onTriggered: { loginScreen.refresh(); if (--left <= 0) stop() }
            }
            WButton {
                accent: loginScreen.lsState === "off"
                enabled: loginScreen.lsState !== "" && !lsChange.running
                buttonText: lsChange.running ? "Waiting…" : loginScreen.lsState === "on" ? "Turn off" : "Turn on"
                onClicked: {
                    const action = loginScreen.lsState === "on" ? "remove" : "install"
                    const args = ["bash", "-c", `~/.local/bin/phoenix login-screen ${action}; echo; read -r -p 'Press Enter to close.'`]
                    if (terminalRunner) { terminalRunner(args, "Login screen"); lsRecheck.restart(); return }
                    lsChange.command = ["kitty", "--class", "phoenix-setup", "--title", "Login screen", "--"].concat(args)
                    lsChange.running = true
                }
            }
        }
        WLink { icon: "key"; title: "Sign-in options"; description: "Lock screen, keyring, password requirements"; page: "privacy" }
        WLink { icon: "group"; title: "Other users"; description: "Add or manage user accounts"; chevronIcon: "open_in_new"; action: () => Quickshell.execDetached(["bash", "-c", Config.options.apps.manageUser]) }
    }
}
