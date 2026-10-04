import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

// One Windows 11 style settings row: icon, title + description, control on the right.
// Clickable cards (links, toggles) get a hover state; `chevron` adds the "go to page" arrow.
Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string description: ""
    property bool clickable: false
    property bool chevron: false
    property string chevronIcon: "chevron_right"
    property real minHeight: 66
    property real iconSize: 22
    property Component leading: null          // optional custom left item (app icon, avatar…)
    default property alias control: controlRow.data
    signal clicked()

    Layout.fillWidth: true
    implicitHeight: Math.max(minHeight, contentRow.implicitHeight + 24)
    radius: Appearance.rounding.verysmall + 2
    color: mouse.pressed && clickable ? Appearance.colors.colLayer2Active
        : mouse.containsMouse && clickable ? Appearance.colors.colLayer2Hover
        : Appearance.colors.colLayer2
    opacity: enabled ? 1 : 0.5

    Behavior on color {
        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: root.clickable
        enabled: root.clickable
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }

    RowLayout {
        id: contentRow
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 18
            rightMargin: 14
        }
        spacing: 16

        Loader {
            visible: root.icon.length > 0 || root.leading !== null
            active: visible
            Layout.alignment: Qt.AlignVCenter
            sourceComponent: root.leading ?? defaultIcon
        }
        Component {
            id: defaultIcon
            MaterialSymbol {
                text: root.icon
                iconSize: root.iconSize
                color: Appearance.colors.colOnLayer2
                horizontalAlignment: Text.AlignHCenter
                width: 26
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1
            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer2
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                visible: root.description.length > 0
                text: root.description
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.Wrap
            }
        }

        RowLayout {
            id: controlRow
            Layout.alignment: Qt.AlignVCenter
            spacing: 10
        }

        MaterialSymbol {
            visible: root.chevron
            Layout.alignment: Qt.AlignVCenter
            text: root.chevronIcon
            iconSize: 20
            color: Appearance.colors.colSubtext
        }
    }
}
