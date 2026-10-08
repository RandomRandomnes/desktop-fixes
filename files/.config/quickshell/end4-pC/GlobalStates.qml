import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    signal requestBluetoothDialog()
    property bool barOpen: true
    property bool barStyleEditorOpen: false
    property bool crosshairOpen: false
    property bool equalizerOpen: false
    property bool sidebarLeftOpen: false
    property bool sidebarRightOpen: false
    property bool mediaControlsOpen: false
    property bool osdBrightnessOpen: false
    property bool settingsOpen: false
    property bool osdVolumeOpen: false
    property bool oskOpen: false
    property bool overlayOpen: false
    property bool overviewOpen: false
    property bool regionSelectorOpen: false
    property bool searchOpen: false
    property bool screenLocked: false
    property bool screenLockContainsCharacters: false
    property bool screenUnlockFailed: false
    property bool screenTranslatorOpen: false
    property bool sessionOpen: false
    property bool superDown: false
    property bool superReleaseMightTrigger: true
    property bool wallpaperSelectorOpen: false
    property bool workspaceShowNumbers: false
    property var settingsTarget: null

    function openSettingsAt(pageId, label, section, subsection) {
        root.settingsOpen = true;
        Qt.callLater(() => {
            root.settingsTarget = { page: pageId, label: label ?? "", section: section ?? "", subsection: subsection ?? "" };
        });
    }
    property Item currentPageInstance: null
    property list<real> visualizerPoints: []
    property bool desktopWidgetKeyboardFocus: false
    property bool desktopMenuOpen: false
    property var desktopMenuScreen: null
    property real desktopMenuX: 0
    property real desktopMenuY: 0
    property string wallpaperSelectorTarget: "wallpaper"
    property bool dropShelfOpen: false
    property real dropShelfX: 0
    property real dropShelfY: 0
    property string osdIndicatorType: "volume"
    property bool barCenterOnly: false
    property int dashboardPage: 0
    property string dashboardGroup: ""
    property var frameHover: ({})
    function setFrameHover(screenName, side, hovered) {
        const key = `${screenName}:${side}`;
        if ((root.frameHover[key] ?? false) === hovered) return;
        const next = Object.assign({}, root.frameHover);
        next[key] = hovered;
        root.frameHover = next;
    }
    function isFrameHovered(screenName, side) {
        return root.frameHover[`${screenName}:${side}`] ?? false;
    }
    property bool diSessionOpen: false
    property bool startupLockPending: true
    property bool backgroundVisible: true
    // Starts the custom-feature switch service (services/Extras.qml, ours) with the shell.
    readonly property bool extrasStarted: Extras.extras !== undefined
    // Starts automatic Game Mode / Do Not Disturb for games (services/GameAssist.qml, ours).
    readonly property bool gameAssistStarted: GameAssist.extras !== undefined
    // Starts the "Sunset to sunrise" night light schedule (services/NightSchedule.qml, ours).
    readonly property bool nightScheduleStarted: NightSchedule.place !== undefined
    // Starts automatic display profile switching (services/DisplayProfiles.qml, ours).
    readonly property bool displayProfilesStarted: DisplayProfiles.tool !== undefined

    // Wallpaper Engine check lives here (not in Background.qml) so it survives reloadBackground():
    // a freshly created background surface starts with the known value instead of false, which used to
    // paint the static wallpaper over Wallpaper Engine for up to 500ms after every reload (login, wallpaper switch).
    property bool wallpaperEngineRunning: false
    // Wallpapers the shell draws itself (2026-10-03): screen name -> {dir, volume, silent, fps, scaling, props}, parsed from
    // the arguments of the renderer stand-in (~/.local/lib/wallpaper-engine-shell/linux-wallpaperengine, process name
    // linux-wallpaperengine-inshell). Drawn by background/WallpaperEngineLayer.qml. Web wallpapers run in a separate
    // host (process linux-wallpaperengine-web) and are not listed here. props = the app's per-wallpaper settings
    // (--set-property name=value, values kept as strings; the layer converts them using project.json).
    property var wallpaperEngineInShell: ({})
    // wallpaper sound muted via wallpaper-engine-ctl mute (flag file ~/.local/state/wallpaper-engine-muted)
    property bool wallpaperEngineMuted: false
    property string _wallpaperEngineInShellKey: "{}"
    function _parseWallpaperEngineInShell(procs) {
        const result = {};
        for (const args of procs) {
            if (args[0] !== "linux-wallpaperengine-inshell") continue;
            const opts = { volume: 100, silent: false, fps: 60, scaling: "fill", props: {} };
            const dirs = {};
            let pending = [];
            for (let i = 0; i < args.length; i++) {
                const a = args[i], v = args[i + 1];
                if (a === "--screen-root") { pending.push(v); i++; }
                else if (a === "--bg") {
                    const dir = v.startsWith("/") ? v : `${Quickshell.env("HOME")}/.local/share/Steam/steamapps/workshop/content/431960/${v}`;
                    for (const s of pending) dirs[s] = dir;
                    pending = []; i++;
                }
                else if (a === "--volume") { opts.volume = Number(v); i++; }
                else if (a === "--fps") { opts.fps = Number(v); i++; }
                else if (a === "--scaling") { opts.scaling = v; i++; }
                else if (a === "--silent") opts.silent = true;
                else if (a === "--set-property" && v && v.includes("=")) {
                    opts.props[v.slice(0, v.indexOf("="))] = v.slice(v.indexOf("=") + 1); i++;
                }
            }
            for (const s in dirs) result[s] = Object.assign({ dir: dirs[s] }, opts);
        }
        return result;
    }
    Process {
        id: wallpaperEngineRunningCheck
        // One line per process: argv joined with \x1f (newlines inside arguments become spaces), read from /proc so
        // arguments containing spaces (colors such as "0 0 0") stay intact. The [l] pattern keeps this sh from matching itself.
        command: ["sh", "-c", "for p in $(pgrep -f '[l]inux-wallpaperengine'); do tr '\\0\\n' '\\037 ' < /proc/$p/cmdline 2>/dev/null; echo; done; [ -e \"${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper-engine-muted\" ] && echo __WE_MUTED__"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                // only real renderer processes (argv[0] ends in linux-wallpaperengine or a stand-in name: -inshell, -web), not any
                // command line that merely mentions the name
                const procs = this.text.split("\n").filter(l => l.length > 0).map(l => l.split("\x1f").filter((a, i, arr) => i < arr.length - 1 || a !== ""))
                    .filter(args => /linux-wallpaperengine(-inshell|-web)?$/.test(args[0] ?? ""));
                root.wallpaperEngineRunning = procs.length > 0;
                root.wallpaperEngineMuted = this.text.includes("__WE_MUTED__");
                const parsed = root._parseWallpaperEngineInShell(procs);
                const key = JSON.stringify(parsed);
                if (key !== root._wallpaperEngineInShellKey) {
                    root._wallpaperEngineInShellKey = key;
                    root.wallpaperEngineInShell = parsed;
                }
            }
        }
    }
    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: wallpaperEngineRunningCheck.running = true
    }

    Timer {
        interval: 3000
        running: true
        onTriggered: root.startupLockPending = false
    }

    readonly property bool dynamicIslandEnabled: Config.options.bar.layouts.leftLayout.includes("dynamicIsland")
        || Config.options.bar.layouts.middleLayout.includes("dynamicIsland")
        || Config.options.bar.layouts.rightLayout.includes("dynamicIsland")

    signal centeredWallpaperThumpRequested()

    // Shared by desktop (Background) and lock screen (LockSurface) scroll-to-cycle
    readonly property var centeredShapeOptions: [
        "Circle", "Square", "Slanted", "Arch", "Arrow", "SemiCircle", "Oval", "Pill",
        "Triangle", "Diamond", "ClamShell", "Pentagon", "Gem", "Sunny", "VerySunny",
        "Cookie4Sided", "Cookie6Sided", "Cookie7Sided", "Cookie9Sided", "Cookie12Sided",
        "Ghostish", "Clover4Leaf", "Clover8Leaf", "Burst", "SoftBurst", "Flower",
        "Puffy", "PuffyDiamond", "PixelCircle", "Bun", "Heart"
    ]
    function cycleCenteredWallpaperShape(direction) {
        const opts = root.centeredShapeOptions
        const i = opts.indexOf(Config.options.background.centeredWallpaperShape)
        Config.options.background.centeredWallpaperShape = opts[(i + direction + opts.length) % opts.length]
    }

    readonly property var hotCornerOptions: [
        { displayName: Translation.tr("None"),                  value: "none" },
        { displayName: Translation.tr("Left Sidebar"),           value: "sidebarLeftOpen" },
        { displayName: Translation.tr("Right Sidebar"),          value: "sidebarRightOpen" },
        { displayName: Translation.tr("Overview Launcher"),               value: "overviewOpen" },
        { displayName: Translation.tr("Wallpaper Selector"),     value: "wallpaperSelectorOpen" },
        { displayName: Translation.tr("Media Controls"),         value: "mediaControlsOpen" },
        { displayName: Translation.tr("Overlay"),                value: "overlayOpen" },
        { displayName: Translation.tr("ScreenShot Region"),        value: "regionSelectorOpen" },
        { displayName: Translation.tr("Screen Translator"),      value: "screenTranslatorOpen" },
        { displayName: Translation.tr("On-screen Keyboard"),     value: "oskOpen" },
        { displayName: Translation.tr("Session Menu"),           value: "sessionOpen" },
        { displayName: Translation.tr("Equalizer"),           value: "equalizerOpen" }
    ]

    function toggleState(name) {
        if (!name || name === "none") return;
        root[name] = !root[name];
    }
    
    onSidebarRightOpenChanged: {
        if (GlobalStates.sidebarRightOpen) {
            Notifications.timeoutAll();
            Notifications.markAllRead();
        }
    }

    Timer {
        id: barRefreshTimer
        interval: 200
        repeat: false
        onTriggered: {
            root.barOpen = true
        }
    }

    function refreshBar() {
        if (!root.barOpen) return;
        root.barOpen = false
        barRefreshTimer.restart()
    }

    Timer {
        id: backgroundRefreshTimer
        interval: 100
        repeat: false
        onTriggered: {
            root.backgroundVisible = true
        }
    }

    function refreshBackground() {
        if (!root.backgroundVisible) return;
        root.backgroundVisible = false
        backgroundRefreshTimer.restart()
    }

    CompositorGlobalShortcut {
        name: "workspaceNumber"
        description: "Hold to show workspace numbers, release to show icons"
        onPressed: { root.superDown = true }
        onReleased: { root.superDown = false }
    }

    IpcHandler {
        target: "background"
        function toggleCenteredWallpaper(): void {
            Config.options.background.centeredWallpaper = !Config.options.background.centeredWallpaper
        }
        function reloadBackground(): void {
            root.refreshBackground()
        }
    }

     CompositorGlobalShortcut {
        name: "centeredWallpaperToggle"
        description: "Toggles centered wallpaper"
        onPressed: {
            Config.options.background.centeredWallpaper = !Config.options.background.centeredWallpaper
        }
    }
}