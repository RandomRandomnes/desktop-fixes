import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

WPage {
    readonly property bool micActive: Pipewire.linkGroups.values.some(g => g.source?.type === PwNodeType.AudioSource && g.target?.type === PwNodeType.AudioInStream)
    readonly property bool screenSharing: Pipewire.linkGroups.values.some(g => g.source?.type === PwNodeType.VideoSource)
    WSection {
        title: "Security"
        WToggle {
            icon: "password"
            title: "Require a password to shut down or restart from the lock screen"
            checked: Config.options.lock.security.requirePasswordToPower
            onToggled: v => Config.options.lock.security.requirePasswordToPower = v
        }
        WToggle {
            icon: "key"
            title: "Unlock the keyring when you unlock the screen"
            description: "Makes saved passwords available to apps after sign-in"
            checked: Config.options.lock.security.unlockKeyring
            onToggled: v => Config.options.lock.security.unlockKeyring = v
        }
        WLink { icon: "lock_clock"; title: "Lock automatically"; description: "Screen and sleep timeouts"; page: "system"; sub: "power" }
    }

    WSection {
        title: "App permissions"
        WCard {
            icon: micActive ? "mic" : "mic_none"
            title: "Microphone"
            description: micActive ? "An app is using your microphone right now" : "No apps are using your microphone"
        }
        WCard {
            icon: screenSharing ? "screen_share" : "stop_screen_share"
            title: "Screen sharing"
            description: screenSharing ? "Your screen is being shared or recorded" : "Nothing is capturing your screen"
        }
        WToggle {
            icon: "location_on"
            title: "Location for weather"
            description: "Use GPS/Wi-Fi location instead of a fixed city"
            checked: Config.options.bar.weather.enableGPS
            onToggled: v => Config.options.bar.weather.enableGPS = v
        }
    }

    WSection {
        title: "AI"
        WCombo {
            icon: "neurology"
            title: "AI features in the sidebar"
            model: [{ displayName: "On", value: 1 }, { displayName: "Local models only", value: 2 }, { displayName: "Off", value: 0 }]
            currentValue: Config.options.policies.ai
            onSelected: v => Config.options.policies.ai = v
        }
    }

    WSection {
        title: "Work safety"
        WToggle {
            icon: "wallpaper"
            title: "Hide NSFW wallpapers on public networks"
            description: "When connected to networks like cafés, campuses and airports"
            checked: Config.options.workSafety.enable.wallpaper
            onToggled: v => Config.options.workSafety.enable.wallpaper = v
        }
        WToggle {
            icon: "content_paste_off"
            title: "Hide NSFW clipboard items on public networks"
            checked: Config.options.workSafety.enable.clipboard
            onToggled: v => Config.options.workSafety.enable.clipboard = v
        }
    }

    WSection {
        title: "History"
        WCard {
            icon: "content_paste"
            title: "Clipboard history"
            description: `${Cliphist.entries.length} items`
            WButton { buttonText: "Clear"; onClicked: Cliphist.wipe() }
        }
        WCard {
            icon: "notifications"
            title: "Notification history"
            description: `${Notifications.list.length} notifications`
            WButton { buttonText: "Clear"; enabled: Notifications.list.length > 0; onClicked: Notifications.discardAllNotifications() }
        }
    }
}
