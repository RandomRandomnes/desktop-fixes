import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

// Part of the Windows-style desktop menu (DesktopMenu.qml).
Rectangle {
    id: row
    property string icon: ""
    property string text: ""
    property string hint: ""            // small text on the right (a count)
    property bool submenu: false
    property bool checkable: false
    property bool checked: false
    property bool active: false         // its submenu is open
    readonly property alias hovered: rowMouse.containsMouse
    signal triggered()
    signal hoverChanged(bool hovered)

    Layout.fillWidth: true
    implicitHeight: DeskMenuStyle.rowHeight
    radius: DeskMenuStyle.menuRadius - 3
    color: rowMouse.pressed ? DeskMenuStyle.colPressed : (rowMouse.containsMouse || row.active) ? DeskMenuStyle.colHover : "transparent"

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: row.triggered()
        onContainsMouseChanged: row.hoverChanged(containsMouse)
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
        spacing: 12

        MaterialSymbol {
            Layout.preferredWidth: 20
            horizontalAlignment: Text.AlignHCenter
            text: row.checkable ? (row.checked ? "check" : "") : row.icon
            iconSize: 18
            color: DeskMenuStyle.colText
        }
        StyledText {
            Layout.fillWidth: true
            text: row.text
            elide: Text.ElideRight
            font.pixelSize: Appearance.font.pixelSize.small
            color: DeskMenuStyle.colText
        }
        StyledText {
            visible: row.hint.length > 0
            text: row.hint
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: DeskMenuStyle.colText
            opacity: 0.6
        }
        MaterialSymbol {
            visible: row.submenu
            text: "chevron_right"
            iconSize: 16
            color: DeskMenuStyle.colText
            opacity: 0.7
        }
    }
}
