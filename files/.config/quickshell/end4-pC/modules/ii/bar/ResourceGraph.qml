import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * One cell of the bar resources widget (2026-10-03, ours; not upstream): icon, a small history graph with the
 * current value drawn over it, and two detail lines beside it. Turns the error color while `warning` is set.
 */
RowLayout {
    id: root
    property color contentColor: Appearance.colors.colOnTertiaryContainer
    required property string iconName
    required property list<real> history
    required property string valueText
    property string line1: ""
    property string line2: ""
    property bool warning: false
    // widest text the detail lines are expected to show; reserves the space so the pill keeps a steady width
    property string detailTemplate: "00.00 GHz"
    // 2 = graph + value + detail lines, 1 = graph + value, 0 = value only (picked by Resources.qml from the screen width)
    property int density: 2
    readonly property color accent: warning ? Appearance.colors.colError : contentColor
    spacing: 5

    MaterialSymbol {
        Layout.alignment: Qt.AlignVCenter
        fill: 1
        font.weight: Font.DemiBold
        text: root.iconName
        iconSize: Appearance.font.pixelSize.normal
        color: root.accent
    }

    StyledText {
        visible: root.density === 0
        Layout.alignment: Qt.AlignVCenter
        text: root.valueText
        color: root.accent
        font.pixelSize: Appearance.font.pixelSize.smallest
        font.weight: Font.Bold
        font.features: { "tnum": 1 }
    }

    Rectangle {
        visible: root.density >= 1
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 62
        implicitHeight: 24
        radius: 7
        color: ColorUtils.transparentize(root.contentColor, 0.86)
        clip: true

        Graph {
            anchors.fill: parent
            anchors.topMargin: 3
            values: root.history
            points: Math.max(2, SystemStats.historyLength)
            alignment: Graph.Alignment.Right
            color: root.accent
            fillOpacity: 0.22
        }

        StyledText {
            anchors {
                left: parent.left
                leftMargin: 5
                verticalCenter: parent.verticalCenter
            }
            text: root.valueText
            color: root.accent
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.weight: Font.Bold
            font.features: { "tnum": 1 }
            style: Text.Outline
            styleColor: ColorUtils.transparentize(Appearance.colors.colTertiaryContainer, 0.35)
        }
    }

    ColumnLayout {
        id: details
        visible: root.density >= 2
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: Math.max(implicitWidth, templateMetrics.advanceWidth + 2)
        spacing: -2

        TextMetrics {
            id: templateMetrics
            text: root.detailTemplate
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.weight: Font.DemiBold
        }

        StyledText {
            text: root.line1
            color: root.accent
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
        StyledText {
            text: root.line2
            color: root.accent
            opacity: 0.8
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.weight: Font.Medium
            font.features: { "tnum": 1 }
        }
    }
}
