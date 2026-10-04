import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

// Card with a dropdown. model: [{ displayName, value }], emits selected(value).
WCard {
    id: root
    property var model: []
    property var currentValue
    property real fieldWidth: 240
    signal selected(var value)

    StyledComboBox {
        id: combo
        Layout.fillWidth: false
        Layout.preferredWidth: root.fieldWidth
        textRole: "displayName"
        model: root.model
        currentIndex: {
            const i = root.model.findIndex(m => m.value === root.currentValue);
            return i;
        }
        displayText: currentIndex >= 0 ? root.model[currentIndex].displayName : "—"
        onActivated: index => root.selected(root.model[index].value)
    }
}
