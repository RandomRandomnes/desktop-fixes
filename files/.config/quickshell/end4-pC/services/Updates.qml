pragma Singleton
import qs
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * System updates service. Currently only supports Arch.
 */
Singleton {
    id: root

    property bool available: false
    property alias checking: checkUpdatesProc.running
    property int count: 0
    
    readonly property bool updateAdvised: available && count > Config.options.updates.adviseUpdateThreshold
    readonly property bool updateStronglyAdvised: available && count > Config.options.updates.stronglyAdviseUpdateThreshold

    function load() {}
    function refresh() {
        if (!available) return;
        print("[Updates] Checking for system updates")
        checkUpdatesProc.running = true;
    }

    Timer {
        interval: Config.options.updates.checkInterval * 60 * 1000
        repeat: true
        running: Config.ready && Config.options.updates.enableCheck
        onTriggered: {
            print("[Updates] Periodic update check due")
            root.refresh();
        }
    }

    Process {
        id: checkAvailabilityProc
        running: Config.ready && Config.options.updates.enableCheck
        command: ["which", "checkupdates"]
        onExited: (exitCode, exitStatus) => {
            root.available = (exitCode === 0);
            firstCheckTimer.start();
        }
    }

    Timer {
        id: firstCheckTimer
        interval: 60 * 1000
        onTriggered: root.refresh()
    }

    Process {
        id: checkUpdatesProc
        // ours also counts a pending end4-pC shell update and a pending custom-fixes release (both applied by
        // ~/.local/bin/system-update); stock otherwise
        command: Config.options.extras.updatesScript
            ? ["bash", "-c", "pacman=$(checkupdates 2>/dev/null | wc -l); aur=$(yay -Qua 2>/dev/null | wc -l || paru -Qua 2>/dev/null | wc -l || echo 0); shell=$(timeout 15 git -C ~/.config/quickshell/end4-pC fetch -q 2>/dev/null && git -C ~/.config/quickshell/end4-pC rev-list --count HEAD..@{u} 2>/dev/null || echo 0); [ \"$shell\" -gt 0 ] 2>/dev/null && shell=1 || shell=0; fixes=0; $HOME/.local/bin/custom-update check --quiet >/dev/null 2>&1 && fixes=1; echo $((pacman + aur + shell + fixes))"]
            : ["bash", "-c", "pacman=$(checkupdates 2>/dev/null | wc -l); aur=$(yay -Qua 2>/dev/null | wc -l || paru -Qua 2>/dev/null | wc -l || echo 0); echo $((pacman + aur))"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.count = parseInt(text.trim())
            }
        }
    }
}
