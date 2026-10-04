import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

// Card with a slider and a value label. `value` is a plain property: set it from your source,
// and handle moved(v) to write back (only fires on user interaction).
WCard {
    id: root
    property real value: 0
    property real from: 0
    property real to: 1
    property real stepSize: 0
    property var format: v => `${Math.round(v * 100)}%`
    property real sliderWidth: 260
    signal moved(real v)

    StyledText {
        text: root.format(slider.value)
        font.pixelSize: Appearance.font.pixelSize.small
        color: Appearance.colors.colSubtext
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: 56
    }
    StyledSlider {
        id: slider
        Layout.fillWidth: false
        Layout.preferredWidth: root.sliderWidth
        Layout.maximumWidth: root.sliderWidth
        from: root.from
        to: root.to
        stepSize: root.stepSize
        value: root.value
        usePercentTooltip: false
        tooltipContent: root.format(value)
        configuration: StyledSlider.Configuration.XS
        stopIndicatorValues: []
        onMoved: root.moved(value)
        Connections {
            target: root
            function onValueChanged() { if (!slider.pressed) slider.value = root.value }
        }
    }
}
