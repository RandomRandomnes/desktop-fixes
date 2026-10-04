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
        WLink { icon: "password"; title: "Change your password"; description: "Opens a terminal running passwd"; chevronIcon: "open_in_new"; action: () => Quickshell.execDetached(["bash", "-c", Config.options.apps.changePassword]) }
        WLink { icon: "key"; title: "Sign-in options"; description: "Lock screen, keyring, password requirements"; page: "privacy" }
        WLink { icon: "group"; title: "Other users"; description: "Add or manage user accounts"; chevronIcon: "open_in_new"; action: () => Quickshell.execDetached(["bash", "-c", Config.options.apps.manageUser]) }
    }
}
