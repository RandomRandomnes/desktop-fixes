import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Battery levels of wireless devices (mouse, keyboard, headphones, controllers...) as reported by UPower.
// Sits under the media player in the right sidebar; hides itself when no such device is connected.
Rectangle {
    id: root

    // Demo: while ~/.local/state/phoenix/battery-demo exists, two sample devices are shown (for screenshots/tests)
    property bool demo: false
    FileView {
        path: `${Quickshell.env("HOME")}/.local/state/phoenix/battery-demo`
        watchChanges: true
        printErrors: false             // a missing demo file is the normal case
        onLoaded: root.demo = true
        onLoadFailed: root.demo = false
        onFileChanged: reload()
    }
    readonly property var demoDevices: [
        { model: "Wireless mouse (demo)", percentage: 0.53, type: UPowerDeviceType.Mouse, state: UPowerDeviceState.Discharging },
        { model: "Headphones (demo)", percentage: 0.82, type: UPowerDeviceType.Headphones, state: UPowerDeviceState.Charging },
    ]
    readonly property var devices: demo ? demoDevices
        : UPower.devices.values.filter(d => !d.isLaptopBattery && !d.powerSupply && d.isPresent && d.ready)
    property real horizontalPadding: 12
    property real verticalPadding: 10

    visible: Config.options.sidebar.deviceBatteries && devices.length > 0
    implicitHeight: list.implicitHeight + verticalPadding * 2
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1

    function iconFor(type) {
        switch (type) {
        case UPowerDeviceType.Mouse: return "mouse";
        case UPowerDeviceType.Keyboard: return "keyboard";
        case UPowerDeviceType.Headphones: return "headphones";
        case UPowerDeviceType.Headset: return "headset_mic";
        case UPowerDeviceType.GamingInput: return "sports_esports";
        case UPowerDeviceType.Phone: return "smartphone";
        case UPowerDeviceType.Tablet: return "tablet";
        case UPowerDeviceType.Speakers: return "speaker";
        case UPowerDeviceType.Touchpad: return "touch_app";
        case UPowerDeviceType.Pen: return "stylus";
        case UPowerDeviceType.Wearable: return "watch";
        default: return "battery_full";
        }
    }

    ColumnLayout {
        id: list
        anchors {
            fill: parent
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
            topMargin: root.verticalPadding
            bottomMargin: root.verticalPadding
        }
        spacing: 8

        Repeater {
            model: root.devices
            delegate: RowLayout {
                id: row
                required property var modelData
                readonly property real level: modelData.percentage
                readonly property bool charging: modelData.state === UPowerDeviceState.Charging
                    || modelData.state === UPowerDeviceState.PendingCharge
                    || modelData.state === UPowerDeviceState.FullyCharged
                readonly property bool low: !charging && level <= 0.2
                Layout.fillWidth: true
                spacing: 10

                MaterialSymbol {
                    text: root.iconFor(row.modelData.type)
                    iconSize: Appearance.font.pixelSize.larger
                    color: row.low ? Appearance.colors.colError : Appearance.colors.colOnLayer1
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            Layout.fillWidth: true
                            text: row.modelData.model || "Device"
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer1
                        }
                        MaterialSymbol {
                            visible: row.charging
                            text: "bolt"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: `${Math.round(row.level * 100)}%`
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.features: { "tnum": 1 }
                            color: row.low ? Appearance.colors.colError : Appearance.colors.colSubtext
                        }
                    }
                    StyledProgressBar {
                        Layout.fillWidth: true
                        value: row.level
                        valueBarHeight: 4
                        highlightColor: row.low ? Appearance.colors.colError : Appearance.colors.colPrimary
                    }
                }
            }
        }
    }
}
