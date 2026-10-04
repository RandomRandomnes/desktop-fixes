import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

// Card with an On/Off switch. Bind `checked`, react in onToggled(value).
WCard {
    id: root
    property bool checked: false
    property bool showStateText: true
    signal toggled(bool value)

    clickable: true
    onClicked: root.toggled(!root.checked)

    StyledText {
        visible: root.showStateText
        text: root.checked ? "On" : "Off"
        font.pixelSize: Appearance.font.pixelSize.small
        color: Appearance.colors.colOnLayer2
    }
    StyledSwitch {
        checked: root.checked
        onClicked: root.toggled(!root.checked)
        // keep the switch in sync with the binding even after a click flips it locally
        onCheckedChanged: if (checked !== root.checked) checked = Qt.binding(() => root.checked)
    }
}
