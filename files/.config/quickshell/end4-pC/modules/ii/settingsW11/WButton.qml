import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

// Windows 11 style push button: standard (neutral) or accent (filled with the theme's primary color).
RippleButton {
    id: root
    property bool accent: false
    property string iconName: ""

    implicitHeight: 34
    implicitWidth: Math.max(90, row.implicitWidth + 28)
    buttonRadius: Appearance.rounding.verysmall
    colBackground: accent ? Appearance.colors.colPrimary : Appearance.colors.colLayer3
    colBackgroundHover: accent ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer3Hover
    colRipple: accent ? Appearance.colors.colPrimaryActive : Appearance.colors.colLayer3Active

    contentItem: Item {
        implicitWidth: row.implicitWidth
        implicitHeight: row.implicitHeight
        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 6
            MaterialSymbol {
                visible: root.iconName.length > 0
                text: root.iconName
                iconSize: 18
                color: root.accent ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer3
            }
            StyledText {
                text: root.buttonText
                font.pixelSize: Appearance.font.pixelSize.smallie
                color: root.accent ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer3
            }
        }
    }
}
