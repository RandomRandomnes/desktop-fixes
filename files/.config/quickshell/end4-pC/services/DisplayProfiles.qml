pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * Display profiles switching by themselves (2026-10-08, ours; not upstream). Settings › System › Display.
 * When a display is plugged in or out, and once at login, this runs `display-profiles auto`, which applies the saved
 * profile made for exactly the displays now connected (if any). extras.displayProfilesAuto switches it off.
 * Instantiated from GlobalStates.qml.
 */
Singleton {
    id: root

    readonly property bool enabled: Config.ready && Config.options.extras.displayProfilesAuto !== false
    readonly property string tool: `${Quickshell.env("HOME")}/.local/bin/display-profiles`
    property string lastApplied: ""
    signal profilesChanged()

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["monitoraddedv2", "monitorremovedv2"].includes(event.name)) autoTimer.restart()
        }
    }
    // displays settle for a moment after being plugged in; also covers several events in a row
    Timer { id: autoTimer; interval: 2500; onTriggered: root.runAuto() }
    Timer { interval: 4000; running: root.enabled; onTriggered: root.runAuto() }   // at login: port names may have changed

    function runAuto() {
        if (!root.enabled || autoProc.running) return
        autoProc.running = true
    }
    Process {
        id: autoProc
        command: [root.tool, "auto"]
        stdout: StdioCollector {
            onStreamFinished: {
                let r = {}
                try { r = JSON.parse(text) } catch (e) {}
                if (r.profile && r.changed) {
                    root.lastApplied = r.profile
                    console.log(`[DisplayProfiles] applied "${r.profile}"`)
                    Quickshell.execDetached(["notify-send", "-a", "Phoenix", "-i", "video-display", "Display profile", `Switched to "${r.profile}"`])
                    root.profilesChanged()
                }
            }
        }
    }
}
