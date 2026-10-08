pragma Singleton
import Quickshell
import qs.services
import qs.modules.common

Singleton {
    id: root

    function closeAllWindows() {
        HyprlandData.windowList.map(w => w.pid).forEach(pid => {
            Quickshell.execDetached(["kill", pid]);
        });
    }

    function changePassword() {
        Quickshell.execDetached(["bash", "-c", `${Config.options.apps.changePassword}`]);
    }

    function lock() {
        if (WM.compositor === "niri") {
            Quickshell.execDetached(["qs", "-c", "end4-pC", "ipc", "call", "lock", "activate"]);
        } else {
            Quickshell.execDetached(["loginctl", "lock-session"]);
        }
    }

    function suspend() {
        Quickshell.execDetached(["bash", "-c", "systemctl suspend || loginctl suspend"]);
    }

    function logout() {
        closeAllWindows();
        if (WM.compositor === "niri") {
            Quickshell.execDetached(["niri", "msg", "action", "quit"]);
        } else {
            // Phoenix (2026-10-08): the same clean exit as ~/.local/bin/switch-desktop (F25). `pkill -i Hyprland` also hit
            // start-hyprland, xdg-desktop-portal-hyprland and other hyprland-* helpers. Wallpaper Engine is closed first:
            // Hyprland segfaults while exiting and the app then aborts, which shows a crash report next session.
            // ([l]inux…: these patterns are in this command line too; without the brackets pkill -f killed this very shell)
            Quickshell.execDetached(["bash", "-c", "pkill -TERM -f '[l]inux-wallpaper-engine-ux/app.asar'; pkill -TERM -x linux-wallpaper; "
                + "for _ in $(seq 10); do pgrep -f '[l]inux-wallpaper-engine-ux/app.asar|[l]inux-wallpaperengine --' >/dev/null || break; sleep 0.5; done; "
                + "hyprctl dispatch 'hl.dsp.exit()' >/dev/null 2>&1 || pkill -x Hyprland"]);
        }
    }

    function launchTaskManager() {
        Quickshell.execDetached(["bash", "-c", `${Config.options.apps.taskManager}`]);
    }

    function hibernate() {
        Quickshell.execDetached(["bash", "-c", `systemctl hibernate || loginctl hibernate`]);
    }

    function poweroff() {
        closeAllWindows();
        Quickshell.execDetached(["bash", "-c", `systemctl poweroff || loginctl poweroff`]);
    }

    function reboot() {
        closeAllWindows();
        Quickshell.execDetached(["bash", "-c", `reboot || loginctl reboot`]);
    }

    function rebootToFirmware() {
        closeAllWindows();
        Quickshell.execDetached(["bash", "-c", `systemctl reboot --firmware-setup || loginctl reboot --firmware-setup`]);
    }
}
