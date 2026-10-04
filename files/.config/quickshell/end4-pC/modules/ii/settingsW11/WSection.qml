import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

// A titled group of cards, stacked with the small gaps Windows 11 uses.
ColumnLayout {
    id: root
    property string title: ""
    default property alias cards: cardColumn.data

    Layout.fillWidth: true
    spacing: 8

    StyledText {
        visible: root.title.length > 0
        Layout.topMargin: 6
        Layout.leftMargin: 2
        text: root.title
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.DemiBold
        color: Appearance.colors.colOnLayer1
    }

    ColumnLayout {
        id: cardColumn
        Layout.fillWidth: true
        spacing: 3
    }
}
