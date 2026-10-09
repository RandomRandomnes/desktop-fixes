import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

// Part of the Windows-style desktop menu (DesktopMenu.qml).
Rectangle {
    id: frame
    default property alias content: frameCol.data
    width: DeskMenuStyle.menuWidth
    implicitHeight: frameCol.implicitHeight + 8
    radius: DeskMenuStyle.menuRadius
    color: DeskMenuStyle.colMenu
    border.width: 1
    border.color: Qt.rgba(DeskMenuStyle.colBorder.r, DeskMenuStyle.colBorder.g, DeskMenuStyle.colBorder.b, 0.7)

    StyledRectangularShadow { target: frame }

    // Windows-like opening: fade in while sliding down a little
    opacity: 0
    transform: Translate { id: slide; y: -6; Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } } }
    Component.onCompleted: { opacity = 1; slide.y = 0 }
    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    readonly property alias hovered: frameHover.hovered
    HoverHandler { id: frameHover }

    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }   // clicks inside don't close the menu

    ColumnLayout {
        id: frameCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 4 }
        spacing: 0
    }
}
