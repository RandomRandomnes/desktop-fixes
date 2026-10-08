pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Custom-feature switches (2026-10-03, ours; not upstream). The switches are Config.options.extras (Settings › Extras,
 * setup profiles). Shell-side features read them directly; whenever one changes this runs ~/.local/bin/setup-features
 * apply, which handles the Hyprland side (window rules, title bars, minimize) and starts/stops Wallpaper Engine.
 * Instantiated from GlobalStates.qml.
 */
Singleton {
    id: root

    readonly property var extras: Config.options.extras
    readonly property string signature: [extras.windowsStyle, extras.minimizeToDock, extras.wallpaperEngine,
        extras.resourceGraphs, extras.appGrid, extras.powerMenuKde, extras.claudeCodeAi, extras.updatesScript,
        extras.steamTray, extras.workspaceGroups].join(",")
    property string appliedSignature: ""

    function apply() {
        applyTimer.restart()
    }

    onSignatureChanged: {
        if (!Config.ready) return
        // the first value after loading is the saved state; setup-features apply is a no-op then, but run it once
        // so features.lua exists and matches the config
        if (root.appliedSignature !== root.signature) applyTimer.restart()
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) applyTimer.restart()
        }
    }

    Timer {
        id: applyTimer
        interval: 400
        onTriggered: {
            if (applyProc.running) {
                applyTimer.restart()
                return
            }
            root.appliedSignature = root.signature
            applyProc.running = true
        }
    }

    Process {
        id: applyProc
        command: [`${Quickshell.env("HOME")}/.local/bin/setup-features`, "apply"]
        stdout: StdioCollector {
            onStreamFinished: if (text.trim() !== "" && text.trim() !== "no changes") console.log("[Extras] " + text.trim())
        }
    }
}
