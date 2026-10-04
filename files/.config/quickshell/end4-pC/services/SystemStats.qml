pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Detailed system telemetry for the bar resources widget (2026-10-03, ours; not upstream).
 * One long-lived scripts/sysstats/sysstats.py process prints a JSON sample per second; this keeps the
 * latest sample plus short CPU / GPU / RAM usage histories for the bar graphs.
 */
Singleton {
    id: root

    readonly property int historyLength: Config?.options.resources.historyLength ?? 60
    property var sample: null
    readonly property var cpu: sample?.cpu ?? null
    readonly property var gpu: sample?.gpu ?? null
    readonly property var mem: sample?.mem ?? null
    readonly property var sys: sample?.sys ?? null
    readonly property bool ready: sample !== null

    readonly property real memUsage: mem && mem.total > 0 ? mem.used / mem.total : 0
    property list<real> cpuHistory: []
    property list<real> gpuHistory: []
    property list<real> memHistory: []

    function pushHistory(list, value) {
        const next = list.concat([Math.max(0, Math.min(1, value))])
        return next.length > root.historyLength ? next.slice(next.length - root.historyLength) : next
    }

    function gb(bytes, digits = 1) {
        return (bytes / 1073741824).toFixed(digits)
    }

    function bytesShort(bytes) {
        if (bytes >= 1073741824) return `${(bytes / 1073741824).toFixed(1)} GB`
        if (bytes >= 1048576) return `${(bytes / 1048576).toFixed(0)} MB`
        return `${Math.round(bytes / 1024)} KB`
    }

    function rate(bytesPerSec) {
        if (bytesPerSec >= 1048576) return `${(bytesPerSec / 1048576).toFixed(1)} MB/s`
        if (bytesPerSec >= 1024) return `${Math.round(bytesPerSec / 1024)} KB/s`
        return `${Math.round(bytesPerSec)} B/s`
    }

    function ghz(mhz) {
        return (mhz / 1000).toFixed(2)
    }

    function duration(seconds) {
        const d = Math.floor(seconds / 86400), h = Math.floor(seconds % 86400 / 3600), m = Math.floor(seconds % 3600 / 60)
        if (d > 0) return `${d} d ${h} h`
        if (h > 0) return `${h} h ${m} min`
        return `${m} min`
    }

    Process {
        id: sampler
        // only needed by the graph widget (Settings › Extras › resource graphs)
        running: Config.options.extras.resourceGraphs
        command: ["python3", `${Directories.scriptPath}/sysstats/sysstats.py`.replace(/file:\/\//, ""), "1"]
        stdout: SplitParser {
            onRead: line => {
                let s
                try {
                    s = JSON.parse(line)
                } catch (e) {
                    return
                }
                root.sample = s
                root.cpuHistory = root.pushHistory(root.cpuHistory, s.cpu.usage)
                root.gpuHistory = root.pushHistory(root.gpuHistory, s.gpu?.busy ?? 0)
                root.memHistory = root.pushHistory(root.memHistory, s.mem.total > 0 ? s.mem.used / s.mem.total : 0)
            }
        }
        onExited: restartTimer.start()
    }

    Timer {
        id: restartTimer
        interval: 3000
        onTriggered: sampler.running = Config.options.extras.resourceGraphs
    }
}
