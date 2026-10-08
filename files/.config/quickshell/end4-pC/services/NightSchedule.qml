pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Night light from sunset to sunrise (2026-10-08, ours; not upstream). Settings › System › Display.
 * While light.night.followSun (and the schedule) is on, this sets light.night.from/to to today's sunset and tomorrow's
 * sunrise from ~/.local/bin/sun-times (offline: the time zone's main city), checked every 30 minutes so a new day or a
 * daylight-saving change is picked up. ii's Hyprsunset service does the rest with those hours.
 * Instantiated from GlobalStates.qml.
 */
Singleton {
    id: root

    readonly property bool active: Config.ready && Config.options.light.night.automatic && Config.options.light.night.followSun === true
    property string place: ""
    property bool ok: false

    onActiveChanged: if (active) proc.running = true
    Timer {
        interval: 30 * 60 * 1000
        repeat: true
        running: root.active
        onTriggered: proc.running = true
    }
    Process {
        id: proc
        command: [`${Quickshell.env("HOME")}/.local/bin/sun-times`]
        stdout: StdioCollector {
            onStreamFinished: {
                let d = {}
                try { d = JSON.parse(text) } catch (e) {}
                root.place = d.place || ""
                root.ok = d.ok === true
                if (!root.ok || !root.active) return   // polar day/night or no location: keep the hours as they are
                const night = Config.options.light.night
                if (night.from !== d.sunset) night.from = d.sunset
                if (night.to !== d.sunrise) night.to = d.sunrise
            }
        }
    }
}
