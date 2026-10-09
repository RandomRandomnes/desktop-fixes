pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs
import qs.services

// Navigation state + search index for the Windows 11 style settings window.
// Pages are one file per category (P<Category>.qml); sub-pages live inside those files.
Singleton {
    id: root

    property string page: "home"
    property string sub: ""
    property bool advanced: false          // showing the original illogical-impulse settings
    property var history: []

    readonly property var categories: [
        { id: "home",            name: "Home",                 icon: "home" },
        { id: "system",          name: "System",               icon: "computer" },
        { id: "devices",         name: "Bluetooth & devices",  icon: "devices_other" },
        { id: "network",         name: "Network & internet",   icon: "wifi" },
        { id: "personalization", name: "Personalization",      icon: "brush" },
        { id: "apps",            name: "Apps",                 icon: "apps" },
        { id: "accounts",        name: "Accounts",             icon: "account_circle" },
        { id: "time",            name: "Time & language",      icon: "schedule" },
        { id: "gaming",          name: "Gaming",               icon: "sports_esports" },
        { id: "accessibility",   name: "Accessibility",        icon: "accessibility_new" },
        { id: "privacy",         name: "Privacy & security",   icon: "shield" },
        { id: "extras",          name: "Extras",               icon: "auto_awesome" },
        { id: "update",          name: "Update",               icon: "update" },
    ]

    readonly property var subTitles: ({
        "system/display": "Display",
        "system/sound": "Sound",
        "system/notifications": "Notifications",
        "system/power": "Power",
        "system/storage": "Storage",
        "system/multitasking": "Multitasking",
        "system/clipboard": "Clipboard",
        "system/about": "About",
        "system/report": "Report a problem",
        "devices/bluetooth": "Devices",
        "devices/mouse": "Mouse",
        "devices/keyboard": "Keyboard",
        "network/wifi": "Wi-Fi",
        "personalization/background": "Background",
        "personalization/colors": "Colors",
        "personalization/taskbar": "Taskbar",
        "personalization/dock": "Dock",
        "personalization/start": "Start",
        "personalization/appgrid": "Super menu apps",
        "personalization/lockscreen": "Lock screen",
        "personalization/widgets": "Desktop widgets",
        "personalization/sidebar": "Sidebar",
        "apps/installed": "Installed apps",
        "apps/defaults": "Default apps",
        "apps/startup": "Startup",
        "apps/rules": "Window rules",
        "time/datetime": "Date & time",
        "time/language": "Language & region",
    })

    // title, extra search words, page, sub
    readonly property var index: [
        ["Display", "screen monitor resolution refresh rate scale", "system", "display"],
        ["Brightness", "screen display dim", "system", "display"],
        ["Night light", "blue light warm color temperature hyprsunset", "system", "display"],
        ["Sound", "audio volume speakers headphones", "system", "sound"],
        ["Output device", "speakers headphones audio", "system", "sound"],
        ["Input device", "microphone mic audio", "system", "sound"],
        ["Volume mixer", "app volume audio", "system", "sound"],
        ["Notifications", "popups alerts banners", "system", "notifications"],
        ["Do not disturb", "silent mute notifications focus", "system", "notifications"],
        ["Power mode", "performance balanced power saver profile", "system", "power"],
        ["Screen and sleep", "idle timeout lock suspend screen off", "system", "power"],
        ["Battery", "charge suspend low", "system", "power"],
        ["Keep awake", "idle inhibitor caffeine", "system", "power"],
        ["Storage", "disk space drive usage", "system", "storage"],
        ["Snap windows", "multitasking tiling float layout gaps", "system", "multitasking"],
        ["Workspaces", "virtual desktops overview", "system", "multitasking"],
        ["Notifications from apps", "notifications per app banners sound block mute apps", "system", "notifications"],
        ["Login screen at startup", "login screen sign in password startup autologin greeter users", "accounts", ""],
        ["Taskbar on each screen", "taskbar bar widgets second monitor screen per monitor tv hide", "personalization", "taskbar"],
        ["Display profiles", "monitors displays profile multiple screens tv dock laptop automatic switch", "system", "display"],
        ["Night light schedule", "sunset sunrise night light blue light evening automatic", "system", "display"],
        ["Clipboard history", "copy paste cliphist", "system", "clipboard"],
        ["About", "device specifications cpu gpu ram memory kernel hostname", "system", "about"],
        ["Report a problem", "bug issue feedback help github broken crash", "system", "report"],
        ["Bluetooth", "devices pair connect headphones", "devices", "bluetooth"],
        ["Device batteries", "battery percentage mouse headphones controller sidebar", "devices", ""],
        ["Mouse", "pointer speed sensitivity scroll acceleration left handed", "devices", "mouse"],
        ["Touchpad", "trackpad natural scrolling tap", "devices", "mouse"],
        ["Keyboard", "layout repeat rate delay num lock", "devices", "keyboard"],
        ["On-screen keyboard", "osk touch keyboard", "devices", "keyboard"],
        ["Wi-Fi", "wireless network internet", "network", "wifi"],
        ["Airplane mode", "radio offline", "network", ""],
        ["Ethernet", "wired lan network", "network", ""],
        ["Background", "wallpaper picture image", "personalization", "background"],
        ["Colors", "dark mode light mode accent theme transparency", "personalization", "colors"],
        ["Dark mode", "theme light colors", "personalization", "colors"],
        ["Transparency effects", "blur translucent", "personalization", "colors"],
        ["Taskbar", "bar panel top bottom autohide tray", "personalization", "taskbar"],
        ["Dock", "pinned apps taskbar icons favorites", "personalization", "dock"],
        ["Pinned apps", "dock favorites taskbar", "personalization", "dock"],
        ["Start", "launcher app menu search pinned", "personalization", "start"],
        ["Super menu apps", "app grid launcher overview hide show apps", "personalization", "appgrid"],
        ["Lock screen", "lockscreen password blur", "personalization", "lockscreen"],
        ["Desktop widgets", "clock calendar notes todo weather", "personalization", "widgets"],
        ["Sidebar", "right sidebar panel extras hide show", "personalization", "sidebar"],
        ["Extras", "custom features switches profile", "extras", ""],
        ["Windows-style windows", "floating title bar tiling close maximize", "extras", ""],
        ["Minimize to the dock", "minimize hide restore", "extras", ""],
        ["Wallpaper Engine background", "animated live wallpaper static picture", "extras", ""],
        ["Live system graphs", "resources cpu gpu ram taskbar monitor", "extras", ""],
        ["Claude Code in the AI sidebar", "ai claude model", "extras", ""],
        ["Start Steam at login", "steam autostart tray", "extras", ""],
        ["Wallpaper Engine picker", "wallpaper engine sidebar card live animated", "personalization", "sidebar"],
        ["Switch to KDE Plasma button", "kde plasma desktop switch sidebar", "personalization", "sidebar"],
        ["Installed apps", "uninstall remove programs", "apps", "installed"],
        ["Default apps", "browser file manager terminal open with", "apps", "defaults"],
        ["Startup apps", "autostart login launch", "apps", "startup"],
        ["Window rules", "window rule float size position workspace monitor opacity pin maximize title bar", "apps", "rules"],
        ["Your info", "account profile picture avatar name", "accounts", ""],
        ["Change password", "account sign-in", "accounts", ""],
        ["Date & time", "clock 24 hour time zone format", "time", "datetime"],
        ["Language", "region locale translation", "time", "language"],
        ["Game mode", "gaming performance animations tearing automatic fullscreen wallpaper engine power", "gaming", ""],
        ["Do not disturb while playing", "gaming notifications focus assist silence screen sharing", "gaming", ""],
        ["Crosshair", "gaming overlay", "gaming", ""],
        ["Animations", "motion effects reduce", "accessibility", ""],
        ["Visual effects", "transparency animations", "accessibility", ""],
        ["Privacy", "microphone camera location", "privacy", ""],
        ["Work safety", "hide nsfw wallpaper clipboard", "privacy", ""],
        ["Windows Update", "updates upgrade pacman packages system update", "update", ""],
        ["Shell update", "illogical impulse end4 dotfiles hypr-guard", "update", ""],
        ["Advanced settings", "illogical impulse original all settings", "advanced", ""],
    ]

    function search(q) {
        q = q.trim().toLowerCase();
        if (q.length === 0) return [];
        const words = q.split(/\s+/);
        return root.index
            .map(e => {
                const title = e[0].toLowerCase();
                const hay = title + " " + e[1];
                if (!words.every(w => hay.indexOf(w) !== -1)) return null;
                const score = title.startsWith(q) ? 0 : title.indexOf(q) !== -1 ? 1 : 2;
                return { title: e[0], page: e[2], sub: e[3], score: score };
            })
            .filter(e => e !== null)
            .sort((a, b) => a.score - b.score)
            .slice(0, 8);
    }

    function categoryName(id) {
        return root.categories.find(c => c.id === id)?.name ?? "";
    }

    function subTitle(page, sub) {
        return root.subTitles[`${page}/${sub}`] ?? "";
    }

    function go(page, sub = "") {
        if (page === "advanced") {
            root.advanced = true;
            return;
        }
        if (page === root.page && sub === root.sub && !root.advanced) return;
        root.history = root.history.concat([{ page: root.page, sub: root.sub }]);
        root.advanced = false;
        root.page = page;
        root.sub = sub;
    }

    function back() {
        if (root.advanced) {
            root.advanced = false;
            return;
        }
        if (root.history.length === 0) {
            if (root.sub !== "") root.sub = "";
            return;
        }
        const last = root.history[root.history.length - 1];
        root.history = root.history.slice(0, -1);
        root.page = last.page;
        root.sub = last.sub;
    }

    readonly property bool canGoBack: advanced || history.length > 0 || sub !== ""

    // Launcher search results deep-link into the original settings pages (GlobalStates.openSettingsAt).
    // This singleton is created before the embedded original settings, so this handler runs first.
    Connections {
        target: GlobalStates
        function onSettingsTargetChanged() {
            if (GlobalStates.settingsTarget) root.advanced = true;
        }
        // Closing Settings leaves the original (advanced) pages: the next open starts at Phoenix's own Settings again
        // (2026-10-08; it used to stay in the advanced view for good)
        function onSettingsOpenChanged() {
            if (GlobalStates.settingsOpen) return;
            // the next open starts at Home, like Windows Settings (QA 2026-10-09: it reopened on the last page)
            root.advanced = false;
            root.page = "home";
            root.sub = "";
            root.history = [];
        }
    }
}
