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
                // through the setup assistant's queue when it runs there (one terminal at a time; QA 2026-10-08)
                action: () => terminalRunner ? terminalRunner(["bash", "-c", "passwd; echo; read -r -p 'Press Enter to close.'"], "Change password")
                    : Quickshell.execDetached(["kitty", "--class", "phoenix-setup", "--title", "Change password", "--hold", "passwd"]) }
        // Phoenix login screen (P5, 2026-10-08): `phoenix login-screen install|remove` in a terminal (asks for the password)
        WCard {
            id: loginScreen
            property string lsState: ""   // "on" | "off" | ""
            icon: "login"
            title: "Login screen at startup"
            property string otherDm: ""   // another login manager (sddm, gdm…) instead of automatic sign-in
            property bool updateReady: false   // a newer login screen came with a Phoenix update (root's copy is older)
            description: lsState === "on" ? (updateReady ? "On. An update for the login screen is ready (asks for your password)"
                    : "On: the PC starts at the Phoenix login screen and asks for your password")
                : lsState === "off" ? (otherDm ? `Off: the PC uses another login screen (${otherDm})` : "Off: the PC signs you in automatically when it starts")
                : "Checking…"
            function refresh() { lsStatus.running = true }
            Component.onCompleted: refresh()
            Connections { target: GlobalStates; function onSettingsOpenChanged() { if (GlobalStates.settingsOpen) loginScreen.refresh() } }
            Process {
                id: lsStatus
                command: ["bash", "-c", "~/.local/bin/phoenix login-screen status"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        loginScreen.lsState = /: on/.test(text) ? "on" : /: off/.test(text) ? "off" : ""
                        loginScreen.otherDm = (text.match(/login manager: ([\w.-]+)/) || [])[1] ?? ""
                        loginScreen.updateReady = /update is ready/.test(text)
                    }
                }
            }
            Process {
                id: lsChange
                onExited: loginScreen.refresh()
            }
            Timer {   // through the assistant's terminal: look again every few seconds for a while
                id: lsRecheck
                interval: 3000; repeat: true
                property int left: 0
                property string startState: ""
                onRunningChanged: if (running) { left = 60; startState = loginScreen.lsState }
                onTriggered: { loginScreen.refresh(); if (--left <= 0 || loginScreen.lsState !== startState) stop() }
            }
            WButton {   // an update for the installed login screen: install again
                visible: loginScreen.lsState === "on" && loginScreen.updateReady
                accent: true
                enabled: !lsChange.running && !lsRecheck.running
                buttonText: "Update"
                onClicked: {
                    const args = ["bash", "-c", "~/.local/bin/phoenix login-screen install; echo; read -r -p 'Press Enter to close.'"]
                    if (terminalRunner) { terminalRunner(args, "Login screen"); lsRecheck.restart(); return }
                    lsChange.command = ["kitty", "--class", "phoenix-setup", "--title", "Login screen", "--"].concat(args)
                    lsChange.running = true
                }
            }
            WButton {
                accent: loginScreen.lsState === "off"
                // busy also while the assistant's terminal runs it (lsRecheck), so it can't be queued twice
                readonly property bool busy: lsChange.running || lsRecheck.running
                enabled: loginScreen.lsState !== "" && !busy
                buttonText: busy ? "Waiting…" : loginScreen.lsState === "on" ? "Turn off" : "Turn on"
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
