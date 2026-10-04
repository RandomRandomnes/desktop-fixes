import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

WPage {
    WSection {
        title: "Vision"
        WToggle {
            icon: "animation"
            title: "Animation effects"
            description: "Window and workspace animations"
            checked: Config.options.hyprland.animations.enable
            onToggled: v => { Config.options.hyprland.animations.enable = v; HyprlandConfig.set("animations:enabled", v ? 1 : 0); }
        }
        WCombo {
            visible: Config.options.hyprland.animations.enable
            icon: "slow_motion_video"
            title: "Animation speed"
            model: [{ displayName: "Normal", value: "normal" }, { displayName: "Fast", value: "fast" }, { displayName: "Smooth (Niri style)", value: "niri" }]
            currentValue: Config.options.hyprland.animations.animation
            onSelected: v => { Config.options.hyprland.animations.animation = v; HyprlandConfig.setAnimPreset(v); }
        }
        WToggle {
            icon: "opacity"
            title: "Transparency effects"
            checked: Config.options.appearance.transparency.enable
            onToggled: v => Config.options.appearance.transparency.enable = v
        }
        WToggle {
            icon: "blur_on"
            title: "Blur behind windows"
            checked: Config.options.hyprland.decoration.blur.enabled
            onToggled: v => { Config.options.hyprland.decoration.blur.enabled = v; HyprlandConfig.set("decoration:blur:enabled", v ? 1 : 0); }
        }
        WSlider {
            icon: "timer"
            title: "Show notifications for"
            from: 3000; to: 30000; stepSize: 1000
            format: v => `${Math.round(v / 1000)} s`
            value: Config.options.notifications.timeout
            onMoved: v => Config.options.notifications.timeout = Math.round(v / 1000) * 1000
        }
        WToggle {
            icon: "chat_bubble"
            title: "Click instead of hover to show taskbar tooltips"
            checked: Config.options.bar.tooltips.clickToShow
            onToggled: v => Config.options.bar.tooltips.clickToShow = v
        }
    }

    WSection {
        title: "Color & contrast"
        WLink { icon: "nightlight"; title: "Night light"; description: "Warmer colors in the evening"; page: "system"; sub: "display" }
        WLink { icon: "contrast"; title: "Dark mode & colors"; page: "personalization"; sub: "colors" }
        WToggle {
            icon: "flare"
            title: "Anti-flashbang"
            description: "Dim the screen briefly when a very bright window appears"
            checked: Config.options.light.antiFlashbang.enable
            onToggled: v => Config.options.light.antiFlashbang.enable = v
        }
    }

    WSection {
        title: "Interaction"
        WToggle {
            icon: "keyboard"
            title: "On-screen keyboard"
            checked: GlobalStates.oskOpen
            onToggled: v => GlobalStates.oskOpen = v
        }
        WToggle {
            icon: "swipe_vertical"
            title: "Faster touchpad scrolling in the shell"
            checked: Config.options.interactions.scrolling.fasterTouchpadScroll
            onToggled: v => Config.options.interactions.scrolling.fasterTouchpadScroll = v
        }
        WLink { icon: "mouse"; title: "Mouse"; description: "Pointer speed, primary button, scrolling"; page: "devices"; sub: "mouse" }
        WLink { icon: "keyboard"; title: "Keyboard"; description: "Repeat delay and rate"; page: "devices"; sub: "keyboard" }
    }

    WSection {
        title: "Hearing"
        WToggle {
            icon: "volume_up"
            title: "System sounds for battery and timers"
            checked: Config.options.sounds.battery
            onToggled: v => { Config.options.sounds.battery = v; Config.options.sounds.pomodoro = v; }
        }
        WToggle {
            icon: "hearing"
            title: "Volume protection"
            description: "Prevent sudden loud volume jumps"
            checked: Config.options.audio.protection.enable
            onToggled: v => Config.options.audio.protection.enable = v
        }
    }
}
