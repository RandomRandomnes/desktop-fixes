import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell

QuickToggleButton {
    id: root
    buttonIcon: "swap_horiz"
    toggled: false

    onClicked: {
        Quickshell.execDetached([`${Quickshell.env("HOME")}/.local/bin/switch-desktop`, "plasma"])
    }
    StyledToolTip {
        text: Translation.tr("Switch to KDE Plasma (logs out)")
    }
}
