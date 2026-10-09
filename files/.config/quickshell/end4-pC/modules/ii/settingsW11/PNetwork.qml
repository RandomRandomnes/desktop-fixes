import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models.quickToggles

Item {
    id: root

    Loader {
        anchors.fill: parent
        sourceComponent: ({ "wifi": wifi })[WState.sub] ?? overview
    }

    readonly property bool wifiOn: Network.wifiStatus !== "disabled"
    // Phoenix (2026-10-09): is there a Wi-Fi adapter at all? (a wired-only PC showed "Wi-Fi On – Connected to Wired
    // connection 1": the row used the general connection name)
    property bool hasWifi: true
    Process {
        running: true
        command: ["nmcli", "-t", "-f", "TYPE", "device"]
        stdout: StdioCollector { onStreamFinished: root.hasWifi = /^wifi$/m.test(text) }
    }
    readonly property bool connected: Network.ethernet || Network.wifiStatus === "connected"

    function setAirplane(on) {
        Quickshell.execDetached(["nmcli", "radio", "all", on ? "off" : "on"]);
        if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !on;
    }

    // ── Overview ───────────────────────────────────────────────────
    Component {
        id: overview
        WPage {
            // Connection banner
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 96
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2
                RowLayout {
                    anchors { fill: parent; leftMargin: 22; rightMargin: 18 }
                    spacing: 18
                    MaterialSymbol {
                        Layout.preferredWidth: 44
                        horizontalAlignment: Text.AlignHCenter
                        text: Network.materialSymbol
                        iconSize: 40
                        color: root.connected ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                    }
                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true
                        StyledText {
                            text: Network.ethernet ? "Ethernet" : (Network.networkName || "Not connected")
                            font.pixelSize: Appearance.font.pixelSize.larger
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer2
                        }
                        StyledText {
                            text: root.connected ? `Connected, secured${Network.ipAddress ? " · " + Network.ipAddress : ""}` : "You're not connected to any networks"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }
                    WButton {
                        visible: !Network.ethernet && root.connected
                        buttonText: "Disconnect"
                        onClicked: Network.disconnectWifiNetwork()
                    }
                }
            }

            WSection {
                WToggle {
                    icon: "wifi"
                    title: "Wi-Fi"
                    enabled: root.hasWifi
                    description: !root.hasWifi ? "No Wi-Fi adapter"
                        : root.wifiOn ? (Network.active?.ssid ? `Connected to ${Network.active.ssid}` : "On") : "Off"
                    checked: root.hasWifi && root.wifiOn
                    onToggled: v => Network.enableWifi(v)
                }
                WLink { visible: root.hasWifi; icon: "wifi_find"; title: "Show available networks"; description: "Connect to a Wi-Fi network"; sub: "wifi" }
                WCard {
                    visible: Network.ethernet
                    icon: "lan"
                    title: "Ethernet"
                    description: `Connected · ${Network.networkInterface}`
                }
                WToggle {
                    icon: "airplanemode_active"
                    title: "Airplane mode"
                    description: "Stop all wireless communication (Wi-Fi and Bluetooth)"
                    checked: !root.wifiOn && !BluetoothStatus.enabled
                    onToggled: v => root.setAirplane(v)
                }
            }

            WSection {
                title: "Properties"
                visible: root.connected
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: propCol.implicitHeight + 28
                    radius: Appearance.rounding.verysmall + 2
                    color: Appearance.colors.colLayer2
                    ColumnLayout {
                        id: propCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14; leftMargin: 18 }
                        spacing: 8
                        Repeater {
                            model: [
                                ["Interface", Network.networkInterface],
                                ["IPv4 address", Network.ipAddress],
                                ["Gateway", Network.gateway],
                                ["Public IP", Network.publicIpAddress],
                                ["Physical address (MAC)", Network.macAddress],
                                ["Signal strength", Network.ethernet || !Network.active ? "" : `${Network.active.strength}%`],
                            ].filter(p => p[1])
                            RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 12
                                StyledText { Layout.preferredWidth: 200; text: modelData[0]; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.small }
                                StyledText { Layout.fillWidth: true; text: modelData[1]; color: Appearance.colors.colOnLayer2; font.pixelSize: Appearance.font.pixelSize.small }
                            }
                        }
                    }
                }
            }

            WSection {
                title: "Related settings"
                WLink { icon: "settings_ethernet"; title: "Advanced network settings"; description: "Connections, DNS, proxy, VPN profiles"; chevronIcon: "open_in_new"; action: () => Quickshell.execDetached(["bash", "-c", Config.options.apps.network]) }
                WLink { icon: "public"; title: "Open sign-in page for public Wi-Fi"; chevronIcon: "open_in_new"; action: () => Network.openPublicWifiPortal() }
            }
        }
    }

    // ── Wi-Fi list ─────────────────────────────────────────────────
    Component {
        id: wifi
        WPage {
            Component.onCompleted: if (root.wifiOn) Network.rescanWifi()

            WSection {
                WToggle {
                    icon: "wifi"
                    title: "Wi-Fi"
                    checked: root.wifiOn
                    onToggled: v => Network.enableWifi(v)
                }
                WCard {
                    icon: "refresh"
                    title: Network.wifiScanning ? "Scanning…" : `${Network.friendlyWifiNetworks.length} networks found`
                    enabled: root.wifiOn
                    WButton { buttonText: "Refresh"; enabled: !Network.wifiScanning; onClicked: Network.rescanWifi() }
                }
            }

            WSection {
                title: "Available networks"
                visible: root.wifiOn
                Repeater {
                    model: Network.friendlyWifiNetworks.filter(n => n && n.ssid)
                    WCard {
                        id: net
                        required property var modelData
                        readonly property bool connecting: Network.wifiConnectTarget === modelData
                        icon: modelData.strength > 75 ? "signal_wifi_4_bar" : modelData.strength > 50 ? "network_wifi_3_bar" : modelData.strength > 25 ? "network_wifi_2_bar" : "network_wifi_1_bar"
                        title: modelData.ssid
                        description: (modelData.active ? "Connected" : connecting ? "Connecting…" : modelData.isSecure ? "Secured" : "Open")
                            + ` · ${modelData.frequency > 5000 ? "5 GHz" : "2.4 GHz"}`
                        minHeight: modelData.askingPassword ? 110 : 66

                        ColumnLayout {
                            spacing: 6
                            RowLayout {
                                Layout.alignment: Qt.AlignRight
                                WButton {
                                    visible: !net.modelData.askingPassword
                                    accent: !net.modelData.active
                                    buttonText: net.modelData.active ? "Disconnect" : "Connect"
                                    enabled: !net.connecting
                                    onClicked: net.modelData.active ? Network.disconnectWifiNetwork() : Network.connectToWifiNetwork(net.modelData)
                                }
                            }
                            RowLayout {
                                visible: net.modelData.askingPassword
                                spacing: 8
                                Rectangle {
                                    implicitWidth: 220; implicitHeight: 34
                                    radius: Appearance.rounding.verysmall
                                    color: Appearance.colors.colLayer3
                                    border.width: 2
                                    border.color: Appearance.colors.colPrimary
                                    TextField {
                                        id: pw
                                        anchors.fill: parent
                                        leftPadding: 10
                                        background: null
                                        echoMode: TextInput.Password
                                        placeholderText: "Network security key"
                                        placeholderTextColor: Appearance.colors.colSubtext
                                        color: Appearance.colors.colOnLayer3
                                        font.family: Appearance.font.family.main
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        onAccepted: if (text.length > 0) Network.changePassword(net.modelData, text)
                                    }
                                }
                                WButton { buttonText: "Cancel"; onClicked: net.modelData.askingPassword = false }
                                WButton { accent: true; buttonText: "Next"; enabled: pw.text.length > 0; onClicked: Network.changePassword(net.modelData, pw.text) }
                            }
                        }
                    }
                }
            }
        }
    }
}
