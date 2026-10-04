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

WPage {
    id: page

    DarkModeToggle { id: darkMode }
    NightLightToggle { id: nightLight }
    NotificationToggle { id: notif }
    IdleInhibitorToggle { id: keepAwake }

    Component.onCompleted: if (SystemInfo.cpu === "") SystemInfo.refresh()

    // ── Device banner ──────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 18

        Rectangle {
            implicitWidth: 196
            implicitHeight: 110
            radius: Appearance.rounding.small
            color: Appearance.colors.colLayer2
            Image {
                id: wallThumb
                anchors.fill: parent
                source: Config.options.background.wallpaperPath ? "file://" + Config.options.background.wallpaperPath : ""
                sourceSize.width: 400
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle { width: wallThumb.width; height: wallThumb.height; radius: Appearance.rounding.small }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 120
            spacing: 2
            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: SystemInfo.hostname || "This PC"
                font.pixelSize: Appearance.font.pixelSize.huge
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
            }
            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: SystemInfo.distroName + (SystemInfo.cpu ? " · " + SystemInfo.cpu : "")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
            StyledText {
                text: "Rename in System › About"
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colPrimary
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: WState.go("system", "about")
                }
            }
        }

        // status pills (Windows 11: network + Windows Update)
        Repeater {
            model: [
                { icon: Network.materialSymbol, title: Network.ethernet ? "Ethernet" : (Network.networkName || "Not connected"), sub: Network.wifiStatus === "connected" || Network.ethernet ? "Connected" : "Offline", page: "network" },
                { icon: "update", title: "Updates", sub: Updates.available ? (Updates.count > 0 ? `${Updates.count} available` : "Up to date") : "Checking…", page: "update" },
            ]
            RippleButton {
                required property var modelData
                Layout.preferredWidth: 180
                Layout.minimumWidth: 140
                Layout.fillWidth: false
                implicitHeight: 64
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                onClicked: WState.go(modelData.page)
                contentItem: RowLayout {
                    spacing: 12
                    MaterialSymbol {
                        Layout.leftMargin: 14
                        text: modelData.icon
                        iconSize: 24
                        color: Appearance.colors.colPrimary
                    }
                    ColumnLayout {
                        spacing: 0
                        Layout.fillWidth: true
                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.title
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer2
                            elide: Text.ElideRight
                        }
                        StyledText {
                            text: modelData.sub
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
            }
        }
    }

    // ── Tiles ───────────────────────────────────────────────────────
    GridLayout {
        Layout.fillWidth: true
        columns: page.width > 760 ? 2 : 1
        columnSpacing: 12
        rowSpacing: 12

        WTile {
            Layout.alignment: Qt.AlignTop
            title: "Recommended settings"
            description: "Recent and commonly used settings"
            WToggle { icon: "dark_mode"; title: "Dark mode"; minHeight: 52; checked: darkMode.toggled; onToggled: darkMode.mainAction() }
            WToggle { icon: "nightlight"; title: "Night light"; minHeight: 52; checked: nightLight.toggled; onToggled: nightLight.mainAction() }
            WToggle { icon: "do_not_disturb_on"; title: "Do not disturb"; minHeight: 52; checked: !notif.toggled; onToggled: notif.mainAction() }
            WToggle { icon: "coffee"; title: "Keep awake"; minHeight: 52; checked: keepAwake.toggled; onToggled: keepAwake.mainAction() }
        }

        WTile {
            Layout.alignment: Qt.AlignTop
            title: "Personalize your device"
            description: "Change your background and color mode"
            linkText: "Browse more backgrounds"
            onLinkClicked: GlobalStates.wallpaperSelectorOpen = true
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Repeater {
                    model: [false, true]
                    RippleButton {
                        required property bool modelData
                        Layout.fillWidth: true
                        implicitHeight: 76
                        buttonRadius: Appearance.rounding.small
                        toggled: Appearance.m3colors.darkmode === modelData
                        colBackground: Appearance.colors.colLayer3
                        colBackgroundToggled: Appearance.colors.colPrimaryContainer
                        colBackgroundToggledHover: Appearance.colors.colPrimaryContainerHover
                        onClicked: if (!toggled) darkMode.mainAction()
                        contentItem: ColumnLayout {
                            spacing: 4
                            MaterialSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData ? "dark_mode" : "light_mode"
                                iconSize: 26
                                fill: parent.parent.toggled ? 1 : 0
                                color: parent.parent.toggled ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer3
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData ? "Dark" : "Light"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: parent.parent.toggled ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer3
                            }
                        }
                    }
                }
            }
            WLink { icon: "wallpaper"; title: "Background"; minHeight: 52; page: "personalization"; sub: "background" }
            WLink { icon: "palette"; title: "Colors"; minHeight: 52; page: "personalization"; sub: "colors" }
        }

        WTile {
            Layout.alignment: Qt.AlignTop
            title: "Your dock"
            description: "Apps pinned to the dock at the bottom of the screen"
            linkText: "Edit pinned apps"
            onLinkClicked: WState.go("personalization", "dock")
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: Config.options.dock.pinnedApps
                    Rectangle {
                        required property string modelData
                        width: 46
                        height: 46
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer3
                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 28
                            source: Quickshell.iconPath(AppSearch.guessIcon(modelData), "image-missing")
                        }
                    }
                }
            }
        }

        WTile {
            Layout.alignment: Qt.AlignTop
            title: "Bluetooth devices"
            description: BluetoothStatus.enabled ? "Manage your connected devices" : "Bluetooth is off"
            linkText: "View all devices"
            onLinkClicked: WState.go("devices", "bluetooth")
            Repeater {
                model: BluetoothStatus.connectedDevices.concat(BluetoothStatus.pairedButNotConnectedDevices).slice(0, 4)
                WCard {
                    required property var modelData
                    minHeight: 50
                    icon: modelData.icon ? Icons.getBluetoothDeviceMaterialSymbol(modelData.icon) : "bluetooth"
                    title: modelData.name
                    description: BluetoothStatus.isConnected(modelData) ? "Connected" + (modelData.batteryAvailable ? ` · ${Math.round(modelData.battery * 100)}%` : "") : "Paired"
                }
            }
            StyledText {
                visible: BluetoothStatus.connectedDevices.length + BluetoothStatus.pairedButNotConnectedDevices.length === 0
                text: "No devices"
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }
    }
}
