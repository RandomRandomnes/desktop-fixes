import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models.hyprland

Item {
    id: root

    Loader {
        anchors.fill: parent
        sourceComponent: ({ "bluetooth": bluetooth, "mouse": mouse, "keyboard": keyboard })[WState.sub] ?? overview
    }

    // Device row with connect/forget buttons (shared by overview + Devices page)
    component DeviceCard: WCard {
        id: dc
        required property var device
        readonly property bool connected: BluetoothStatus.isConnected(device)
        icon: device?.icon ? Icons.getBluetoothDeviceMaterialSymbol(device.icon) : "bluetooth"
        title: device?.name || device?.address || "Unknown device"
        description: {
            if (connected) return "Connected" + (device.batteryAvailable ? ` · Battery ${Math.round(device.battery * 100)}%` : "");
            if (device?.pairing) return "Pairing…";
            if (device?.state === BluetoothDeviceState.Connecting) return "Connecting…";
            return device?.paired ? "Paired" : "Not paired";
        }
        WButton {
            buttonText: dc.connected ? "Disconnect" : "Connect"
            accent: !dc.connected
            onClicked: dc.connected ? dc.device.disconnect() : dc.device.connect()
        }
        WButton {
            visible: dc.device?.paired ?? false
            buttonText: "Remove"
            onClicked: dc.device.forget()
        }
        WButton {
            visible: !(dc.device?.paired ?? true)
            buttonText: "Pair"
            onClicked: { dc.device.trusted = true; dc.device.pair(); }
        }
    }

    component BluetoothToggleCard: WToggle {
        icon: "bluetooth"
        title: "Bluetooth"
        description: !BluetoothStatus.available ? "No Bluetooth adapter found"
            : BluetoothStatus.enabled ? `Discoverable as "${Bluetooth.defaultAdapter?.name ?? ""}"` : "Off"
        enabled: BluetoothStatus.available
        checked: BluetoothStatus.enabled
        onToggled: v => { if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = v }
    }

    // ── Overview ───────────────────────────────────────────────────
    Component {
        id: overview
        WPage {
            WSection {
                BluetoothToggleCard {}
                Repeater {
                    model: BluetoothStatus.connectedDevices
                    DeviceCard { required property var modelData; device: modelData }
                }
                WLink { icon: "devices"; title: "View more devices"; description: "Pair new devices, connect, remove"; sub: "bluetooth" }
            }
            WSection {
                title: "Batteries"
                WToggle {
                    icon: "battery_full"
                    title: "Show device batteries in the sidebar"
                    description: "Battery levels of your mouse, headphones, controllers and other wireless devices, under the media controls"
                    checked: Config.options.sidebar.deviceBatteries
                    onToggled: v => Config.options.sidebar.deviceBatteries = v
                }
            }
            WSection {
                title: "Input"
                WLink { icon: "mouse"; title: "Mouse"; description: "Pointer speed, acceleration, scrolling, primary button"; sub: "mouse" }
                WLink { icon: "keyboard"; title: "Keyboard"; description: "Layout, repeat rate, on-screen keyboard"; sub: "keyboard" }
            }
            WSection {
                title: "Related settings"
                WLink { icon: "settings_bluetooth"; title: "More Bluetooth settings"; chevronIcon: "open_in_new"; action: () => Quickshell.execDetached(["bash", "-c", Config.options.apps.bluetooth]) }
            }
        }
    }

    // ── Devices ────────────────────────────────────────────────────
    Component {
        id: bluetooth
        WPage {
            Component.onDestruction: if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.discovering = false
            WSection {
                BluetoothToggleCard {}
                WCard {
                    icon: "add"
                    title: "Add device"
                    description: (Bluetooth.defaultAdapter?.discovering ?? false) ? "Searching for nearby devices… make sure yours is in pairing mode" : "Search for headphones, controllers, keyboards and more"
                    enabled: BluetoothStatus.enabled
                    WButton {
                        accent: !(Bluetooth.defaultAdapter?.discovering ?? false)
                        buttonText: (Bluetooth.defaultAdapter?.discovering ?? false) ? "Stop" : "Add device"
                        onClicked: Bluetooth.defaultAdapter.discovering = !Bluetooth.defaultAdapter.discovering
                    }
                }
            }
            WSection {
                title: "Connected"
                visible: BluetoothStatus.connectedDevices.length > 0
                Repeater {
                    model: BluetoothStatus.connectedDevices
                    DeviceCard { required property var modelData; device: modelData }
                }
            }
            WSection {
                title: "Paired"
                visible: BluetoothStatus.pairedButNotConnectedDevices.length > 0
                Repeater {
                    model: BluetoothStatus.pairedButNotConnectedDevices
                    DeviceCard { required property var modelData; device: modelData }
                }
            }
            WSection {
                title: "Nearby"
                visible: Bluetooth.defaultAdapter?.discovering ?? false
                Repeater {
                    model: BluetoothStatus.unpairedDevices.filter(d => d.name && d.name !== d.address.replace(/:/g, "-"))
                    DeviceCard { required property var modelData; device: modelData }
                }
            }
        }
    }

    // ── Mouse ──────────────────────────────────────────────────────
    Component {
        id: mouse
        WPage {
            id: mp
            HyprlandConfigOption { id: sens; key: "input:sensitivity" }
            HyprlandConfigOption { id: accel; key: "input:accel_profile" }
            HyprlandConfigOption { id: natural; key: "input:natural_scroll" }
            HyprlandConfigOption { id: leftHanded; key: "input:left_handed" }
            HyprlandConfigOption { id: scroll; key: "input:scroll_factor" }
            function put(opt, v) { opt.value = v; opt.setValue(v); }

            property bool hasTouchpad: false
            Process {
                running: true
                command: ["bash", "-c", "hyprctl devices -j | jq '[.mice[].name | select(test(\"touchpad|trackpad\";\"i\"))] | length'"]
                stdout: StdioCollector { onStreamFinished: mp.hasTouchpad = parseInt(text) > 0 }
            }

            WSection {
                title: "Mouse"
                WCombo {
                    icon: "left_click"
                    title: "Primary mouse button"
                    model: [{ displayName: "Left", value: false }, { displayName: "Right", value: true }]
                    currentValue: !!leftHanded.value
                    onSelected: v => mp.put(leftHanded, v ? 1 : 0)
                }
                WSlider {
                    icon: "speed"
                    title: "Mouse pointer speed"
                    from: -1; to: 1; stepSize: 0.05
                    format: v => `${Math.round((v + 1) * 10)}`
                    value: sens.value ?? 0
                    onMoved: v => mp.put(sens, Math.round(v * 100) / 100)
                }
                WToggle {
                    icon: "trending_up"
                    title: "Enhanced pointer precision"
                    description: "Mouse acceleration: the pointer moves farther when you move the mouse faster"
                    checked: (accel.value ?? "") !== "flat"
                    onToggled: v => mp.put(accel, v ? "adaptive" : "flat")
                }
            }
            WSection {
                title: "Scrolling"
                WSlider {
                    icon: "swap_vert"
                    title: "Scroll speed"
                    from: 0.2; to: 3; stepSize: 0.1
                    format: v => `${v.toFixed(1)}×`
                    value: scroll.value ?? 1
                    onMoved: v => mp.put(scroll, Math.round(v * 10) / 10)
                }
                WToggle {
                    icon: "swipe_vertical"
                    title: "Natural scrolling"
                    description: "Content moves the same direction as your fingers (reverse scroll direction)"
                    checked: !!natural.value
                    onToggled: v => mp.put(natural, v ? 1 : 0)
                }
            }
            WSection {
                title: "Touchpad"
                visible: mp.hasTouchpad
                WToggle {
                    icon: "swipe"
                    title: "Natural scrolling on touchpad"
                    checked: Config.options.hyprland.input.touchpad.naturalScroll
                    onToggled: v => { Config.options.hyprland.input.touchpad.naturalScroll = v; HyprlandConfig.set("input:touchpad:natural_scroll", v ? 1 : 0); }
                }
                WToggle {
                    icon: "keyboard_hide"
                    title: "Disable touchpad while typing"
                    checked: Config.options.hyprland.input.touchpad.disableWhileTyping
                    onToggled: v => { Config.options.hyprland.input.touchpad.disableWhileTyping = v; HyprlandConfig.set("input:touchpad:disable_while_typing", v ? 1 : 0); }
                }
                WSlider {
                    icon: "swap_vert"
                    title: "Touchpad scroll speed"
                    from: 0.1; to: 2; stepSize: 0.1
                    format: v => `${v.toFixed(1)}×`
                    value: Config.options.hyprland.input.touchpad.scrollFactor
                    onMoved: v => { const r = Math.round(v * 10) / 10; Config.options.hyprland.input.touchpad.scrollFactor = r; HyprlandConfig.set("input:touchpad:scroll_factor", r); }
                }
            }
            WSection {
                title: "Related settings"
                WLink { icon: "ads_click"; title: "Focus follows mouse"; description: "In Multitasking"; page: "system"; sub: "multitasking" }
            }
        }
    }

    // ── Keyboard ───────────────────────────────────────────────────
    Component {
        id: keyboard
        WPage {
            WSection {
                title: "Typing"
                WCard {
                    icon: "language"
                    title: "Keyboard layout"
                    description: "XKB layout codes, comma separated for several (e.g. us,de). Current: " + HyprlandXkb.currentLayoutName
                    Rectangle {
                        implicitWidth: 160; implicitHeight: 34
                        radius: Appearance.rounding.verysmall
                        color: Appearance.colors.colLayer3
                        border.width: kbInput.activeFocus ? 2 : 0
                        border.color: Appearance.colors.colPrimary
                        TextInput {
                            id: kbInput
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            verticalAlignment: Text.AlignVCenter
                            color: Appearance.colors.colOnLayer3
                            font.family: Appearance.font.family.main
                            font.pixelSize: Appearance.font.pixelSize.small
                            text: Config.options.hyprland.input.kbLayout
                            validator: RegularExpressionValidator { regularExpression: /^[a-z]{2,3}(\([a-z0-9_-]+\))?(,[a-z]{2,3}(\([a-z0-9_-]+\))?)*$/ }
                            onEditingFinished: if (acceptableInput && text !== Config.options.hyprland.input.kbLayout) {
                                Config.options.hyprland.input.kbLayout = text;
                                HyprlandConfig.set("input:kb_layout", text);
                            }
                        }
                    }
                }
                WSlider {
                    icon: "timer"
                    title: "Repeat delay"
                    description: "How long to hold a key before it starts repeating"
                    from: 150; to: 1000; stepSize: 25
                    format: v => `${Math.round(v)} ms`
                    value: Config.options.hyprland.input.repeatDelay
                    onMoved: v => { Config.options.hyprland.input.repeatDelay = Math.round(v); HyprlandConfig.set("input:repeat_delay", Math.round(v)); }
                }
                WSlider {
                    icon: "fast_forward"
                    title: "Repeat rate"
                    description: "How fast a held key repeats"
                    from: 10; to: 80; stepSize: 1
                    format: v => `${Math.round(v)}/s`
                    value: Config.options.hyprland.input.repeatRate
                    onMoved: v => { Config.options.hyprland.input.repeatRate = Math.round(v); HyprlandConfig.set("input:repeat_rate", Math.round(v)); }
                }
                WToggle {
                    icon: "dialpad"
                    title: "Turn on Num Lock at startup"
                    checked: Config.options.hyprland.input.numlock
                    onToggled: v => { Config.options.hyprland.input.numlock = v; HyprlandConfig.set("input:numlock_by_default", v ? 1 : 0); }
                }
            }
            WSection {
                title: "On-screen keyboard"
                WToggle {
                    icon: "keyboard"
                    title: "On-screen keyboard"
                    checked: GlobalStates.oskOpen
                    onToggled: v => GlobalStates.oskOpen = v
                }
                WToggle {
                    icon: "push_pin"
                    title: "Keep it pinned at startup"
                    checked: Config.options.osk.pinnedOnStartup
                    onToggled: v => Config.options.osk.pinnedOnStartup = v
                }
            }
            WSection {
                title: "Related"
                WLink { icon: "keyboard_command_key"; title: "Keyboard shortcuts"; description: "Edit your Hyprland keybinds file"; chevronIcon: "open_in_new"; action: () => Quickshell.execDetached(["xdg-open", `${Directories.config}/hypr/custom/keybinds.lua`.replace("file://", "")]) }
            }
        }
    }
}
