pragma Singleton
pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.models.hyprland
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower

/**
 * Game mode extras and automatic Do Not Disturb (2026-10-08, ours; not upstream). Settings › Gaming.
 *  - Game Mode (ii's quick toggle: animations, blur, shadows, gaps, rounding off) is "on" while animations are off.
 *    While it is on this also stops Wallpaper Engine (extras.gameModeWallpaper) and picks the Best performance power
 *    mode (extras.gameModePerformance); both come back when it goes off.
 *  - extras.gameModeAuto: Game Mode turns on by itself while a fullscreen game has the focus, and off afterwards
 *    (only if it was turned on automatically).
 *  - extras.autoDnd: Do Not Disturb while a fullscreen game has the focus or (extras.autoDndScreenShare) while the
 *    screen is shared; it goes off afterwards unless you had it on already.
 * A game = the focused window is fullscreen and is a Steam game (steam_app_*), gamescope, a Windows program (*.exe,
 * Wine/Proton) or says it is a game (content type). Instantiated from GlobalStates.qml.
 */
Singleton {
    id: root

    readonly property var extras: Config.options.extras
    readonly property bool autoGameMode: Config.ready && extras.gameModeAuto === true
    readonly property bool autoDnd: Config.ready && extras.autoDnd !== false
    readonly property bool autoDndScreenShare: extras.autoDndScreenShare !== false

    property bool gameFocused: false
    property string gameClass: ""
    property bool screenShared: false

    // Game Mode's state, read from Hyprland (the quick toggle and Settings › Gaming write it)
    HyprlandConfigOption { id: animations; key: "animations:enabled" }
    HyprlandConfigOption { id: blur; key: "decoration:blur:enabled" }
    HyprlandConfigOption { id: gapsIn; key: "general:gaps_in" }
    readonly property bool gameModeKnown: animations.value !== undefined && animations.value !== null
        && blur.value !== undefined && blur.value !== null
    // Game Mode switches animations, blur and gaps off together; animations off alone is Accessibility's "reduce
    // motion", not Game Mode (QA 2026-10-08: that used to stop Wallpaper Engine and force the performance power mode)
    readonly property bool gameModeOn: gameModeKnown && !animations.value && !blur.value
        && (gapsIn.value === 0 || gapsIn.value === "0" || String(gapsIn.value).trim().startsWith("0"))

    // what this service switched itself, so it only undoes its own changes; kept in a file so a shell restart in the
    // middle of a game still undoes them afterwards (Do Not Disturb itself isn't kept across restarts)
    property bool autoGameModeActive: false
    property bool autoDndActive: false
    property bool wallpaperStopped: false
    property int previousProfile: -1
    property bool stateLoaded: false
    readonly property string stateText: JSON.stringify({ autoGameModeActive, wallpaperStopped, previousProfile })
    onStateTextChanged: if (stateLoaded) stateFile.setText(stateText)
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", `${Quickshell.env("HOME")}/.local/state/phoenix`])
    FileView {
        id: stateFile
        path: `${Quickshell.env("HOME")}/.local/state/phoenix/game-assist.json`
        printErrors: false
        onLoaded: {
            try {
                const j = JSON.parse(text())
                root.autoGameModeActive = j.autoGameModeActive === true
                root.wallpaperStopped = j.wallpaperStopped === true
                root.previousProfile = typeof j.previousProfile === "number" ? j.previousProfile : -1
            } catch (e) {}
            root.stateLoaded = true
            checkTimer.restart()
            settleTimer.restart()
        }
        onLoadFailed: { root.stateLoaded = true; checkTimer.restart(); settleTimer.restart() }
    }

    readonly property var gameModeEntries: ({
        "animations:enabled": 0, "decoration:shadow:enabled": 0, "decoration:blur:enabled": 0,
        "general:gaps_in": 0, "general:gaps_out": 0, "general:border_size": 1, "decoration:rounding": 0,
        "general:allow_tearing": 1 })

    function isGame(w) {
        if (!w || !(w.fullscreen >= 2 || w.fullscreenClient >= 2)) return false
        const cls = String(w.class || w.initialClass || "")
        return /^steam_app_\d+$/.test(cls) || /^gamescope$/i.test(cls) || /\.exe$/i.test(cls) || w.contentType === "game"
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["activewindowv2", "fullscreen", "closewindow", "openwindow", "workspacev2", "focusedmonv2"].includes(event.name))
                checkTimer.restart()
            else if (event.name === "screencast") {
                // several shares can run at once (OBS + Discord): count them, the first one ending must not end DND
                const on = String(event.data).split(",")[0] === "1"
                root.shareCount = Math.max(0, root.shareCount + (on ? 1 : -1))
                if (root.shareCount > 0) shareTimer.restart(); else { shareTimer.stop(); root.screenShared = false }
            }
        }
    }
    property int shareCount: 0
    // a screenshot or a window preview also reports a short "screencast": only a share that lasts counts
    Timer { id: shareTimer; interval: 3000; onTriggered: root.screenShared = root.shareCount > 0 }
    Timer { id: checkTimer; interval: 300; onTriggered: if (!checkProc.running) checkProc.running = true }
    Process {
        id: checkProc
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let w = null
                try { w = JSON.parse(text) } catch (e) {}
                root.gameFocused = root.isGame(w)
                root.gameClass = root.gameFocused ? String(w.class) : ""
            }
        }
    }

    // on quickly, off after a pause, so a short Alt+Tab doesn't flip everything back and forth
    readonly property bool wantGameMode: autoGameMode && gameFocused
    readonly property bool wantDnd: autoDnd && (gameFocused || (autoDndScreenShare && screenShared))
    onWantGameModeChanged: wantGameMode ? gameModeOnTimer.restart() : gameModeOffTimer.restart()
    onWantDndChanged: wantDnd ? dndOnTimer.restart() : dndOffTimer.restart()

    // after a restart: once the game check ran, apply the wanted state (turns automatic Game Mode off if the game is gone)
    Timer { id: settleTimer; interval: 2500; onTriggered: { root.syncGameMode(); root.applyGameModeExtras() } }
    Timer { id: gameModeOnTimer; interval: 1500; onTriggered: root.syncGameMode() }
    Timer { id: gameModeOffTimer; interval: 4000; onTriggered: root.syncGameMode() }
    Timer { id: dndOnTimer; interval: 1000; onTriggered: root.syncDnd() }
    Timer { id: dndOffTimer; interval: 4000; onTriggered: root.syncDnd() }

    function syncGameMode() {
        if (!root.gameModeKnown || !root.stateLoaded) return
        if (root.wantGameMode && !root.gameModeOn) {
            HyprlandConfig.setMany(root.gameModeEntries)
            root.autoGameModeActive = true
            console.log(`[GameAssist] Game Mode on for ${root.gameClass}`)
        } else if (!root.wantGameMode && root.autoGameModeActive) {
            if (root.gameModeOn) HyprlandConfig.resetMany(Object.keys(root.gameModeEntries))
            root.autoGameModeActive = false
            console.log("[GameAssist] Game Mode off (game left)")
        }
    }

    function syncDnd() {
        if (root.wantDnd && !Notifications.silent) {
            Notifications.silent = true
            root.autoDndActive = true
            console.log(`[GameAssist] Do Not Disturb on (${root.gameFocused ? root.gameClass : "screen shared"})`)
        } else if (!root.wantDnd && root.autoDndActive) {
            if (Notifications.silent) Notifications.silent = false
            root.autoDndActive = false
            console.log("[GameAssist] Do Not Disturb off")
        }
    }
    // switching Do Not Disturb by hand while it was automatic: it's yours now, it won't be switched off
    Connections {
        target: Notifications
        function onSilentChanged() { if (!Notifications.silent) root.autoDndActive = false }
    }

    // Game Mode on/off (by hand or automatically): Wallpaper Engine and the power mode
    onGameModeOnChanged: applyGameModeExtras()
    function applyGameModeExtras() {
        if (!root.gameModeKnown || !root.stateLoaded) return
        if (root.gameModeOn) {
            if (!root.wallpaperStopped && root.extras.gameModeWallpaper !== false && root.extras.wallpaperEngine
                    && GlobalStates.wallpaperEngineRunning) {
                Quickshell.execDetached([`${Quickshell.env("HOME")}/.local/bin/wallpaper-engine-ctl`, "stop"])
                root.wallpaperStopped = true
            }
            if (root.extras.gameModePerformance !== false && PowerProfiles.hasPerformanceProfile
                    && PowerProfiles.profile !== PowerProfile.Performance) {
                root.previousProfile = PowerProfiles.profile
                PowerProfiles.profile = PowerProfile.Performance
            }
        } else {
            if (root.wallpaperStopped) {
                if (root.extras.wallpaperEngine)
                    Quickshell.execDetached([`${Quickshell.env("HOME")}/.local/bin/wallpaper-engine-ctl`, "start"])
                root.wallpaperStopped = false
            }
            if (root.previousProfile >= 0) {
                if (PowerProfiles.profile === PowerProfile.Performance) PowerProfiles.profile = root.previousProfile
                root.previousProfile = -1
            }
        }
    }
}
