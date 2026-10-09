import qs.modules.common.widgets
import qs.services
import QtQuick

// Phoenix (2026-10-09): sound button for the classic quick panel, like the Android-style "Audio output" tile.
// Click mutes/unmutes; right-click opens the output list (speakers, headset, …) with the volume mixer.
QuickToggleButton {
    id: root
    toggled: !(Audio.sink?.audio?.muted ?? false)
    buttonIcon: (Audio.sink?.audio?.muted ?? false) ? "volume_off" : "volume_up"
    onClicked: Audio.toggleMute()
    StyledToolTip {
        text: Translation.tr("%1 | Right-click to choose the output").arg(Audio.sink ? Audio.friendlyDeviceName(Audio.sink) : Translation.tr("Audio output"))
    }
}
