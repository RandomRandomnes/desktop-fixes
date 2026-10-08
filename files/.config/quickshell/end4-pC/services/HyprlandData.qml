pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services

/**
 * Provides access to some Hyprland data not available in Quickshell.Hyprland.
 */
Singleton {
    id: root
    property var windowList: []
    property var addresses: []
    property var windowByAddress: ({})
    property var workspaces: []
    property var workspaceIds: []
    property var workspaceById: ({})
    property var activeWorkspace: null
    property var monitors: []
    property var layers: ({})

    // Convenient stuff

    function toplevelsForWorkspace(workspace) {
        return ToplevelManager.toplevels.values.filter(toplevel => {
            const address = `0x${toplevel.HyprlandToplevel?.address}`;
            var win = HyprlandData.windowByAddress[address];
            return win?.workspace?.id === workspace;
        })
    }

    function hyprlandClientsForWorkspace(workspace) {
        return root.windowList.filter(win => win.workspace.id === workspace);
    }

    function clientForToplevel(toplevel) {
        if (!toplevel || !toplevel.HyprlandToplevel) {
            return null;
        }
        const address = `0x${toplevel?.HyprlandToplevel?.address}`;
        return root.windowByAddress[address];
    }

    // Internals

    property bool _pendingClients: false
    property bool _pendingMonitors: false
    property bool _pendingLayers: false
    property bool _pendingWorkspaces: false

    Timer {
        id: eventDebounceTimer
        interval: 60
        repeat: false
        onTriggered: {
            if (WM.compositor !== "hyprland") return;
            if (root._pendingClients) {
                getClients.running = false;
                getClients.running = true;
                root._pendingClients = false;
            }
            if (root._pendingMonitors) {
                getMonitors.running = false;
                getMonitors.running = true;
                root._pendingMonitors = false;
            }
            if (root._pendingLayers) {
                getLayers.running = false;
                getLayers.running = true;
                root._pendingLayers = false;
            }
            if (root._pendingWorkspaces) {
                getWorkspaces.running = false;
                getWorkspaces.running = true;
                getActiveWorkspace.running = false;
                getActiveWorkspace.running = true;
                root._pendingWorkspaces = false;
            }
        }
    }

    // Phoenix (2026-10-08): a request restarted while it was still answering (running = false/true in the debounce
    // timer) ends with half its JSON; that showed up as an error at every start (and as a "desktop check" problem).
    // Ask again instead; only failures that keep coming are logged as errors.
    property var _parseFailures: ({})
    function parseFailed(what, e, retry) {
        const n = (root._parseFailures[what] ?? 0) + 1;
        root._parseFailures[what] = n;
        if (n >= 5) console.error(`[HyprlandData] Failed to parse ${what} (${n} times in a row):`, e);
        else retry();
    }
    function parseOk(what) { if (root._parseFailures[what]) root._parseFailures[what] = 0; }

    function queueUpdate(clients = false, workspaces = false, monitors = false, layers = false) {
        if (WM.compositor !== "hyprland") return;
        if (clients) root._pendingClients = true;
        if (workspaces) root._pendingWorkspaces = true;
        if (monitors) root._pendingMonitors = true;
        if (layers) root._pendingLayers = true;
        eventDebounceTimer.restart();
    }

    function updateWindowList() {
        queueUpdate(true, false, false, false);
    }

    function updateLayers() {
        queueUpdate(false, false, false, true);
    }

    function updateMonitors() {
        queueUpdate(false, false, true, false);
    }

    function updateWorkspaces() {
        queueUpdate(false, true, false, false);
    }

    function updateAll() {
        queueUpdate(true, true, true, true);
    }

    function biggestWindowForWorkspace(workspaceId) {
        const windowsInThisWorkspace = HyprlandData.windowList.filter(w => w.workspace.id == workspaceId);
        return windowsInThisWorkspace.reduce((maxWin, win) => {
            const maxArea = (maxWin?.size?.[0] ?? 0) * (maxWin?.size?.[1] ?? 0);
            const winArea = (win?.size?.[0] ?? 0) * (win?.size?.[1] ?? 0);
            return winArea > maxArea ? win : maxWin;
        }, null);
    }

    Component.onCompleted: {
        if (WM.compositor === "hyprland") {
            getClients.running = true;
            getMonitors.running = true;
            getLayers.running = true;
            getWorkspaces.running = true;
            getActiveWorkspace.running = true;
        }
    }

    Connections {
        target: Hyprland
        enabled: WM.compositor === "hyprland"

        function onRawEvent(event) {
            const name = event.name;
            if (["openlayer", "closelayer", "screencast", "submap", "activelayout"].includes(name)) return;

            if (name.startsWith("workspace") || name.startsWith("createworkspace") || name.startsWith("destroyworkspace") || name.startsWith("moveworkspace") || name === "renameworkspace") {
                root.queueUpdate(false, true, false, false);
            } else if (name.startsWith("activespecial")) {
                root.queueUpdate(false, true, true, false);
            } else if (name.startsWith("openwindow") || name.startsWith("closewindow") || name.startsWith("movewindow")) {
                root.queueUpdate(true, true, false, false);
            } else if (name.startsWith("window") || name.startsWith("activewindow") || name === "fullscreen" || name === "changefloatingmode" || name === "pin" || name === "urgent" || name === "minimize") {
                root.queueUpdate(true, false, false, false);
            } else if (name.startsWith("monitor") || name === "focusedmon") {
                root.queueUpdate(false, true, true, false);
            } else {
                root.queueUpdate(true, true, false, false);
            }
        }
    }

    Process {
        id: getClients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            id: clientsCollector
            onStreamFinished: {
                try {
                    root.windowList = JSON.parse(clientsCollector.text);
                    let tempWinByAddress = {};
                    for (var i = 0; i < root.windowList.length; ++i) {
                        var win = root.windowList[i];
                        tempWinByAddress[win.address] = win;
                    }
                    root.windowByAddress = tempWinByAddress;
                    root.addresses = root.windowList.map(win => win.address);
                    root.parseOk("clients");
                } catch (e) {
                    root.parseFailed("clients", e, () => root.queueUpdate(true, false, false, false));
                }
            }
        }
    }

    Process {
        id: getMonitors
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            id: monitorsCollector
            onStreamFinished: {
                try {
                    root.monitors = JSON.parse(monitorsCollector.text);
                    root.parseOk("monitors");
                } catch (e) {
                    root.parseFailed("monitors", e, () => root.queueUpdate(false, false, true, false));
                }
            }
        }
    }

    Process {
        id: getLayers
        command: ["hyprctl", "layers", "-j"]
        stdout: StdioCollector {
            id: layersCollector
            onStreamFinished: {
                try {
                    root.layers = JSON.parse(layersCollector.text);
                    root.parseOk("layers");
                } catch (e) {
                    root.parseFailed("layers", e, () => root.queueUpdate(false, false, false, true));
                }
            }
        }
    }

    Process {
        id: getWorkspaces
        command: ["hyprctl", "workspaces", "-j"]
        stdout: StdioCollector {
            id: workspacesCollector
            onStreamFinished: {
                try {
                    var rawWorkspaces = JSON.parse(workspacesCollector.text);
                    root.parseOk("workspaces");
                    root.workspaces = rawWorkspaces.filter(ws => ws.id >= 1 && ws.id <= 100);
                    let tempWorkspaceById = {};
                    for (var i = 0; i < root.workspaces.length; ++i) {
                        var ws = root.workspaces[i];
                        tempWorkspaceById[ws.id] = ws;
                    }
                    root.workspaceById = tempWorkspaceById;
                    root.workspaceIds = root.workspaces.map(ws => ws.id);
                } catch (e) {
                    root.parseFailed("workspaces", e, () => root.queueUpdate(false, true, false, false));
                }
            }
        }
    }

    Process {
        id: getActiveWorkspace
        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector {
            id: activeWorkspaceCollector
            onStreamFinished: {
                try {
                    root.activeWorkspace = JSON.parse(activeWorkspaceCollector.text);
                    root.parseOk("active workspace");
                } catch (e) {
                    root.parseFailed("active workspace", e, () => root.queueUpdate(false, true, false, false));
                }
            }
        }
    }
}