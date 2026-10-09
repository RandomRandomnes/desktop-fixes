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

    // Phoenix (2026-10-09): Restart / Shut down run ~/.local/bin/phoenix-power, outside the shell. Killing every window's
    // process from here while starting the restart could kill the shell itself first (a window of its own), and
    // killed Wallpaper Engine abruptly; one restart froze the PC with nothing in the log. The helper closes Wallpaper
    // Engine cleanly, then the apps (never the shell or Hyprland), logs each step, then asks systemd. The old way
    // stays as the fallback when the helper is missing.
    function power(action, fallback) {
        const helper = `${Quickshell.env("HOME")}/.local/bin/phoenix-power`;
        Quickshell.execDetached(["bash", "-c", `if [ -x "${helper}" ]; then exec setsid "${helper}" ${action}; fi; ${fallback}`]);
    }

    function poweroff() {
        root.power("poweroff", "systemctl poweroff || loginctl poweroff");
    }

    function reboot() {
        root.power("reboot", "reboot || loginctl reboot");
    }

    function rebootToFirmware() {
        root.power("firmware", "systemctl reboot --firmware-setup || loginctl reboot --firmware-setup");
    }
}
