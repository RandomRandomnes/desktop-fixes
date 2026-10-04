import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models.hyprland
import qs.modules.common.models.quickToggles

WPage {
    id: page
    GameModeToggle { id: gameMode }
    HyprlandConfigOption { id: tearing; key: "general:allow_tearing" }

    WSection {
        WToggle {
            icon: "sports_esports"
            title: "Game Mode"
            description: "Turns off animations, blur, shadows, gaps and rounded corners, and allows tearing for the lowest latency"
            checked: gameMode.toggled
            onToggled: gameMode.mainAction()
        }
        WCombo {
            icon: "bolt"
            title: "Power mode"
            model: [
                { displayName: "Best power efficiency", value: PowerProfile.PowerSaver },
                { displayName: "Balanced", value: PowerProfile.Balanced },
            ].concat(PowerProfiles.hasPerformanceProfile ? [{ displayName: "Best performance", value: PowerProfile.Performance }] : [])
            currentValue: PowerProfiles.profile
            onSelected: v => PowerProfiles.profile = v
        }
    }

    WSection {
        title: "Display"
        WToggle {
            icon: "bolt"
            title: "Allow screen tearing in games"
            description: "Lower input latency for fullscreen games that request it (immediate mode)"
            checked: !!tearing.value
            onToggled: v => { tearing.value = v; tearing.setValue(v ? 1 : 0); }
        }
        WToggle {
            icon: "fullscreen"
            title: "Pause the animated wallpaper behind fullscreen apps"
            checked: Config.options.background.hideWhenFullscreen
            onToggled: v => Config.options.background.hideWhenFullscreen = v
        }
        WLink { icon: "speed"; title: "Variable refresh rate"; description: "In Display settings"; page: "system"; sub: "display" }
    }

    WSection {
        title: "Overlays"
        WToggle {
            icon: "my_location"
            title: "Crosshair overlay"
            description: "Draws a crosshair in the middle of the screen"
            checked: GlobalStates.crosshairOpen
            onToggled: v => GlobalStates.crosshairOpen = v
        }
        WCard {
            icon: "code"
            title: "Crosshair code"
            description: "Valorant-style crosshair code"
            Rectangle {
                implicitWidth: 280; implicitHeight: 34
                radius: Appearance.rounding.verysmall
                color: Appearance.colors.colLayer3
                TextInput {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    verticalAlignment: Text.AlignVCenter
                    clip: true
                    color: Appearance.colors.colOnLayer3
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    text: Config.options.crosshair.code
                    onEditingFinished: Config.options.crosshair.code = text
                }
            }
        }
    }

    WSection {
        title: "Related"
        WLink { icon: "sports_esports"; title: "Open Steam"; chevronIcon: "open_in_new"; action: () => { Quickshell.execDetached(["steam"]); GlobalStates.settingsOpen = false; } }
        WLink { icon: "notifications_off"; title: "Do not disturb"; description: "Silence notifications while you play"; page: "system"; sub: "notifications" }
    }
}
