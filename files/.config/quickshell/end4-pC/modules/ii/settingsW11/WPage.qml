import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

// Scrollable page body. Children are laid out in one column, capped at a readable width.
StyledFlickable {
    id: root
    default property alias content: column.data
    property real maxContentWidth: 1000

    clip: true
    contentWidth: width
    contentHeight: column.implicitHeight + 40
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: column
        x: 0
        y: 4
        width: Math.min(root.width - 24, root.maxContentWidth)
        spacing: 18
    }
}
