pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Per-app notification settings (2026-10-08, ours; not upstream). Settings › System › Notifications.
 * Notifications.qml asks decide() for every new notification: an app can be switched off (the notification is
 * dropped), shown without a pop-up banner (straight to the notification center), and play a sound or not (the sound
 * itself is notifications.playSound, off by default; never during Do Not Disturb).
 * Every app that sends a notification is remembered so Settings can list it, newest first, also after a restart.
 * Kept in ~/.local/state/phoenix/notification-apps.json (personal: not in config.json or setup profiles):
 *   { "<app>": { "icon", "lastSeen" (ms), "enabled", "banners", "sound" } }   (a missing option = on)
 */
Singleton {
    id: root

    property var apps: ({})
    property bool loaded: false
    readonly property var appList: Object.keys(apps).map(k => Object.assign({ name: k }, apps[k]))
        .sort((a, b) => (b.lastSeen || 0) - (a.lastSeen || 0))
    readonly property string soundFile: "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga"

    function keyFor(notification) {
        return String(notification?.appName || notification?.desktopEntry || "Other apps").trim() || "Other apps"
    }

    function setOption(name, option, value) {
        const a = Object.assign({}, root.apps)
        a[name] = Object.assign({}, a[name] || {})
        a[name][option] = value
        root.apps = a
        saveTimer.restart()
    }

    function forget(name) {
        const a = Object.assign({}, root.apps)
        delete a[name]
        root.apps = a
        saveTimer.restart()
    }

    // → { show, popup, sound } for a new notification; also records the app
    function decide(notification, popupAllowed, silent) {
        const name = root.keyFor(notification)
        const prev = root.apps[name] || {}
        const a = Object.assign({}, root.apps)
        a[name] = Object.assign({}, prev, {
            icon: notification?.appIcon || prev.icon || "",
            lastSeen: Date.now()
        })
        root.apps = a
        saveTimer.restart()
        const show = prev.enabled !== false
        const popup = show && popupAllowed && prev.banners !== false
        const hints = notification?.hints || {}
        const sound = show && !silent && Config.options.notifications.playSound === true && prev.sound !== false
            && !hints["suppress-sound"]
        if (sound) Quickshell.execDetached(["bash", "-c", `[ -f "$1" ] && exec pw-play "$1"`, "_", root.soundFile])
        return { show: show, popup: popup }
    }

    Timer {
        id: saveTimer
        interval: 1000
        onTriggered: if (root.loaded) store.setText(JSON.stringify(root.apps))
    }
    FileView {
        id: store
        path: `${Quickshell.env("HOME")}/.local/state/phoenix/notification-apps.json`
        printErrors: false
        onLoaded: {
            try {   // per app: saved options first, then anything recorded before the file was read
                const saved = JSON.parse(text()) || {}
                for (const k in root.apps) saved[k] = Object.assign({}, saved[k] || {}, root.apps[k])
                root.apps = saved
            } catch (e) {}
            root.loaded = true
        }
        onLoadFailed: root.loaded = true
    }
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", `${Quickshell.env("HOME")}/.local/state/phoenix`])
}
